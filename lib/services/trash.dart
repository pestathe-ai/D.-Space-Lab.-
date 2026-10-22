import 'dart:convert';
import 'dart:io';

/// Un file (o una cartella intera) nel cestino dell'app.
class TrashItem {
  TrashItem(this.trashPath, this.originalPath, this.size, this.deletedMs);
  final String trashPath;
  final String originalPath;
  final int size;
  final int deletedMs;

  DateTime get deleted => DateTime.fromMillisecondsSinceEpoch(deletedMs);

  Map<String, Object> toJson() =>
      {'t': trashPath, 'o': originalPath, 's': size, 'd': deletedMs};

  static TrashItem fromJson(Map<String, dynamic> m) => TrashItem(
      m['t'] as String, m['o'] as String, (m['s'] as num).toInt(),
      (m['d'] as num).toInt());
}

/// Cestino di sicurezza: i file vengono spostati (istantaneo, stessa memoria)
/// in una cartella nascosta e restano recuperabili per [keepDays] giorni.
class Trash {
  Trash(this.root, {this.keepDays = 30});

  final String root;
  final int keepDays;

  String get dir => '$root/.DSpaceLab/Cestino';
  File get _index => File('$root/.DSpaceLab/cestino.json');

  Future<List<TrashItem>> list() async {
    try {
      if (!await _index.exists()) return [];
      final l = jsonDecode(await _index.readAsString()) as List;
      return [for (final e in l) TrashItem.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<TrashItem> items) async {
    await _index.parent.create(recursive: true);
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final i in items) i.toJson()]));
    await tmp.rename(_index.path);
  }

  Future<void> _ensureDir() async {
    final d = Directory(dir);
    if (!await d.exists()) await d.create(recursive: true);
    final nomedia = File('$root/.DSpaceLab/.nomedia');
    if (!await nomedia.exists()) await nomedia.create();
  }

  /// Sposta nel cestino; restituisce i percorsi originali spostati.
  Future<List<String>> moveIn(List<String> paths, {DateTime? now}) async {
    await _ensureDir();
    final items = await list();
    final moved = <String>[];
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    var n = 0;
    for (final p in paths) {
      try {
        final isDir = await FileSystemEntity.isDirectory(p);
        final size = isDir ? await _dirSize(p) : await File(p).length();
        final name = p.substring(p.lastIndexOf('/') + 1);
        final dest = '$dir/${t}_${n++}_$name';
        if (isDir) {
          await Directory(p).rename(dest);
        } else {
          await File(p).rename(dest);
        }
        items.add(TrashItem(dest, p, size, t));
        moved.add(p);
      } catch (_) {}
    }
    await _write(items);
    return moved;
  }

  /// Rimette i file al loro posto (se il posto è occupato, aggiunge "(ripristinato)").
  Future<List<String>> restore(List<TrashItem> which) async {
    final items = await list();
    final keys = {for (final w in which) w.trashPath};
    final restored = <String>[];
    for (final it in items.where((i) => keys.contains(i.trashPath)).toList()) {
      try {
        var target = it.originalPath;
        if (await FileSystemEntity.type(target) !=
            FileSystemEntityType.notFound) {
          final dot = target.lastIndexOf('.');
          target = dot > target.lastIndexOf('/')
              ? '${target.substring(0, dot)} (ripristinato)${target.substring(dot)}'
              : '$target (ripristinato)';
        }
        await File(target).parent.create(recursive: true);
        if (await FileSystemEntity.isDirectory(it.trashPath)) {
          await Directory(it.trashPath).rename(target);
        } else {
          await File(it.trashPath).rename(target);
        }
        items.remove(it);
        restored.add(target);
      } catch (_) {}
    }
    await _write(items);
    return restored;
  }

  /// Elimina definitivamente; restituisce i byte liberati.
  Future<int> purge(List<TrashItem> which) async {
    final items = await list();
    final keys = {for (final w in which) w.trashPath};
    var freed = 0;
    for (final it in items.where((i) => keys.contains(i.trashPath)).toList()) {
      try {
        if (await FileSystemEntity.isDirectory(it.trashPath)) {
          await Directory(it.trashPath).delete(recursive: true);
        } else {
          final f = File(it.trashPath);
          if (await f.exists()) await f.delete();
        }
        freed += it.size;
        items.remove(it);
      } catch (_) {}
    }
    await _write(items);
    return freed;
  }

  static Future<int> _dirSize(String path) async {
    var total = 0;
    await for (final e
        in Directory(path).list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Svuota da solo ciò che è nel cestino da più di [keepDays] giorni.
  Future<int> purgeExpired({DateTime? now}) async {
    final limit = (now ?? DateTime.now())
        .subtract(Duration(days: keepDays))
        .millisecondsSinceEpoch;
    final old = (await list()).where((i) => i.deletedMs < limit).toList();
    return old.isEmpty ? 0 : purge(old);
  }
}
