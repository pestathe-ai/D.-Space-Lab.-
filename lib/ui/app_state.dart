import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/cleanup.dart';
import '../core/doc_classifier.dart';
import '../core/duplicates.dart';
import '../core/eta.dart';
import '../core/file_types.dart';
import '../core/storage_index.dart';
import '../services/doc_analyzer.dart';
import '../services/jobs.dart';
import '../services/native.dart';
import '../services/photo_compress.dart';
import '../services/trash.dart';

// I lavori per gli isolate nascono in funzioni di primo livello, così non
// trascinano con sé lo stato dell'app (che non si può copiare).
ProgressJob<(List<FileEntry>, List<String>)> _walkJob(
        String root, int? expected) =>
    ProgressJob((report) {
      final empty = <String>[];
      final files = walkStorage(root,
          emptyDirs: empty, onCount: (n) => report(1, n, expected ?? 0));
      return (files, empty);
    });

ProgressJob<List<List<FileEntry>>> _duplicatesJob(List<FileEntry> files) =>
    ProgressJob((report) => findDuplicateFiles(files,
        onProgress: (p, d, t) => report(p, d, t)));

Future<StorageIndex> _buildIndex(String root, List<FileEntry> files) =>
    Isolate.run(() => StorageIndex(root, files));

enum Status { checking, unsupported, needPermission, scanning, ready }

/// Un lavoro lungo con avanzamento e stima del tempo.
class Progress {
  bool running = false;
  String phase = '';
  int done = 0, total = 0;
  final eta = EtaEstimator();
  final Stopwatch clock = Stopwatch();

  void start(String p) {
    running = true;
    phase = p;
    done = total = 0;
    eta.reset();
    clock
      ..reset()
      ..start();
  }

  void update(int d, int t) {
    done = d;
    total = t;
    eta.update(d, t);
  }

  void stop() {
    running = false;
    clock.stop();
  }

  double? get fraction => total <= 0 ? null : (done / total).clamp(0.0, 1.0);

  /// "circa 4 minuti", o null se non si può ancora dire.
  String? get etaText {
    final r = eta.remaining;
    return r == null ? null : formatEta(r);
  }

  String get elapsedText => formatElapsed(clock.elapsed);
}

class AppState extends ChangeNotifier {
  Status status = Status.checking;
  bool _cancelDocs = false;

  String root = '';
  int deviceTotal = 0, deviceFree = 0;
  StorageIndex? index;
  List<String> emptyDirs = [];
  Set<String> installed = {};
  Set<String> installedApks = {};
  DocAnalysis? docs;
  late Trash trash;
  List<TrashItem> trashItems = [];

  /// Scansione della memoria (bloccante) e lettura documenti (in sottofondo).
  final scanProgress = Progress();
  final docsProgress = Progress();
  final dupProgress = Progress();
  final photoProgress = Progress();
  int photoSaved = 0;
  CompressResult? lastCompress;

  /// File attesi in base all'ultima scansione (per stimare il tempo).
  int? expectedFiles;

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

  // ---- memoria della durata delle scansioni ----
  static Future<File> _statsFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/scansione.json');

  Future<void> _loadScanStats() async {
    try {
      final f = await _statsFile();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        expectedFiles = (m['files'] as num?)?.toInt();
      }
    } catch (_) {}
  }

  Future<void> _saveScanStats(int files, int ms) async {
    try {
      await (await _statsFile())
          .writeAsString(jsonEncode({'files': files, 'ms': ms}));
    } catch (_) {}
  }

  Future<void> scan() async {
    if (status == Status.scanning) return;
    _cancelDocs = true; // una lettura documenti in corso riparte dopo
    status = Status.scanning;
    scanProgress.start('Misuro lo spazio');
    notifyListeners();
    await _loadScanStats();

    final s = await Native.storageStats();
    deviceTotal = s.total;
    deviceFree = s.free;
    final r = root;
    final expected = expectedFiles;
    final job = _walkJob(r, expected);
    final res = await job.run((_, d, t) {
      // se ci sono più file dell'ultima volta, il totale cresce con loro
      scanProgress.update(d, t == 0 ? 0 : (d > t ? (d * 1.05).round() : t));
      notifyListeners();
    });
    final (files, empty) = res!;
    emptyDirs = empty;
    index = await _buildIndex(r, files);
    await _saveScanStats(files.length, scanProgress.clock.elapsedMilliseconds);
    expectedFiles = files.length;
    scanProgress.stop();

    trashItems = await trash.list();
    installed = await Native.installedPackages();
    installedApks = await Native.installedApks([
      for (final f in files)
        if (f.kind == FileKind.apk && extensionOf(f.path) == 'apk') f.path,
    ]);
    status = Status.ready;
    notifyListeners();
    analyzeDocs();
  }

  // ---- documenti (in sottofondo) ----
  Future<void> analyzeDocs() async {
    final idx = index;
    if (idx == null) return;
    // aspetta che un'eventuale lettura precedente si fermi
    while (docsProgress.running) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _cancelDocs = false;
    docsStopped = false;
    docsProgress.start('Leggo i documenti');
    notifyListeners();
    var last = 0;
    try {
      final result = await DocAnalyzer.analyze(
        idx.files,
        onProgress: (d, t) {
          docsProgress.update(d, t);
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - last > 400 || d == t) {
            last = now;
            notifyListeners();
          }
        },
        isCancelled: () => _cancelDocs,
      );
      // tolgo ciò che nel frattempo è finito nel cestino
      final alive = index?.sizeOf ?? const <String, int>{};
      docs = DocAnalysis(
        result.docs.where((d) => alive.containsKey(d.file.path)).toList(),
        [
          for (final g in result.duplicateGroups)
            if (g.where((d) => alive.containsKey(d.file.path)).length > 1)
              g.where((d) => alive.containsKey(d.file.path)).toList(),
        ],
      );
      docsStopped = _cancelDocs;
    } finally {
      docsProgress.stop();
      notifyListeners();
    }
  }

  /// La lettura documenti è stata fermata prima della fine.
  bool docsStopped = false;

  void stopDocs() => _cancelDocs = true;

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

  // ---- file inutili e residui ----
  // calcolati una volta per ogni versione dell'indice
  List<JunkGroup>? _junk;
  List<Residue>? _residues;
  Object? _cacheKeyIndex, _cacheKeyEmpty;

  void _checkCache() {
    if (!identical(_cacheKeyIndex, index) || !identical(_cacheKeyEmpty, emptyDirs)) {
      _cacheKeyIndex = index;
      _cacheKeyEmpty = emptyDirs;
      _junk = null;
      _residues = null;
    }
  }

  List<JunkGroup> get junk {
    if (index == null) return const [];
    _checkCache();
    return _junk ??= findJunk(root, index!.files, emptyDirs,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        installedApks: installedApks);
  }

  List<Residue> get residues {
    if (index == null) return const [];
    _checkCache();
    return _residues ??= findResidues(root, index!, emptyDirs, installed);
  }

  /// Elimina cartelle vuote (non serve il cestino: non c'è niente dentro).
  Future<int> deleteEmptyDirs(Iterable<String> dirs) async {
    var n = 0;
    for (final d in dirs) {
      try {
        await Directory(d).delete();
        n++;
      } catch (_) {}
    }
    final gone = dirs.toSet();
    emptyDirs = emptyDirs.where((d) => !gone.contains(d)).toList();
    notifyListeners();
    return n;
  }

  // ---- duplicati di ogni tipo ----
  List<List<FileEntry>>? fileDuplicates;
  ProgressJob<List<List<FileEntry>>>? _dupJob;

  int get fileDuplicateWaste => (fileDuplicates ?? const []).fold(
      0, (s, g) => s + g.first.size * (g.length - 1));

  Future<void> findFileDuplicates() async {
    final idx = index;
    if (idx == null || dupProgress.running) return;
    dupProgress.start('Cerco file con lo stesso peso');
    notifyListeners();
    final job = _dupJob = _duplicatesJob(idx.files);
    var phase = 0, last = 0;
    try {
      final r = await job.run((p, d, t) {
        if (p != phase) {
          phase = p;
          dupProgress.start(p == 1
              ? 'Confronto veloce dei sospetti'
              : 'Confronto completo, byte per byte');
        }
        dupProgress.update(d, t);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - last > 300) {
          last = now;
          notifyListeners();
        }
      });
      if (r != null) {
        final alive = index?.sizeOf ?? const <String, int>{};
        fileDuplicates = [
          for (final g in r)
            if (g.where((f) => alive.containsKey(f.path)).length > 1)
              g.where((f) => alive.containsKey(f.path)).toList(),
        ];
      }
    } finally {
      _dupJob = null;
      dupProgress.stop();
      notifyListeners();
    }
  }

  void stopFileDuplicates() => _dupJob?.cancel();

  // ---- compressione foto ----
  bool _cancelPhotos = false;

  Future<void> compressPhotos(List<FileEntry> photos, CompressPreset p) async {
    if (photoProgress.running) return;
    _cancelPhotos = false;
    photoSaved = 0;
    lastCompress = null;
    photoProgress.start('Comprimo le foto');
    notifyListeners();
    var last = 0;
    try {
      lastCompress = await PhotoCompressor.run(root, photos, p, trash,
          onProgress: (d, t, saved) {
        photoProgress.update(d, t);
        photoSaved = saved;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - last > 300 || d == t) {
          last = now;
          notifyListeners();
        }
      }, isCancelled: () => _cancelPhotos);
    } finally {
      photoProgress.stop();
      trashItems = await trash.list();
      notifyListeners();
    }
    // le dimensioni sono cambiate: ricalcolo la mappa
    await scan();
  }

  void stopPhotos() => _cancelPhotos = true;

  /// Svuota dal cestino gli originali delle foto appena compresse.
  Future<int> purgeCompressedOriginals() async {
    final which = lastCompress?.originals.toSet() ?? {};
    final items =
        trashItems.where((i) => which.contains(i.originalPath)).toList();
    return purge(items);
  }

  // ---- cestino ----
  Future<int> moveToTrash(Iterable<String> paths) async {
    final moved = await trash.moveIn(paths.toList());
    final gone = moved.toSet();
    final goneDirs = [for (final p in moved) '$p/'];
    bool isGone(String p) =>
        gone.contains(p) || goneDirs.any((d) => p.startsWith(d));
    final mediaPaths = <String>[
      for (final f in index!.files)
        if (isGone(f.path)) f.path,
    ];
    await Native.scanMedia(mediaPaths.take(500).toList());
    final r = root;
    final keep = index!.files.where((f) => !isGone(f.path)).toList();
    index = await _buildIndex(r, keep);
    emptyDirs = emptyDirs.where((d) => !isGone(d)).toList();
    if (docs != null) {
      docs = DocAnalysis(
        docs!.docs.where((d) => !isGone(d.file.path)).toList(),
        [
          for (final g in docs!.duplicateGroups)
            if (g.where((d) => !isGone(d.file.path)).length > 1)
              g.where((d) => !isGone(d.file.path)).toList(),
        ],
      );
    }
    if (fileDuplicates != null) {
      fileDuplicates = [
        for (final g in fileDuplicates!)
          if (g.where((f) => !isGone(f.path)).length > 1)
            g.where((f) => !isGone(f.path)).toList(),
      ];
    }
    trashItems = await trash.list();
    notifyListeners();
    return moved.length;
  }

  /// Elimina subito: passa dal cestino (stesso codice sicuro) e lo svuota
  /// solo di questi elementi.
  Future<({int count, int freed})> deleteNow(Iterable<String> paths) async {
    final list = paths.toList();
    final moved = await moveToTrash(list);
    final which = list.toSet();
    final items =
        trashItems.where((i) => which.contains(i.originalPath)).toList();
    return (count: moved, freed: await purge(items));
  }

  /// Pulisce un insieme misto: cartelle vuote eliminate, il resto nel
  /// cestino oppure eliminato subito ([now]).
  Future<({int count, int freed})> clean(
      Iterable<String> paths, Set<String> emptyDirsToDelete,
      {required bool now}) async {
    final empties = await deleteEmptyDirs(emptyDirsToDelete);
    final rest = paths.where((p) => !emptyDirsToDelete.contains(p)).toList();
    if (rest.isEmpty) return (count: empties, freed: 0);
    if (now) {
      final r = await deleteNow(rest);
      return (count: r.count + empties, freed: r.freed);
    }
    return (count: await moveToTrash(rest) + empties, freed: 0);
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

  Future<void> refreshFree() async {
    final s = await Native.storageStats();
    deviceFree = s.free;
    notifyListeners();
  }
}
