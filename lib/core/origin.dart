import 'cleanup.dart';
import 'file_types.dart';
import 'storage_index.dart';

/// Da dove arriva un file: serve a capire se è tuo o di un'app.
enum Origin {
  camera,
  screenshots,
  whatsapp,
  stickers,
  telegram,
  downloads,
  documents,
  saved,
  music,
  recordings,
  appMedia,
  thumbnails,
  galleryTrash,
  hidden,
  other,
}

/// Consiglio: quanto è sicuro eliminare.
enum Advice { safe, check, keep }

extension OriginText on Origin {
  String get label => switch (this) {
        Origin.camera => 'Fotocamera',
        Origin.screenshots => 'Screenshot',
        Origin.whatsapp => 'WhatsApp',
        Origin.stickers => 'Sticker di WhatsApp',
        Origin.telegram => 'Telegram',
        Origin.downloads => 'Scaricati (Download)',
        Origin.documents => 'Cartella Documenti',
        Origin.saved => 'Salvati in Immagini e Film',
        Origin.music => 'Musica e podcast',
        Origin.recordings => 'Registrazioni',
        Origin.appMedia => 'File delle app',
        Origin.thumbnails => 'Miniature',
        Origin.galleryTrash => 'Cestino della Galleria',
        Origin.hidden => 'Cartelle nascoste delle app',
        Origin.other => 'Altre cartelle',
      };

  Advice get advice => switch (this) {
        Origin.thumbnails || Origin.galleryTrash || Origin.telegram =>
          Advice.safe,
        Origin.camera || Origin.documents || Origin.music || Origin.recordings =>
          Advice.keep,
        _ => Advice.check,
      };

  String get explanation => switch (this) {
        Origin.camera =>
          'Le foto e i video che hai scattato. Sono tuoi: per fare spazio usa '
              'Duplicati o Comprimi foto.',
        Origin.screenshots =>
          'Catture dello schermo: spesso servono una volta sola. Guarda le più '
              'vecchie, di solito si possono togliere.',
        Origin.whatsapp =>
          'Ricevuti e inviati in chat. Restano anche nelle chat degli altri; '
              'quelli vecchi di solito non servono più.',
        Origin.stickers =>
          'Tanti file piccolissimi. Se li elimini spariscono dalle chat, ma si '
              'riscaricano quando qualcuno li rimanda.',
        Origin.telegram =>
          'Telegram tiene tutto sul suo cloud: eliminando la copia sul telefono '
              'la riscarichi quando la riapri.',
        Origin.downloads =>
          'Scaricati da internet o dalle app. Spesso dimenticati qui dopo averli '
              'aperti una volta.',
        Origin.documents => 'La tua cartella Documenti: di solito roba da tenere.',
        Origin.saved =>
          'Immagini e video salvati da app, editor o browser. Controlla: alcuni '
              'sono tuoi, altri sono copie.',
        Origin.music => 'La tua musica e i podcast scaricati.',
        Origin.recordings => 'Registrazioni vocali e chiamate: di solito tue.',
        Origin.appMedia =>
          'File scritti dalle app (immagini di anteprima, audio, scaricati). '
              'Di solito l\'app li ricrea o li riscarica.',
        Origin.thumbnails =>
          'Anteprime per la Galleria: il telefono le ricrea da solo. Sicuro '
              'eliminarle.',
        Origin.galleryTrash =>
          'Già eliminati dalla Galleria, in attesa di sparire: puoi '
              'anticipare.',
        Origin.hidden =>
          'Cartelle con il punto davanti: cache e dati di lavoro delle app.',
        Origin.other => 'File in cartelle create da altre app o da te.',
      };
}

bool _under(String rel, List<String> prefixes) =>
    prefixes.any((p) => rel == p || rel.startsWith('$p/'));

/// Riconosce la provenienza dal percorso.
Origin originOf(String root, String path) {
  final rel = relativeTo(root, path);
  final name = nameOf(path);
  if (rel.contains('/.thumbnails/') || rel.startsWith('.thumbnails/')) {
    return Origin.thumbnails;
  }
  if (name.toLowerCase().startsWith('.trashed-')) return Origin.galleryTrash;
  final wa = whatsappInfo(root, path);
  if (wa != null) {
    return wa.kind == WaKind.stickers ? Origin.stickers : Origin.whatsapp;
  }
  if (rel.startsWith('Android/media/com.whatsapp')) return Origin.whatsapp;
  if (_under(rel, ['Telegram', 'Android/media/org.telegram.messenger']) ||
      rel.startsWith('Android/media/org.telegram')) {
    return Origin.telegram;
  }
  if (rel.contains('Screenshots/') || rel.contains('Screen recordings/')) {
    return Origin.screenshots;
  }
  if (_under(rel, ['DCIM'])) return Origin.camera;
  if (_under(rel, ['Download', 'Downloads'])) return Origin.downloads;
  if (_under(rel, ['Documents'])) return Origin.documents;
  if (_under(rel, ['Music', 'Podcasts', 'Audiobooks'])) return Origin.music;
  if (_under(rel, ['Recordings', 'Sounds', 'Call', 'MIUI/sound_recorder'])) {
    return Origin.recordings;
  }
  if (_under(rel, ['Android/media'])) return Origin.appMedia;
  if (rel.split('/').any((s) => s.startsWith('.'))) return Origin.hidden;
  if (_under(rel, ['Pictures', 'Movies'])) return Origin.saved;
  return Origin.other;
}

/// Un gruppo di file con la stessa provenienza.
class OriginGroup {
  OriginGroup(this.origin, this.files);
  final Origin origin;
  final List<FileEntry> files;
  late final int bytes = files.fold(0, (s, f) => s + f.size);
}

/// File di un tipo (o tutti, se [kind] è null) divisi per provenienza,
/// dal gruppo più pesante.
List<OriginGroup> groupByOrigin(String root, List<FileEntry> files,
    {FileKind? kind, Origin Function(FileEntry f)? of}) {
  final m = <Origin, List<FileEntry>>{};
  for (final f in files) {
    if (kind != null && f.kind != kind) continue;
    m.putIfAbsent(of?.call(f) ?? originOf(root, f.path), () => []).add(f);
  }
  final out = [for (final e in m.entries) OriginGroup(e.key, e.value)];
  out.sort((a, b) => b.bytes.compareTo(a.bytes));
  return out;
}

/// Sottocartelle che pesano di più dentro un gruppo (es. quale app).
List<({String dir, int bytes, int count})> topFolders(
    String root, List<FileEntry> files,
    {int limit = 8}) {
  final m = <String, (int, int)>{};
  for (final f in files) {
    final rel = relativeTo(root, f.dir);
    final parts = rel.split('/');
    // per Android/media mostro il nome dell'app, altrimenti due livelli
    final depth = parts.length >= 3 && parts[0] == 'Android' && parts[1] == 'media'
        ? 3
        : 2;
    final key = parts.take(depth).join('/');
    final c = m[key] ?? (0, 0);
    m[key] = (c.$1 + f.size, c.$2 + 1);
  }
  final out = [
    for (final e in m.entries) (dir: e.key, bytes: e.value.$1, count: e.value.$2),
  ]..sort((a, b) => b.bytes.compareTo(a.bytes));
  return out.length > limit ? out.sublist(0, limit) : out;
}

// ---------------------------------------------------------------------------
// Documenti: versioni dello stesso file
// ---------------------------------------------------------------------------

final _copyMarks = RegExp(
    r'(\(\d+\)|\[\d+\]|\b(copia|copy|copy of|copia di|final[e]?|def|definitivo|'
    r'ultim[oa]|nuov[oa]|new|old|vecchi[oa]|bozza|draft|rev\d*|v\d+|ver\d+|'
    r'versione\s*\d+|firmat[oa]|signed)\b)',
    caseSensitive: false);

/// Nome "di base" di un documento: senza estensione, copie e versioni.
String baseDocName(String fileName) {
  var n = fileName;
  final dot = n.lastIndexOf('.');
  if (dot > 0) n = n.substring(0, dot);
  n = n.toLowerCase().replaceAll(RegExp(r'[_\-.]+'), ' ');
  n = n.replaceAll(_copyMarks, ' ');
  n = n.replaceAll(RegExp(r'\s\d{1,2}$'), ' '); // "contratto 2"
  n = n.replaceAll(RegExp(r'[^a-z0-9àèéìòù ]'), ' ');
  return n.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Gruppi di documenti che sembrano versioni dello stesso file.
/// Il primo di ogni gruppo è il più recente.
List<List<FileEntry>> documentVersions(List<FileEntry> docs) {
  final m = <String, List<FileEntry>>{};
  for (final f in docs) {
    final b = baseDocName(f.name);
    if (b.length < 4) continue; // nomi troppo generici ("scan", "doc")
    if (RegExp(r'^(img|scan|doc|document|documento|file|pdf)( \d+)*$')
        .hasMatch(b)) {
      continue;
    }
    m.putIfAbsent(b, () => []).add(f);
  }
  final out = <List<FileEntry>>[];
  for (final l in m.values) {
    if (l.length < 2) continue;
    // stessa dimensione e stesso nome sono doppioni, non versioni: li
    // trova già l'altra scheda; qui teniamo i gruppi con almeno 2 pesi diversi
    if (l.map((f) => f.size).toSet().length < 2) continue;
    l.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    out.add(l);
  }
  out.sort((a, b) => b.skip(1).fold<int>(0, (s, f) => s + f.size)
      .compareTo(a.skip(1).fold<int>(0, (s, f) => s + f.size)));
  return out;
}
