import 'dart:io';

import 'file_types.dart';

class FileEntry {
  const FileEntry(this.path, this.size, this.modifiedMs);
  final String path;
  final int size;
  final int modifiedMs;

  String get name => nameOf(path);
  String get dir => parentOf(path);
  FileKind get kind => kindOf(path);
  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(modifiedMs);
}

/// Indice della memoria: file, dimensioni per cartella, totali per tipo.
class StorageIndex {
  StorageIndex(this.root, this.files) {
    for (final f in files) {
      kindTotals[f.kind] = (kindTotals[f.kind] ?? 0) + f.size;
      kindCounts[f.kind] = (kindCounts[f.kind] ?? 0) + 1;
      filesByDir.putIfAbsent(f.dir, () => []).add(f);
      // somma la dimensione su tutte le cartelle antenate fino alla radice
      var d = f.dir;
      while (true) {
        dirSizes[d] = (dirSizes[d] ?? 0) + f.size;
        if (d == root || d.length <= root.length) break;
        final p = parentOf(d);
        childDirs.putIfAbsent(p, () => <String>{}).add(d);
        d = p;
      }
    }
  }

  final String root;
  final List<FileEntry> files;
  final Map<String, int> dirSizes = {};
  final Map<String, Set<String>> childDirs = {};
  final Map<String, List<FileEntry>> filesByDir = {};
  final Map<FileKind, int> kindTotals = {};
  final Map<FileKind, int> kindCounts = {};

  int get totalBytes => dirSizes[root] ?? 0;

  late final Map<String, int> sizeOf = {for (final f in files) f.path: f.size};

  /// Contenuto di una cartella: sottocartelle e file, dal più grande.
  List<({String path, int size, bool isDir, FileEntry? file})> listDir(
      String dir) {
    final out = <({String path, int size, bool isDir, FileEntry? file})>[
      for (final d in childDirs[dir] ?? const <String>{})
        (path: d, size: dirSizes[d] ?? 0, isDir: true, file: null),
      for (final f in filesByDir[dir] ?? const <FileEntry>[])
        (path: f.path, size: f.size, isDir: false, file: f),
    ];
    out.sort((a, b) => b.size.compareTo(a.size));
    return out;
  }

  List<FileEntry> largest(FileKind? kind, {int limit = 200}) {
    final l = kind == null
        ? [...files]
        : files.where((f) => f.kind == kind).toList();
    l.sort((a, b) => b.size.compareTo(a.size));
    return l.length > limit ? l.sublist(0, limit) : l;
  }
}

/// Cartelle da non toccare: inaccessibili o nostre.
bool isExcluded(String root, String path) {
  final rel = path.length > root.length ? path.substring(root.length + 1) : '';
  return rel == 'Android/data' ||
      rel == 'Android/obb' ||
      rel.startsWith('.DSpaceLab');
}

/// Percorre la memoria (da chiamare in un isolate: è lento).
///
/// [emptyDirs] riceve le cartelle senza nulla dentro; [onCount] viene
/// chiamato ogni tanto con il numero di file trovati finora.
List<FileEntry> walkStorage(String root,
    {List<String>? emptyDirs, void Function(int files)? onCount}) {
  final out = <FileEntry>[];
  final stack = <Directory>[Directory(root)];
  var lastReport = 0;
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    List<FileSystemEntity> items;
    try {
      items = dir.listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    if (items.isEmpty && dir.path != root) emptyDirs?.add(dir.path);
    for (final e in items) {
      if (isExcluded(root, e.path)) continue;
      if (e is Directory) {
        stack.add(e);
      } else if (e is File) {
        try {
          final st = e.statSync();
          out.add(FileEntry(
              e.path, st.size, st.modified.millisecondsSinceEpoch));
        } catch (_) {}
      }
    }
    if (onCount != null && out.length - lastReport >= 400) {
      lastReport = out.length;
      onCount(out.length);
    }
  }
  onCount?.call(out.length);
  return out;
}
