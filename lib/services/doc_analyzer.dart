import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/doc_classifier.dart';
import '../core/file_types.dart';
import '../core/office_text.dart';
import '../core/storage_index.dart';

class AnalyzedDoc {
  AnalyzedDoc(this.file, this.facts);
  final FileEntry file;
  final DocFacts facts;
  String? hash;

  DocVerdict verdict(DateTime now) => classify(facts, now);
}

class DocAnalysis {
  DocAnalysis(this.docs, this.duplicateGroups);
  final List<AnalyzedDoc> docs;

  /// Gruppi di file identici, il primo è quello da tenere.
  final List<List<AnalyzedDoc>> duplicateGroups;
}

String _key(FileEntry f) => '${f.path}|${f.size}|${f.modifiedMs}';

class _Cache {
  _Cache(this.map);
  final Map<String, dynamic> map;

  static Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/documenti_v1.json');

  static Future<_Cache> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString());
        if (m is Map<String, dynamic>) return _Cache(m);
      }
    } catch (_) {}
    return _Cache({});
  }

  Future<void> save(Set<String> keep) async {
    try {
      map.removeWhere((k, _) => !keep.contains(k));
      final f = await _file();
      await File('${f.path}.tmp').writeAsString(jsonEncode(map));
      await File('${f.path}.tmp').rename(f.path);
    } catch (_) {}
  }
}

class DocAnalyzer {
  static const _maxBytes = 40 * 1024 * 1024;

  static Future<DocAnalysis> analyze(
    List<FileEntry> files, {
    required void Function(int done, int total) onProgress,
    bool Function()? isCancelled,
  }) async {
    final docs = files.where((f) => f.kind == FileKind.document).toList();
    final cache = await _Cache.load();
    final out = <AnalyzedDoc>[];
    TextRecognizer? ocr;
    var done = 0, sinceSave = 0;

    try {
      for (final f in docs) {
        if (isCancelled?.call() ?? false) break;
        final k = _key(f);
        final c = cache.map[k];
        if (c is Map<String, dynamic>) {
          out.add(AnalyzedDoc(f, DocFacts.fromJson(c))..hash = c['h'] as String?);
        } else {
          var text = '';
          try {
            if (f.size <= _maxBytes) {
              text = await _extract(f, () => ocr ??= TextRecognizer());
            }
          } catch (_) {}
          final facts = extractFacts(text);
          out.add(AnalyzedDoc(f, facts));
          cache.map[k] = facts.toJson();
          if (++sinceSave >= 50) {
            sinceSave = 0;
            await cache.save(cache.map.keys.toSet());
          }
        }
        done++;
        if (done % 3 == 0 || done == docs.length) onProgress(done, docs.length);
      }
    } finally {
      await ocr?.close();
    }

    final groups = await _duplicates(out, cache);
    await cache.save({for (final d in out) _key(d.file)});
    return DocAnalysis(out, groups);
  }

  /// Doppioni esatti: stessa dimensione, poi stessa impronta SHA-1.
  static Future<List<List<AnalyzedDoc>>> _duplicates(
      List<AnalyzedDoc> docs, _Cache cache) async {
    final bySize = <int, List<AnalyzedDoc>>{};
    for (final d in docs) {
      if (d.file.size == 0) continue;
      bySize.putIfAbsent(d.file.size, () => []).add(d);
    }
    final byHash = <String, List<AnalyzedDoc>>{};
    for (final same in bySize.values.where((l) => l.length > 1)) {
      for (final d in same) {
        if (d.hash == null) {
          try {
            final path = d.file.path;
            d.hash = await Isolate.run(() async =>
                (await sha1.bind(File(path).openRead()).first).toString());
            final c = cache.map[_key(d.file)];
            if (c is Map<String, dynamic>) c['h'] = d.hash;
          } catch (_) {
            continue;
          }
        }
        byHash.putIfAbsent(d.hash!, () => []).add(d);
      }
    }
    final groups = byHash.values.where((l) => l.length > 1).toList();
    for (final g in groups) {
      g.sort(_keepFirst);
    }
    groups.sort((a, b) => (b.first.file.size * (b.length - 1))
        .compareTo(a.first.file.size * (a.length - 1)));
    return groups;
  }

  /// Si tiene: il nome che non sembra una copia, fuori da Download, il più vecchio.
  static int _keepFirst(AnalyzedDoc a, AnalyzedDoc b) {
    final ca = looksLikeCopyName(a.file.name), cb = looksLikeCopyName(b.file.name);
    if (ca != cb) return ca ? 1 : -1;
    final da = a.file.path.contains('/Download/'),
        db = b.file.path.contains('/Download/');
    if (da != db) return da ? 1 : -1;
    return a.file.modifiedMs.compareTo(b.file.modifiedMs);
  }

  static Future<String> _extract(
      FileEntry f, TextRecognizer Function() ocr) async {
    final ext = extensionOf(f.path);
    switch (ext) {
      case 'pdf':
        return _pdfText(f.path, ocr);
      case 'docx' || 'xlsx' || 'pptx' || 'odt' || 'ods' || 'odp':
        final bytes = await File(f.path).readAsBytes();
        return Isolate.run(() => officeZipText(bytes));
      case 'doc' || 'xls' || 'ppt':
        final bytes = await File(f.path).readAsBytes();
        return Isolate.run(() => binaryRuns(bytes));
      case 'rtf':
        return rtfToText(plainText(await File(f.path).readAsBytes()));
      case 'txt' || 'csv' || 'md':
        final raf = await File(f.path).open();
        try {
          return plainText(await raf.read(200 * 1024));
        } finally {
          await raf.close();
        }
      default:
        return '';
    }
  }

  static Future<String> _pdfText(
      String path, TextRecognizer Function() ocr) async {
    final doc = await PdfDocument.openFile(path);
    try {
      final buf = StringBuffer();
      final pages = doc.pages;
      for (var i = 0; i < pages.length && i < 6; i++) {
        final t = await pages[i].loadText();
        if (t != null) buf.writeln(t.fullText);
        if (buf.length > maxTextChars) break;
      }
      // Pochissimo testo: probabilmente una scansione. Leggo le prime pagine.
      if (buf.toString().replaceAll(RegExp(r'\s'), '').length < 40) {
        final tmp = File('${(await getTemporaryDirectory()).path}/pagina.png');
        for (var i = 0; i < pages.length && i < 2; i++) {
          final p = pages[i];
          const w = 1200;
          final h = (w * p.height / p.width).round().clamp(1, 4000);
          final img = await p.render(
              width: w,
              height: h,
              fullWidth: w.toDouble(),
              fullHeight: h.toDouble(),
              backgroundColor: 0xffffffff);
          if (img == null) continue;
          final ui.Image uiImg = await img.createImage();
          img.dispose();
          final png = await uiImg.toByteData(format: ui.ImageByteFormat.png);
          uiImg.dispose();
          if (png == null) continue;
          await tmp.writeAsBytes(png.buffer.asUint8List(), flush: true);
          final r = await ocr().processImage(InputImage.fromFilePath(tmp.path));
          buf.writeln(r.text);
        }
      }
      return buf.toString();
    } finally {
      await doc.dispose();
    }
  }
}
