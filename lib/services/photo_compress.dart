import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/storage_index.dart';
import 'native.dart';
import 'trash.dart';

class CompressPreset {
  const CompressPreset(this.name, this.quality, this.maxSide, this.description);
  final String name;
  final int quality;
  final int maxSide;
  final String description;
}

const compressPresets = [
  CompressPreset('Leggera', 85, 4096,
      'Differenza quasi invisibile. Risparmio tipico: un terzo.'),
  CompressPreset('Media', 80, 3264,
      'Ottima per guardarle sul telefono e in TV. Risparmio tipico: metà.'),
  CompressPreset('Forte', 70, 2048,
      'Per i ricordi da tenere ma che non stamperai. Risparmio tipico: tre quarti.'),
];

/// Ricorda le foto già compresse (o che non conveniva comprimere).
class _Done {
  _Done(this.map);
  final Map<String, dynamic> map;

  static Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/foto_compresse.json');

  static Future<_Done> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString());
        if (m is Map<String, dynamic>) return _Done(m);
      }
    } catch (_) {}
    return _Done({});
  }

  Future<void> save() async {
    try {
      final f = await _file();
      await File('${f.path}.tmp').writeAsString(jsonEncode(map));
      await File('${f.path}.tmp').rename(f.path);
    } catch (_) {}
  }

  bool contains(FileEntry f) => map[f.path] == f.size;
}

class CompressResult {
  CompressResult(this.compressed, this.saved, this.skipped, this.originals);
  final int compressed;
  final int saved;
  final int skipped;
  final List<String> originals; // percorsi delle foto ora compresse
}

class PhotoCompressor {
  static Future<Set<String>> alreadyDone(List<FileEntry> files) async {
    final d = await _Done.load();
    return {for (final f in files) if (d.contains(f)) f.path};
  }

  /// Comprime le foto una alla volta. L'originale va nel cestino (30 giorni
  /// per ripensarci); al suo posto resta la versione compressa, con la
  /// stessa data. Se il guadagno è sotto il 15% la foto non viene toccata.
  static Future<CompressResult> run(
    String root,
    List<FileEntry> photos,
    CompressPreset preset,
    Trash trash, {
    required void Function(int done, int total, int saved) onProgress,
    bool Function()? isCancelled,
  }) async {
    final record = await _Done.load();
    final tmpDir = Directory('$root/.DSpaceLab/tmp');
    await tmpDir.create(recursive: true);
    final tmp = '${tmpDir.path}/in_compressione.jpg';
    var done = 0, saved = 0, skipped = 0;
    final changed = <String>[];
    onProgress(0, photos.length, 0);
    for (final f in photos) {
      if (isCancelled?.call() ?? false) break;
      try {
        final newSize = await Native.compressJpeg(f.path, tmp,
            quality: preset.quality, maxSide: preset.maxSide);
        if (newSize > 0 && newSize < f.size * 0.85) {
          final moved = await trash.moveIn([f.path]);
          if (moved.isNotEmpty) {
            await File(tmp).rename(f.path);
            await File(f.path).setLastModified(f.modified);
            saved += f.size - newSize;
            changed.add(f.path);
            record.map[f.path] = newSize;
          }
        } else {
          skipped++;
          record.map[f.path] = f.size;
        }
      } catch (_) {
        skipped++;
      }
      try {
        if (await File(tmp).exists()) await File(tmp).delete();
      } catch (_) {}
      done++;
      onProgress(done, photos.length, saved);
      if (done % 20 == 0) await record.save();
    }
    await record.save();
    for (var i = 0; i < changed.length; i += 200) {
      await Native.scanMedia(changed.sublist(
          i, i + 200 > changed.length ? changed.length : i + 200));
    }
    return CompressResult(changed.length, saved, skipped, changed);
  }
}
