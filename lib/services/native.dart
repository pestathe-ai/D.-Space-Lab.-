import 'package:flutter/services.dart';

import '../core/apps.dart';

class Native {
  static const _ch = MethodChannel('dspacelab/native');

  /// Testo dell'ultimo errore grave (se l'app si era chiusa da sola).
  static Future<String?> lastCrash() async {
    try {
      return await _ch.invokeMethod<String>('lastCrash');
    } catch (_) {
      return null;
    }
  }

  static Future<int> sdkInt() async =>
      (await _ch.invokeMethod<int>('sdkInt')) ?? 0;
  static Future<bool> hasAllFiles() async =>
      (await _ch.invokeMethod<bool>('hasAllFiles')) ?? false;
  static Future<void> requestAllFiles() => _ch.invokeMethod('requestAllFiles');
  static Future<String> storageRoot() async =>
      (await _ch.invokeMethod<String>('storageRoot')) ?? '/storage/emulated/0';

  static Future<({int total, int free})> storageStats() async {
    final m = await _ch.invokeMapMethod<String, dynamic>('storageStats');
    return (
      total: (m?['total'] as num?)?.toInt() ?? 0,
      free: (m?['free'] as num?)?.toInt() ?? 0,
    );
  }

  /// Avvisa la Galleria che questi percorsi sono cambiati.
  static Future<void> scanMedia(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _ch.invokeMethod('scanMedia', {'paths': paths});
    } catch (_) {}
  }

  static Future<bool> openFile(String path) async {
    try {
      return (await _ch.invokeMethod<bool>('openFile', {'path': path})) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---- app ----
  static Future<Set<String>> installedPackages() async {
    try {
      final l = await _ch.invokeListMethod<String>('installedPackages');
      return {...?l};
    } catch (_) {
      return {};
    }
  }

  /// Tra questi APK, quelli la cui app è già installata.
  static Future<Set<String>> installedApks(List<String> paths) async {
    if (paths.isEmpty) return {};
    try {
      final l = await _ch.invokeListMethod<String>('installedApks', {'paths': paths});
      return {...?l};
    } catch (_) {
      return {};
    }
  }

  static Future<bool> hasUsageAccess() async =>
      (await _ch.invokeMethod<bool>('hasUsageAccess')) ?? false;
  static Future<void> requestUsageAccess() =>
      _ch.invokeMethod('requestUsageAccess');

  static Future<List<AppInfo>> appsInfo() async {
    final l = await _ch.invokeListMethod<Map<dynamic, dynamic>>('appsInfo');
    return [for (final m in l ?? const <Map<dynamic, dynamic>>[]) AppInfo.fromMap(m)];
  }

  static Future<void> openAppSettings(String pkg) =>
      _ch.invokeMethod('openAppSettings', {'pkg': pkg});
  static Future<void> uninstall(String pkg) =>
      _ch.invokeMethod('uninstall', {'pkg': pkg});

  // ---- foto ----
  /// Nuova dimensione in byte, o -1 se la foto non si è potuta leggere.
  static Future<int> compressJpeg(String src, String dst,
          {required int quality, required int maxSide}) async =>
      (await _ch.invokeMethod<int>('compressJpeg', {
        'src': src,
        'dst': dst,
        'quality': quality,
        'maxSide': maxSide,
      })) ??
      -1;

  // ---- notifiche e pulizia programmata ----
  static Future<bool> hasNotifications() async =>
      (await _ch.invokeMethod<bool>('hasNotifications')) ?? false;
  static Future<void> requestNotifications() =>
      _ch.invokeMethod('requestNotifications');

  static Future<Map<String, dynamic>> getSchedule() async =>
      (await _ch.invokeMapMethod<String, dynamic>('getSchedule')) ?? {};
  static Future<void> setSchedule(
          {required bool enabled, required int days, required bool thumbs}) =>
      _ch.invokeMethod(
          'setSchedule', {'enabled': enabled, 'days': days, 'thumbs': thumbs});
  static Future<void> runCleanupNow() => _ch.invokeMethod('runCleanupNow');
}
