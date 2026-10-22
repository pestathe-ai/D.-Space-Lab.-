import 'dart:async';
import 'dart:isolate';

/// Lavoro pesante in un isolate, con avanzamento e possibilità di fermarlo.
///
/// [work] riceve una funzione `report(fase, fatto, totale)` da chiamare
/// ogni tanto. Il risultato deve poter passare tra isolate.
class ProgressJob<R> {
  ProgressJob(this.work);
  final R Function(void Function(int phase, int done, int total) report) work;

  Isolate? _iso;
  Completer<R?>? _done;

  /// Restituisce null se il lavoro viene fermato con [cancel].
  Future<R?> run(void Function(int phase, int done, int total) onProgress) async {
    final port = ReceivePort();
    final done = _done = Completer<R?>();
    port.listen((m) {
      if (m is List && m.length == 3) {
        onProgress(m[0] as int, m[1] as int, m[2] as int);
      } else if (m is _Result) {
        if (!done.isCompleted) {
          if (m.error != null) {
            done.completeError(m.error!);
          } else {
            done.complete(m.value as R);
          }
        }
      }
    });
    _iso = await Isolate.spawn<List<Object>>(_entry, [port.sendPort, work]);
    try {
      return await done.future;
    } finally {
      port.close();
      _iso?.kill(priority: Isolate.immediate);
      _iso = null;
    }
  }

  void cancel() {
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
    final d = _done;
    if (d != null && !d.isCompleted) d.complete(null);
  }
}

void _entry(List<Object> args) {
  final sp = args[0] as SendPort;
  final w = args[1] as Object? Function(void Function(int, int, int));
  try {
    final r = w((p, d, t) => sp.send([p, d, t]));
    sp.send(_Result(r, null));
  } catch (e) {
    sp.send(_Result(null, '$e'));
  }
}

class _Result {
  _Result(this.value, this.error);
  final Object? value;
  final String? error;
}
