import 'dart:io';

import 'package:d_space_lab/core/apps.dart';
import 'package:d_space_lab/core/cleanup.dart';
import 'package:d_space_lab/core/duplicates.dart';
import 'package:d_space_lab/core/eta.dart';
import 'package:d_space_lab/core/storage_index.dart';
import 'package:d_space_lab/services/trash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stima del tempo', () {
    test('velocità costante: stima giusta', () {
      final e = EtaEstimator(warmupMs: 1000);
      for (var s = 0; s <= 10; s++) {
        e.update(s * 10, 1000, nowMs: s * 1000); // 10 al secondo
      }
      // mancano 900 a 10/s = 90 s
      expect(e.remaining!.inSeconds, 90);
    });

    test('niente stima nei primi secondi', () {
      final e = EtaEstimator(warmupMs: 3000);
      e.update(1, 100, nowMs: 0);
      e.update(5, 100, nowMs: 1000);
      expect(e.remaining, isNull);
    });

    test('segue un rallentamento', () {
      final e = EtaEstimator(windowMs: 5000, warmupMs: 1000);
      var done = 0;
      for (var s = 0; s <= 10; s++) {
        e.update(done, 1000, nowMs: s * 1000);
        done += 50; // veloce
      }
      for (var s = 11; s <= 30; s++) {
        done += 5; // lento
        e.update(done, 1000, nowMs: s * 1000);
      }
      final left = 1000 - done;
      expect(e.remaining!.inSeconds, closeTo(left / 5, 2));
    });

    test('testo', () {
      expect(formatEta(const Duration(seconds: 20)), 'meno di un minuto');
      expect(formatEta(const Duration(seconds: 70)), 'circa 1 minuto');
      expect(formatEta(const Duration(minutes: 7, seconds: 10)), 'circa 7 minuti');
      expect(formatEta(const Duration(minutes: 83)), 'circa 1 h 25 min');
      expect(formatElapsed(const Duration(seconds: 65)), '1 min 05 s');
    });
  });

  group('file inutili', () {
    const r = '/s';
    final now = DateTime(2026, 10, 22).millisecondsSinceEpoch;
    final old = DateTime(2026, 10, 1).millisecondsSinceEpoch;
    final files = [
      FileEntry('/s/DCIM/.thumbnails/1.jpg', 100, old),
      FileEntry('/s/DCIM/Camera/foto.jpg', 5000, old),
      FileEntry('/s/app/logs/debug.log', 30, old),
      FileEntry('/s/app/x.log.2', 20, old),
      FileEntry('/s/Download/film.mp4.crdownload', 900, old),
      FileEntry('/s/Download/nuovo.crdownload', 900, now),
      FileEntry('/s/Documents/~\$lettera.docx', 1, old),
      FileEntry('/s/Pictures/.trashed-1700000000-a.jpg', 70, old),
      FileEntry('/s/Download/app.apk', 400, old),
    ];
    final groups = findJunk(r, files,
        ['/s/Music', '/s/vecchia/vuota', '/s/Android/media', '/s/DCIM/Camera'],
        nowMs: now, installedApks: {'/s/Download/app.apk'});
    List<String> of(JunkKind k) =>
        groups.firstWhere((g) => g.kind == k).paths;

    test('categorie', () {
      expect(of(JunkKind.thumbnails), ['/s/DCIM/.thumbnails/1.jpg']);
      expect(of(JunkKind.logs), hasLength(2));
      expect(of(JunkKind.partial), ['/s/Download/film.mp4.crdownload']);
      expect(of(JunkKind.temp), ['/s/Documents/~\$lettera.docx']);
      expect(of(JunkKind.installedApks), ['/s/Download/app.apk']);
      expect(of(JunkKind.galleryTrash), hasLength(1));
      expect(groups.firstWhere((g) => g.kind == JunkKind.galleryTrash).preselected,
          isFalse);
    });

    test('le foto vere non sono mai inutili', () {
      for (final g in groups) {
        expect(g.paths, isNot(contains('/s/DCIM/Camera/foto.jpg')));
      }
    });

    test('cartelle vuote: le standard restano', () {
      expect(of(JunkKind.emptyDirs), ['/s/vecchia/vuota']);
    });
  });

  group('residui di app', () {
    const r = '/s';
    final idx = StorageIndex(r, const [
      FileEntry('/s/Android/media/com.vecchia.app/a.bin', 500, 0),
      FileEntry('/s/Android/media/com.whatsapp/WhatsApp/Media/x.jpg', 100, 0),
      FileEntry('/s/com.altra.app/cache/b.bin', 300, 0),
      FileEntry('/s/Foto.Vacanze/c.jpg', 50, 0),
    ]);
    final installed = {
      'com.whatsapp',
      for (var i = 0; i < 20; i++) 'com.sistema.app$i',
    };

    test('trova solo le cartelle di app non installate', () {
      final res = findResidues(r, idx, ['/s/Android/media/org.vuota'], installed);
      expect(res.map((e) => e.pkg),
          ['com.vecchia.app', 'com.altra.app', 'org.vuota']);
      expect(res.first.bytes, 500);
      expect(res.first.files, 1);
    });

    test('elenco app sospetto: nessun residuo', () {
      expect(findResidues(r, idx, const [], {'com.whatsapp'}), isEmpty);
    });
  });

  group('WhatsApp', () {
    const r = '/s';
    test('tipi, inviati, Business', () {
      final a = whatsappInfo(r,
          '/s/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes/202442/PTT-1.opus')!;
      expect(a.kind, WaKind.voice);
      expect(a.sent, isFalse);
      final b = whatsappInfo(r,
          '/s/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent/IMG-1.jpg')!;
      expect(b.kind, WaKind.images);
      expect(b.sent, isTrue);
      final c = whatsappInfo(r,
          '/s/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video/v.mp4')!;
      expect(c.kind, WaKind.video);
      expect(c.business, isTrue);
      expect(whatsappInfo(r, '/s/WhatsApp/Media/.Statuses/s.jpg')!.kind,
          WaKind.statuses);
      expect(whatsappInfo(r,
              '/s/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/.nomedia'),
          isNull);
      expect(whatsappInfo(r, '/s/DCIM/Camera/x.jpg'), isNull);
    });
  });

  group('duplicati', () {
    test('trova i file identici e tiene l\'originale', () async {
      final root = (await Directory.systemTemp.createTemp('dsl')).path;
      final big = List<int>.generate(200000, (i) => i % 251);
      final other = [...big]..[100000] = 7; // stessa dimensione, diverso in mezzo
      File('$root/DCIM/a.jpg')..createSync(recursive: true)..writeAsBytesSync(big);
      File('$root/Download/a (1).jpg')..createSync(recursive: true)..writeAsBytesSync(big);
      File('$root/Download/b.jpg').writeAsBytesSync(other);
      File('$root/Download/piccolo1.txt').writeAsStringSync('ciao');
      File('$root/Download/piccolo2.txt').writeAsStringSync('ciao');
      final files = walkStorage(root);
      final phases = <int>{};
      final groups = findDuplicateFiles(files,
          minSize: 1000, onProgress: (p, d, t) => phases.add(p));
      expect(groups, hasLength(1));
      expect(groups.first.map((f) => f.path),
          ['$root/DCIM/a.jpg', '$root/Download/a (1).jpg']);
      expect(phases, {1, 2});
      await Directory(root).delete(recursive: true);
    });

    test('file piccoli identici', () async {
      final root = (await Directory.systemTemp.createTemp('dsl')).path;
      File('$root/x.txt').writeAsStringSync('stesso testo');
      File('$root/y.txt').writeAsStringSync('stesso testo');
      final groups = findDuplicateFiles(walkStorage(root), minSize: 1);
      expect(groups.single, hasLength(2));
      await Directory(root).delete(recursive: true);
    });
  });

  group('app', () {
    final now = DateTime(2026, 10, 22).millisecondsSinceEpoch;
    int daysAgo(int d) => now - d * 24 * 3600 * 1000;
    test('inutilizzate', () {
      expect(AppInfo(pkg: 'a', label: 'A', lastUsedMs: daysAgo(90), installedMs: daysAgo(400))
          .isUnused(now), isTrue);
      expect(AppInfo(pkg: 'b', label: 'B', lastUsedMs: daysAgo(3), installedMs: daysAgo(400))
          .isUnused(now), isFalse);
      // mai usata ma installata ieri: non ancora inutilizzata
      expect(AppInfo(pkg: 'c', label: 'C', installedMs: daysAgo(1)).isUnused(now),
          isFalse);
      expect(idleLabel(400), 'non usata da oltre un anno');
      expect(idleLabel(95), 'non usata da 3 mesi');
    });
  });

  group('cestino con cartelle', () {
    test('una cartella intera va e torna', () async {
      final root = (await Directory.systemTemp.createTemp('dsl')).path;
      File('$root/com.vecchia.app/a/b.bin')
        ..createSync(recursive: true)
        ..writeAsStringSync('12345');
      final t = Trash(root);
      final moved = await t.moveIn(['$root/com.vecchia.app']);
      expect(moved, ['$root/com.vecchia.app']);
      expect(Directory('$root/com.vecchia.app').existsSync(), isFalse);
      final items = await t.list();
      expect(items.single.size, 5);
      await t.restore(items);
      expect(File('$root/com.vecchia.app/a/b.bin').readAsStringSync(), '12345');
      await t.moveIn(['$root/com.vecchia.app']);
      expect(await t.purge(await t.list()), 5);
      expect(Directory(t.dir).listSync(), isEmpty);
      await Directory(root).delete(recursive: true);
    });
  });
}
