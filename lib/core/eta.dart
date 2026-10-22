/// Stima del tempo che manca, calcolata sulla velocità recente.
///
/// Le unità possono essere file, documenti o byte: conta solo che [done]
/// e [total] usino la stessa unità.
class EtaEstimator {
  EtaEstimator({this.windowMs = 20000, this.warmupMs = 2500});

  /// Finestra su cui misurare la velocità (le ultime N millisecondi).
  final int windowMs;

  /// Prima di questo tempo la stima non è affidabile e non viene data.
  final int warmupMs;

  final List<(int, int)> _samples = []; // (istante ms, fatto)
  int? _startMs;
  int done = 0, total = 0;

  void reset() {
    _samples.clear();
    _startMs = null;
    done = total = 0;
  }

  void update(int done, int total, {int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _startMs ??= now;
    this.done = done;
    this.total = total;
    _samples.add((now, done));
    while (_samples.length > 2 && now - _samples.first.$1 > windowMs) {
      _samples.removeAt(0);
    }
  }

  /// Tempo rimanente, o null se non si può ancora stimare.
  Duration? get remaining {
    if (_startMs == null || _samples.length < 2 || total <= 0) return null;
    if (done >= total) return Duration.zero;
    final last = _samples.last, first = _samples.first;
    if (last.$1 - _startMs! < warmupMs) return null;
    var dt = last.$1 - first.$1;
    var dd = last.$2 - first.$2;
    if (dd <= 0 || dt <= 0) {
      // nella finestra non è successo nulla: uso la media dall'inizio
      dt = last.$1 - _startMs!;
      dd = done;
      if (dd <= 0 || dt <= 0) return null;
    }
    final ms = (total - done) * dt / dd;
    return Duration(milliseconds: ms.round());
  }
}

/// "meno di un minuto", "circa 4 minuti", "circa 1 h 20 min".
String formatEta(Duration d) {
  final s = d.inSeconds;
  if (s < 45) return 'meno di un minuto';
  if (s < 90) return 'circa 1 minuto';
  final m = (s / 60).round();
  if (m < 60) return 'circa $m minuti';
  final h = m ~/ 60, r = m % 60;
  final rr = (r / 5).round() * 5;
  if (rr == 0 || rr == 60) return 'circa ${rr == 60 ? h + 1 : h} h';
  return 'circa $h h $rr min';
}

/// "1 min 05 s", per il tempo già trascorso.
String formatElapsed(Duration d) {
  final m = d.inMinutes, s = d.inSeconds % 60;
  return m == 0 ? '$s s' : '$m min ${s.toString().padLeft(2, '0')} s';
}
