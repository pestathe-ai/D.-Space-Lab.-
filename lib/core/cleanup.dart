import 'file_types.dart';
import 'storage_index.dart';

// ---------------------------------------------------------------------------
// File inutili
// ---------------------------------------------------------------------------

enum JunkKind { thumbnails, logs, temp, partial, installedApks, galleryTrash, emptyDirs }

class JunkGroup {
  JunkGroup(this.kind, this.paths, this.bytes);
  final JunkKind kind;
  final List<String> paths;
  final int bytes;

  String get title => switch (kind) {
        JunkKind.thumbnails => 'Miniature',
        JunkKind.logs => 'File di log',
        JunkKind.temp => 'File temporanei',
        JunkKind.partial => 'Download interrotti',
        JunkKind.installedApks => 'Installer già usati',
        JunkKind.galleryTrash => 'Cestino della Galleria',
        JunkKind.emptyDirs => 'Cartelle vuote',
      };

  String get description => switch (kind) {
        JunkKind.thumbnails =>
          'Anteprime delle foto: il telefono le ricrea da solo se servono.',
        JunkKind.logs => 'Diari tecnici scritti dalle app, inutili a te.',
        JunkKind.temp => 'Avanzi di salvataggi e file di lavoro abbandonati.',
        JunkKind.partial =>
          'Download che non sono mai finiti (fermi da più di un giorno).',
        JunkKind.installedApks =>
          'File APK di app che hai già installato: non servono più.',
        JunkKind.galleryTrash =>
          'Foto e video già eliminati dalla Galleria, in attesa di sparire.',
        JunkKind.emptyDirs => 'Cartelle senza niente dentro.',
      };

  /// Selezionato in partenza: solo ciò che è sicuramente inutile.
  bool get preselected => kind != JunkKind.galleryTrash;
}

const _tempExt = {'tmp', 'temp', 'bak~'};
const _partialExt = {'crdownload', 'part', 'partial', 'opdownload'};
final _logName = RegExp(r'\.log(\.\d+)?$', caseSensitive: false);

/// Cartelle standard che non vanno toccate nemmeno se vuote.
const _protectedTop = {
  'Android', 'DCIM', 'Download', 'Downloads', 'Pictures', 'Music', 'Movies',
  'Documents', 'Alarms', 'Notifications', 'Ringtones', 'Podcasts',
  'Audiobooks', 'Recordings', 'Screenshots',
};

String relativeTo(String root, String path) =>
    path.length > root.length ? path.substring(root.length + 1) : '';

bool _isProtectedDir(String root, String dir) {
  final rel = relativeTo(root, dir);
  if (rel.isEmpty) return true;
  final parts = rel.split('/');
  if (parts.first.startsWith('.DSpaceLab')) return true;
  if (parts.length == 1 && _protectedTop.contains(parts.first)) return true;
  if (parts.first == 'Android' && parts.length <= 2) return true;
  if (parts.length == 2 && parts.first == 'DCIM' && parts[1] == 'Camera') {
    return true;
  }
  return false;
}

/// [installedApks] sono i percorsi degli APK la cui app è già installata
/// nella stessa versione o in una più recente.
List<JunkGroup> findJunk(
  String root,
  List<FileEntry> files,
  List<String> emptyDirs, {
  required int nowMs,
  Set<String> installedApks = const {},
}) {
  final byKind = <JunkKind, List<FileEntry>>{};
  void add(JunkKind k, FileEntry f) => byKind.putIfAbsent(k, () => []).add(f);
  const day = 24 * 3600 * 1000;

  for (final f in files) {
    final name = f.name;
    final lower = name.toLowerCase();
    final ext = extensionOf(f.path);
    if (f.path.contains('/.thumbnails/')) {
      add(JunkKind.thumbnails, f);
    } else if (lower.startsWith('.trashed-')) {
      add(JunkKind.galleryTrash, f);
    } else if (_logName.hasMatch(name)) {
      add(JunkKind.logs, f);
    } else if (_tempExt.contains(ext) ||
        lower.startsWith(r'~$') ||
        lower == 'thumbs.db' ||
        lower == '.ds_store' ||
        (name.endsWith('~') && name.length > 1)) {
      add(JunkKind.temp, f);
    } else if (_partialExt.contains(ext) && nowMs - f.modifiedMs > day) {
      add(JunkKind.partial, f);
    } else if (installedApks.contains(f.path)) {
      add(JunkKind.installedApks, f);
    }
  }

  final out = <JunkGroup>[
    for (final k in JunkKind.values)
      if (byKind[k] != null)
        JunkGroup(k, [for (final f in byKind[k]!) f.path],
            byKind[k]!.fold(0, (s, f) => s + f.size)),
  ];
  final empties = [
    for (final d in emptyDirs)
      if (!_isProtectedDir(root, d)) d,
  ]..sort();
  if (empties.isNotEmpty) out.add(JunkGroup(JunkKind.emptyDirs, empties, 0));
  out.sort((a, b) => b.bytes.compareTo(a.bytes));
  return out;
}

// ---------------------------------------------------------------------------
// Residui di app disinstallate
// ---------------------------------------------------------------------------

class Residue {
  Residue(this.dir, this.pkg, this.bytes, this.files);
  final String dir;
  final String pkg;
  final int bytes;
  final int files;
}

final _pkgName = RegExp(r'^[a-z][a-z0-9_]*(\.[a-zA-Z0-9_]+)+$');

bool looksLikePackage(String name) => _pkgName.hasMatch(name);

/// Cartelle che portano il nome di un'app non più installata.
///
/// Cerca in Android/media e tra le cartelle principali che hanno la forma
/// di un nome di pacchetto (es. com.esempio.app). Se l'elenco delle app
/// installate sembra incompleto non segnala nulla, per sicurezza.
List<Residue> findResidues(
  String root,
  StorageIndex idx,
  List<String> emptyDirs,
  Set<String> installed, {
  String self = 'dev.dspacelab.d_space_lab',
}) {
  if (installed.length < 15) return const [];
  final media = '$root/Android/media';
  final candidates = <String>{
    ...?idx.childDirs[media],
    for (final d in emptyDirs)
      if (parentOf(d) == media) d,
    for (final d in idx.childDirs[root] ?? const <String>{})
      if (looksLikePackage(nameOf(d))) d,
    for (final d in emptyDirs)
      if (parentOf(d) == root && looksLikePackage(nameOf(d))) d,
  };
  final out = <Residue>[];
  for (final d in candidates) {
    final pkg = nameOf(d);
    if (!looksLikePackage(pkg) || pkg == self || installed.contains(pkg)) {
      continue;
    }
    var n = 0;
    for (final e in idx.filesByDir.entries) {
      if (e.key == d || e.key.startsWith('$d/')) n += e.value.length;
    }
    out.add(Residue(d, pkg, idx.dirSizes[d] ?? 0, n));
  }
  out.sort((a, b) => b.bytes.compareTo(a.bytes));
  return out;
}

// ---------------------------------------------------------------------------
// WhatsApp
// ---------------------------------------------------------------------------

enum WaKind { images, video, voice, audio, documents, gifs, stickers, videoNotes, statuses, other }

extension WaKindLabel on WaKind {
  String get label => switch (this) {
        WaKind.images => 'Foto',
        WaKind.video => 'Video',
        WaKind.voice => 'Vocali',
        WaKind.audio => 'Audio',
        WaKind.documents => 'Documenti',
        WaKind.gifs => 'GIF',
        WaKind.stickers => 'Sticker',
        WaKind.videoNotes => 'Videomessaggi',
        WaKind.statuses => 'Stati salvati',
        WaKind.other => 'Altro',
      };
}

class WaInfo {
  const WaInfo(this.kind, {this.sent = false, this.business = false});
  final WaKind kind;
  final bool sent;
  final bool business;
}

/// Riconosce i file multimediali di WhatsApp (normale e Business).
WaInfo? whatsappInfo(String root, String path) {
  const bases = [
    ('Android/media/com.whatsapp/WhatsApp/Media/', false),
    ('Android/media/com.whatsapp.w4b/WhatsApp Business/Media/', true),
    ('WhatsApp/Media/', false),
    ('WhatsApp Business/Media/', true),
  ];
  final rel = relativeTo(root, path);
  for (final (base, business) in bases) {
    if (!rel.startsWith(base)) continue;
    final rest = rel.substring(base.length);
    final slash = rest.indexOf('/');
    if (slash < 0) return null; // file direttamente in Media
    if (nameOf(path).startsWith('.')) return null; // .nomedia e simili
    var folder = rest.substring(0, slash);
    for (final p in ['WhatsApp Business ', 'WhatsApp ']) {
      if (folder.startsWith(p)) {
        folder = folder.substring(p.length);
        break;
      }
    }
    final kind = switch (folder) {
      'Images' => WaKind.images,
      'Video' => WaKind.video,
      'Voice Notes' => WaKind.voice,
      'Audio' => WaKind.audio,
      'Documents' => WaKind.documents,
      'Animated Gifs' => WaKind.gifs,
      'Stickers' => WaKind.stickers,
      'Video Notes' => WaKind.videoNotes,
      '.Statuses' => WaKind.statuses,
      _ => WaKind.other,
    };
    final sent = rest.contains('/Sent/') || rest.contains('/Private/');
    return WaInfo(kind, sent: sent, business: business);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Foto da comprimere
// ---------------------------------------------------------------------------

bool isCompressCandidate(String root, FileEntry f, {int minBytes = 1500000}) {
  final ext = extensionOf(f.path);
  if (ext != 'jpg' && ext != 'jpeg') return false;
  if (f.size < minBytes) return false;
  if (f.name.startsWith('.')) return false;
  if (f.path.contains('/.thumbnails/') || f.path.contains('/.DSpaceLab')) {
    return false;
  }
  return true;
}
