import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const maxTextChars = 20000;

String _cap(String s) =>
    s.length > maxTextChars ? s.substring(0, maxTextChars) : s;

/// Testo da un file XML: toglie i tag, decodifica le entità principali.
String xmlToText(String xml) {
  final s = xml
      .replaceAll(RegExp(r'</(w:p|a:p|text:p|si|row)>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', '\'')
      .replaceAll(RegExp(r'[ \t]+'), ' ');
  return s;
}

/// Word, Excel, PowerPoint moderni e OpenDocument (sono archivi zip di XML).
String officeZipText(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return '';
  }
  final buf = StringBuffer();
  for (final f in zip.files) {
    if (!f.isFile) continue;
    final n = f.name;
    final wanted = n == 'word/document.xml' ||
        n == 'xl/sharedStrings.xml' ||
        (n.startsWith('ppt/slides/slide') && n.endsWith('.xml')) ||
        n == 'content.xml';
    if (!wanted) continue;
    try {
      buf.writeln(xmlToText(utf8.decode(f.content, allowMalformed: true)));
    } catch (_) {}
    if (buf.length > maxTextChars) break;
  }
  return _cap(buf.toString());
}

/// Vecchi formati binari (.doc, .xls, .ppt): sequenze di caratteri leggibili.
String binaryRuns(Uint8List bytes, {int minRun = 4}) {
  final buf = StringBuffer();
  final run = StringBuffer();
  void flush() {
    if (run.length >= minRun) buf.write('${run.toString()} ');
    run.clear();
  }

  for (var i = 0; i < bytes.length && buf.length < maxTextChars; i++) {
    final b = bytes[i];
    // ASCII stampabile o lettere accentate latin-1
    if ((b >= 32 && b < 127) || (b >= 0xC0 && b <= 0xFF)) {
      run.writeCharCode(b);
    } else if (b == 0 && run.isNotEmpty) {
      // testo UTF-16LE: byte zero tra i caratteri, lo saltiamo
      continue;
    } else {
      flush();
    }
  }
  flush();
  return _cap(buf.toString());
}

/// RTF: toglie le parole di controllo e le parentesi.
String rtfToText(String rtf) => _cap(rtf
    .replaceAll(RegExp(r'\\[a-z]+-?\d* ?'), ' ')
    .replaceAll(RegExp(r'[{}]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' '));

String plainText(Uint8List bytes) =>
    _cap(utf8.decode(bytes, allowMalformed: true));
