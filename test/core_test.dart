import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:d_space_lab/core/doc_classifier.dart';
import 'package:d_space_lab/core/file_types.dart';
import 'package:d_space_lab/core/office_text.dart';
import 'package:d_space_lab/core/storage_index.dart';
import 'package:d_space_lab/services/trash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22);

  group('date', () {
    test('formati italiani e inglesi', () {
      final d = findDates('Partenza 12/03/2024, ritorno 15 marzo 2024. '
          'Issued Mar 2, 2023. Ordine 2025-01-31. Non valida 31/02/2024');
      expect(d, containsAll([
        DateTime(2024, 3, 12),
        DateTime(2024, 3, 15),
        DateTime(2023, 3, 2),
        DateTime(2025, 1, 31),
      ]));
      expect(d, isNot(contains(DateTime(2024, 3, 2)))); // 31/02 scartata
    });
  });

  group('classificazione', () {
    test('carta d\'imbarco passata = scaduta', () {
      final f = extractFacts('RYANAIR Boarding pass  Gate B12  Volo FR123  '
          'Data 12/03/2024');
      expect(classify(f, now), DocVerdict.expired);
    });
    test('biglietto futuro = non scaduto', () {
      final f = extractFacts('Trenitalia Biglietto Frecciarossa carrozza 5 '
          'posto 7A del 12/12/2026');
      expect(classify(f, now), isNot(DocVerdict.expired));
    });
    test('fattura di un volo: vince importante', () {
      final f = extractFacts('Fattura n. 12 Biglietto volo Roma-Milano 03/01/2024');
      expect(classify(f, now), DocVerdict.important);
    });
    test('busta paga = importante', () {
      final f = extractFacts('Cedolino paga mese di marzo 2024 - INPS');
      expect(classify(f, now), DocVerdict.important);
      expect(f.importantHits, contains('Busta paga'));
    });
    test('testo qualsiasi = altro', () {
      expect(classify(extractFacts('Lista della spesa: latte, pane'), now),
          DocVerdict.other);
    });
    test('salvataggio dei dati', () {
      final f = extractFacts('Coupon valido fino al 01/01/2025');
      final back = DocFacts.fromJson(
          jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>);
      expect(back.ticketHits, f.ticketHits);
      expect(back.latestDateMs, f.latestDateMs);
      expect(classify(back, now), DocVerdict.expired);
    });
    test('nomi da copia', () {
      expect(looksLikeCopyName('fattura (1).pdf'), isTrue);
      expect(looksLikeCopyName('Copia di contratto.docx'), isTrue);
      expect(looksLikeCopyName('fattura.pdf'), isFalse);
    });
  });

  group('testo dai file', () {
    test('docx', () {
      final a = Archive()
        ..add(ArchiveFile.string('word/document.xml',
            '<w:document><w:p><w:t>Contratto di affitto</w:t></w:p></w:document>'));
      final bytes = Uint8List.fromList(ZipEncoder().encode(a));
      expect(officeZipText(bytes), contains('Contratto di affitto'));
    });
    test('doc vecchio formato', () {
      final b = Uint8List.fromList(
          [0, 1, 2, ...latin1.encode('Polizza assicurativa'), 0, 3, 4]);
      expect(binaryRuns(b), contains('Polizza assicurativa'));
    });
    test('rtf', () {
      expect(rtfToText(r'{\rtf1\ansi {\b Biglietto} concerto}'),
          contains('Biglietto'));
    });
  });

  group('memoria', () {
    test('tipi e dimensioni per cartella', () {
      const r = '/s';
      final idx = StorageIndex(r, const [
        FileEntry('/s/DCIM/Camera/a.jpg', 100, 0),
        FileEntry('/s/DCIM/Camera/b.mp4', 300, 0),
        FileEntry('/s/Download/c.pdf', 50, 0),
        FileEntry('/s/x.txt', 5, 0),
      ]);
      expect(idx.totalBytes, 455);
      expect(idx.dirSizes['/s/DCIM'], 400);
      expect(idx.kindTotals[FileKind.video], 300);
      final top = idx.listDir('/s');
      expect(top.first.path, '/s/DCIM');
      expect(top.map((e) => e.path), containsAll(['/s/Download', '/s/x.txt']));
    });

    test('percorre le cartelle saltando Android/data e il cestino', () async {
      final root = (await Directory.systemTemp.createTemp('dsl')).path;
      File('$root/a/b.txt')..createSync(recursive: true)..writeAsStringSync('ciao');
      File('$root/Android/data/x/y.bin')..createSync(recursive: true)..writeAsStringSync('no');
      File('$root/.DSpaceLab/Cestino/z')..createSync(recursive: true)..writeAsStringSync('no');
      final files = walkStorage(root);
      expect(files.map((f) => f.path), ['$root/a/b.txt']);
      await Directory(root).delete(recursive: true);
    });
  });

  group('cestino', () {
    test('sposta, ripristina, svuota, scadenza 30 giorni', () async {
      final root = (await Directory.systemTemp.createTemp('dsl')).path;
      final a = File('$root/Download/a.pdf')
        ..createSync(recursive: true)
        ..writeAsStringSync('12345');
      final b = File('$root/Download/b.pdf')..writeAsStringSync('678');
      final t = Trash(root);

      final moved = await t.moveIn([a.path, b.path], now: DateTime(2026, 1, 1));
      expect(moved.length, 2);
      expect(a.existsSync(), isFalse);
      expect((await t.list()).length, 2);

      final itemA = (await t.list()).firstWhere((i) => i.originalPath == a.path);
      await t.restore([itemA]);
      expect(a.readAsStringSync(), '12345');

      // b è nel cestino dal 1 gennaio: dopo 31 giorni sparisce da solo
      final freed = await t.purgeExpired(now: DateTime(2026, 2, 1));
      expect(freed, 3);
      expect(await t.list(), isEmpty);
      await Directory(root).delete(recursive: true);
    });
  });
}
