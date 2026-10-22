import 'package:flutter/services.dart';

class Native {
  static const _ch = MethodChannel('dspacelab/native');

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
}
