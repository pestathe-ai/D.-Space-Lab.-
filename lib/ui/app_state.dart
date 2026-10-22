import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/doc_classifier.dart';
import '../core/storage_index.dart';
import '../services/doc_analyzer.dart';
import '../services/native.dart';
import '../services/trash.dart';

enum Status { checking, unsupported, needPermission, scanning, ready }

class AppState extends ChangeNotifier {
  Status status = Status.checking;
  String phase = '';
  int done = 0, total = 0;
  bool _cancel = false;

  String root = '';
  int deviceTotal = 0, deviceFree = 0;
  StorageIndex? index;
  DocAnalysis? docs;
  late Trash trash;
  List<TrashItem> trashItems = [];

  int get trashBytes => trashItems.fold(0, (s, i) => s + i.size);

  Future<void> start() async {
    if (await Native.sdkInt() < 30) {
      status = Status.unsupported;
      notifyListeners();
      return;
    }
    if (!await Native.hasAllFiles()) {
      status = Status.needPermission;
      notifyListeners();
      return;
    }
    root = await Native.storageRoot();
    trash = Trash(root);
    try {
      await trash.purgeExpired();
    } catch (_) {}
    await scan();
  }

  /// Da chiamare quando l'app torna in primo piano (dopo le impostazioni).
  Future<void> onResume() async {
    if (status == Status.needPermission) await start();
  }

  void cancel() => _cancel = true;

  Future<void> scan() async {
    if (status == Status.scanning) return;
    _cancel = false;
    status = Status.scanning;
    phase = 'Misuro lo spazio';
    done = total = 0;
    notifyListeners();

    final s = await Native.storageStats();
    deviceTotal = s.total;
    deviceFree = s.free;
    final r = root;
    index = await Isolate.run(() => StorageIndex(r, walkStorage(r)));
    trashItems = await trash.list();
    phase = 'Leggo i documenti';
    notifyListeners();

    docs = await DocAnalyzer.analyze(
      index!.files,
      onProgress: (d, t) {
        done = d;
        total = t;
        notifyListeners();
      },
      isCancelled: () => _cancel,
    );
    status = Status.ready;
    notifyListeners();
  }

  // ---- documenti ----
  List<AnalyzedDoc> docsWith(DocVerdict v) {
    final now = DateTime.now();
    final l = (docs?.docs ?? const <AnalyzedDoc>[])
        .where((d) => d.verdict(now) == v)
        .toList();
    l.sort((a, b) => b.file.size.compareTo(a.file.size));
    return l;
  }

  List<List<AnalyzedDoc>> get duplicateGroups =>
      docs?.duplicateGroups ?? const [];

  int get duplicateWaste => duplicateGroups.fold(
      0, (s, g) => s + g.first.file.size * (g.length - 1));

  // ---- cestino ----
  Future<int> moveToTrash(Iterable<String> paths) async {
    final moved = await trash.moveIn(paths.toList());
    await Native.scanMedia(moved);
    final gone = moved.toSet();
    final r = root;
    final keep = index!.files.where((f) => !gone.contains(f.path)).toList();
    index = await Isolate.run(() => StorageIndex(r, keep));
    if (docs != null) {
      docs = DocAnalysis(
        docs!.docs.where((d) => !gone.contains(d.file.path)).toList(),
        [
          for (final g in docs!.duplicateGroups)
            if (g.where((d) => !gone.contains(d.file.path)).length > 1)
              g.where((d) => !gone.contains(d.file.path)).toList(),
        ],
      );
    }
    trashItems = await trash.list();
    notifyListeners();
    return moved.length;
  }

  Future<int> restore(List<TrashItem> items) async {
    final back = await trash.restore(items);
    await Native.scanMedia(back);
    trashItems = await trash.list();
    notifyListeners();
    await scan();
    return back.length;
  }

  Future<int> purge(List<TrashItem> items) async {
    final freed = await trash.purge(items);
    trashItems = await trash.list();
    final s = await Native.storageStats();
    deviceFree = s.free;
    notifyListeners();
    return freed;
  }
}
