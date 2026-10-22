/// Categorie di file per la mappa dello spazio.
enum FileKind { image, video, audio, document, archive, apk, other }

extension FileKindLabel on FileKind {
  String get label => switch (this) {
        FileKind.image => 'Immagini',
        FileKind.video => 'Video',
        FileKind.audio => 'Audio',
        FileKind.document => 'Documenti',
        FileKind.archive => 'Archivi',
        FileKind.apk => 'App (APK)',
        FileKind.other => 'Altro',
      };
}

const _image = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp', 'dng', 'raw',
  'tif', 'tiff', 'svg',
};
const _video = {
  'mp4', 'mkv', 'mov', 'avi', '3gp', 'webm', 'm4v', 'wmv', 'flv', 'ts',
};
const _audio = {
  'mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'flac', 'amr', 'wma', 'mid',
};
const docExtensions = {
  'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt', 'xls', 'xlsx', 'ods', 'csv',
  'ppt', 'pptx', 'odp', 'epub', 'md',
};
const _archive = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'};

String extensionOf(String path) {
  final slash = path.lastIndexOf('/');
  final dot = path.lastIndexOf('.');
  if (dot <= slash + 1) return '';
  return path.substring(dot + 1).toLowerCase();
}

String nameOf(String path) => path.substring(path.lastIndexOf('/') + 1);

String parentOf(String path) {
  final i = path.lastIndexOf('/');
  return i <= 0 ? '/' : path.substring(0, i);
}

FileKind kindOf(String path) {
  final e = extensionOf(path);
  if (_image.contains(e)) return FileKind.image;
  if (_video.contains(e)) return FileKind.video;
  if (_audio.contains(e)) return FileKind.audio;
  if (docExtensions.contains(e)) return FileKind.document;
  if (_archive.contains(e)) return FileKind.archive;
  if (e == 'apk' || e == 'xapk' || e == 'apks') return FileKind.apk;
  return FileKind.other;
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
