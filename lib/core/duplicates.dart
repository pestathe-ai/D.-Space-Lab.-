import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'doc_classifier.dart' show looksLikeCopyName;
import 'storage_index.dart';

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest d) => value = d;
  @override
  void close() {}
}

const _chunk = 1 << 20;
const _edge = 16 * 1024;

/// Impronta SHA-1 dell'intero file (lettura sincrona, per gli isolate).
String sha1OfFile(String path, {void Function(int bytes)? onBytes}) {
  final sink = _DigestSink();
  final conv = sha1.startChunkedConversion(sink);
  final raf = File(path).openSync();
  try {
    final buf = Uint8List(_chunk);
    while (true) {
      final n = raf.readIntoSync(buf);
      if (n <= 0) break;
      conv.add(n == _chunk ? buf : Uint8List.sublistView(buf, 0, n));
      onBytes?.call(n);
    }
  } finally {
    raf.closeSync();
  }
  conv.close();
  return sink.value.toString();
}

/// Impronta veloce: inizio e fine del file. Due file diversi possono
/// averla uguale, quindi serve solo a scartare in fretta.
String quickPrint(String path, int size) {
  final raf = File(path).openSync();
  try {
    final sink = _DigestSink();
    final conv = sha1.startChunkedConversion(sink);
    conv.add(raf.readSync(_edge));
    if (size > 2 * _edge) {
      raf.setPositionSync(size - _edge);
      conv.add(raf.readSync(_edge));
    }
    conv.close();
    return sink.value.toString();
  } finally {
    raf.closeSync();
  }
}

/// Punteggio per scegliere quale copia tenere: più basso = da tenere.
int _placeScore(String path) {
  if (path.contains('/DCIM/') || path.contains('/Pictures/')) return 0;
  if (path.contains('/Documents/') || path.contains('/Music/')) return 1;
  if (path.contains('/WhatsApp')) return 3;
  if (path.contains('/Download/')) return 4;
  return 2;
}

/// Ordina le copie: prima quella da tenere.
int keepFirst(FileEntry a, FileEntry b) {
  final ca = looksLikeCopyName(a.name), cb = looksLikeCopyName(b.name);
  if (ca != cb) return ca ? 1 : -1;
  final pa = _placeScore(a.path), pb = _placeScore(b.path);
  if (pa != pb) return pa.compareTo(pb);
  return a.modifiedMs.compareTo(b.modifiedMs);
}

/// Avanzamento: [phase] 1 = controllo veloce, 2 = confronto completo.
typedef DupProgress = void Function(int phase, int done, int total);

/// Trova i file identici (stesso contenuto, byte per byte via SHA-1).
///
/// Prima raggruppa per dimensione, poi confronta inizio e fine del file,
/// e solo per i sospetti rimasti calcola l'impronta completa.
List<List<FileEntry>> findDuplicateFiles(
  List<FileEntry> files, {
  int minSize = 64 * 1024,
  DupProgress? onProgress,
  bool Function(FileEntry f)? skip,
}) {
  final bySize = <int, List<FileEntry>>{};
  for (final f in files) {
    if (f.size < minSize) continue;
    if (f.name.startsWith('.') || f.path.contains('/.thumbnails/')) continue;
    if (skip != null && skip(f)) continue;
    bySize.putIfAbsent(f.size, () => []).add(f);
  }
  final sameSize = [for (final l in bySize.values) if (l.length > 1) l];

  // Fase 1: impronta veloce.
  final total1 = sameSize.fold<int>(0, (s, l) => s + l.length);
  var done1 = 0;
  final suspects = <List<FileEntry>>[];
  for (final group in sameSize) {
    final byQuick = <String, List<FileEntry>>{};
    for (final f in group) {
      try {
        byQuick.putIfAbsent(quickPrint(f.path, f.size), () => []).add(f);
      } catch (_) {}
      done1++;
      if (done1 % 50 == 0) onProgress?.call(1, done1, total1);
    }
    suspects.addAll(byQuick.values.where((l) => l.length > 1));
  }
  onProgress?.call(1, total1, total1);

  // Fase 2: impronta completa (misurata in byte, per una stima giusta).
  final total2 = suspects.fold<int>(
      0, (s, l) => s + l.fold<int>(0, (t, f) => t + f.size));
  var done2 = 0, lastSent = 0;
  final out = <List<FileEntry>>[];
  for (final group in suspects) {
    final byHash = <String, List<FileEntry>>{};
    for (final f in group) {
      try {
        // file piccoli: l'impronta veloce li ha già letti per intero
        final h = f.size <= 2 * _edge
            ? quickPrint(f.path, f.size)
            : sha1OfFile(f.path, onBytes: (n) {
                done2 += n;
                if (done2 - lastSent > 8 * _chunk) {
                  lastSent = done2;
                  onProgress?.call(2, done2, total2);
                }
              });
        if (f.size <= 2 * _edge) done2 += f.size;
        byHash.putIfAbsent(h, () => []).add(f);
      } catch (_) {}
    }
    for (final l in byHash.values.where((l) => l.length > 1)) {
      l.sort(keepFirst);
      out.add(l);
    }
  }
  onProgress?.call(2, total2, total2);
  out.sort((a, b) =>
      (b.first.size * (b.length - 1)).compareTo(a.first.size * (a.length - 1)));
  return out;
}
