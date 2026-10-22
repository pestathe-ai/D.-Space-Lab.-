import 'package:d_space_lab/core/file_types.dart';
import 'package:d_space_lab/core/origin.dart';
import 'package:d_space_lab/core/storage_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const r = '/s';
  test('provenienza', () {
    Origin o(String p) => originOf(r, '/s/$p');
    expect(o('DCIM/Camera/IMG_1.jpg'), Origin.camera);
    expect(o('DCIM/.thumbnails/123.jpg'), Origin.thumbnails);
    expect(o('Pictures/Screenshots/s.png'), Origin.screenshots);
    expect(o('DCIM/Screenshots/s.png'), Origin.screenshots);
    expect(o('Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers/a.webp'),
        Origin.stickers);
    expect(o('Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/a.jpg'),
        Origin.whatsapp);
    expect(o('Android/media/org.telegram.messenger/Telegram/Telegram Images/a.jpg'),
        Origin.telegram);
    expect(o('Download/foto.jpg'), Origin.downloads);
    expect(o('Android/media/com.spotify.music/cover.png'), Origin.appMedia);
    expect(o('Pictures/Instagram/a.jpg'), Origin.saved);
    expect(o('.cache/x/a.png'), Origin.hidden);
    expect(o('Pictures/.trashed-1700-a.jpg'), Origin.galleryTrash);
    expect(o('MiaCartella/a.png'), Origin.other);
    expect(Origin.thumbnails.advice, Advice.safe);
    expect(Origin.camera.advice, Advice.keep);
  });

  test('gruppi e cartelle principali', () {
    final files = const [
      FileEntry('/s/DCIM/Camera/a.jpg', 1000, 0),
      FileEntry('/s/DCIM/.thumbnails/1.jpg', 10, 0),
      FileEntry('/s/DCIM/.thumbnails/2.jpg', 10, 0),
      FileEntry('/s/Android/media/com.app.uno/img/x.png', 300, 0),
      FileEntry('/s/Android/media/com.app.due/y.png', 50, 0),
      FileEntry('/s/Music/s.mp3', 5000, 0),
    ];
    final g = groupByOrigin(r, files, kind: FileKind.image);
    expect(g.map((e) => e.origin),
        [Origin.camera, Origin.appMedia, Origin.thumbnails]);
    expect(g.last.files, hasLength(2));
    final top = topFolders(r, g[1].files);
    expect(top.first.dir, 'Android/media/com.app.uno');
    expect(top.first.bytes, 300);
  });

  test('versioni dello stesso documento', () {
    expect(baseDocName('Contratto affitto (1).pdf'), 'contratto affitto');
    expect(baseDocName('Contratto_affitto_v2_FIRMATO.pdf'), 'contratto affitto');
    expect(baseDocName('CV_Mario_2.docx'), 'cv mario');
    expect(baseDocName('Fattura 2024.pdf'), 'fattura 2024');
    final docs = const [
      FileEntry('/s/Download/Contratto affitto.pdf', 100, 1),
      FileEntry('/s/Download/Contratto_affitto_v2.pdf', 120, 3),
      FileEntry('/s/Documents/contratto-affitto-firmato.pdf', 130, 2),
      FileEntry('/s/Download/scan 1.pdf', 10, 1),
      FileEntry('/s/Download/scan 2.pdf', 20, 1),
      FileEntry('/s/Download/altro.pdf', 20, 1),
    ];
    final v = documentVersions(docs);
    expect(v, hasLength(1));
    expect(v.single.first.name, 'Contratto_affitto_v2.pdf'); // il più recente
  });
}
