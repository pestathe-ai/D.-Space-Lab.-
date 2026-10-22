import 'dart:typed_data';

/// Un'app installata, con quanto occupa e quando è stata usata.
class AppInfo {
  AppInfo({
    required this.pkg,
    required this.label,
    this.appBytes = 0,
    this.dataBytes = 0,
    this.cacheBytes = 0,
    this.lastUsedMs = 0,
    this.installedMs = 0,
    this.icon,
  });

  final String pkg;
  final String label;
  final int appBytes;
  final int dataBytes; // comprende la cache
  final int cacheBytes;
  final int lastUsedMs; // 0 = mai usata nell'ultimo anno
  final int installedMs;
  final Uint8List? icon;

  int get totalBytes => appBytes + dataBytes;

  static AppInfo fromMap(Map<dynamic, dynamic> m) => AppInfo(
        pkg: m['pkg'] as String,
        label: (m['label'] as String?) ?? m['pkg'] as String,
        appBytes: (m['app'] as num?)?.toInt() ?? 0,
        dataBytes: (m['data'] as num?)?.toInt() ?? 0,
        cacheBytes: (m['cache'] as num?)?.toInt() ?? 0,
        lastUsedMs: (m['lastUsed'] as num?)?.toInt() ?? 0,
        installedMs: (m['installed'] as num?)?.toInt() ?? 0,
        icon: m['icon'] as Uint8List?,
      );

  /// Ultimo segno di vita: l'ultimo uso o, se mai usata, l'installazione.
  int get lastActivityMs =>
      lastUsedMs > installedMs ? lastUsedMs : installedMs;

  /// Non usata da almeno [days] giorni (e installata da almeno altrettanto).
  bool isUnused(int nowMs, {int days = 60}) =>
      nowMs - lastActivityMs > days * 24 * 3600 * 1000;

  /// Giorni dall'ultimo uso, per mostrarlo.
  int daysIdle(int nowMs) => (nowMs - lastActivityMs) ~/ (24 * 3600 * 1000);
}

String idleLabel(int days) {
  if (days >= 365) return 'non usata da oltre un anno';
  if (days >= 60) return 'non usata da ${days ~/ 30} mesi';
  if (days >= 1) return 'usata $days giorni fa';
  return 'usata oggi';
}
