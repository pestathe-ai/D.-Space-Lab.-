import 'package:flutter/material.dart';

import '../core/apps.dart';
import '../core/file_types.dart';
import '../services/native.dart';
import 'app_state.dart';
import 'widgets.dart';

/// App: quanto pesa la cache, quali app non usi più.
class AppsPage extends StatefulWidget {
  const AppsPage({super.key, required this.state, this.initial = 0});
  final AppState state;
  final int initial;

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> with WidgetsBindingObserver {
  bool? _access;
  bool _loading = false;
  List<AppInfo> _apps = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // di ritorno dalle impostazioni o dalla disinstallazione: aggiorno
    if (s == AppLifecycleState.resumed) {
      _load();
      widget.state.refreshFree();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    final access = await Native.hasUsageAccess();
    if (!mounted) return;
    setState(() {
      _access = access;
      _loading = access;
    });
    if (!access) return;
    try {
      final apps = await Native.appsInfo();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_access == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('App')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.query_stats,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Quanto occupano le tue app',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Per vedere la cache di ogni app e quando l\'hai usata l\'ultima '
              'volta serve il permesso "Accesso ai dati di utilizzo". '
              'Resta tutto sul telefono.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: Native.requestUsageAccess,
              child: const Text('Apri impostazioni'),
            ),
            const SizedBox(height: 8),
            const Text('Cerca D. Space Lab, attiva l\'interruttore e torna qui.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final byCache = [..._apps]..sort((a, b) => b.cacheBytes.compareTo(a.cacheBytes));
    final unused = _apps.where((a) => a.isUnused(now)).toList()
      ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    final bySize = [..._apps]..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    final cacheTotal = _apps.fold<int>(0, (s, a) => s + a.cacheBytes);
    final unusedTotal = unused.fold<int>(0, (s, a) => s + a.totalBytes);

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initial,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('App'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Cache'),
              Tab(text: 'Inutilizzate'),
              Tab(text: 'Più pesanti'),
            ],
          ),
        ),
        body: _access == null || (_loading && _apps.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _apps.isEmpty
                ? Center(child: Text('Non riesco a leggere le app: $_error'))
                : TabBarView(
                    children: [
                      _list(
                        header: InfoCard(
                          icon: Icons.cached,
                          text: 'Cache totale: ${formatBytes(cacheTotal)}. '
                              'È roba che le app ricreano da sole. Tocca un\'app, '
                              'poi "Memoria" → "Svuota cache". Android non '
                              'permette a nessuna app di farlo al posto tuo '
                              'in modo affidabile.',
                        ),
                        apps: byCache.where((a) => a.cacheBytes > 0).toList(),
                        trailing: (a) => formatBytes(a.cacheBytes),
                        subtitle: (a) => 'App e dati: ${formatBytes(a.totalBytes)}',
                        onTap: (a) => Native.openAppSettings(a.pkg),
                      ),
                      _list(
                        header: InfoCard(
                          icon: Icons.hourglass_empty,
                          text: unused.isEmpty
                              ? 'Nessuna app ferma da più di due mesi.'
                              : '${unused.length} app non usate da più di due mesi '
                                  'occupano ${formatBytes(unusedTotal)}. '
                                  'Tocca "Disinstalla": la conferma la chiede Android.',
                        ),
                        apps: unused,
                        trailing: (a) => formatBytes(a.totalBytes),
                        subtitle: (a) => idleLabel(a.daysIdle(now)),
                        onTap: (a) => Native.openAppSettings(a.pkg),
                        action: (a) => TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => Native.uninstall(a.pkg),
                          child: const Text('Disinstalla'),
                        ),
                      ),
                      _list(
                        apps: bySize,
                        trailing: (a) => formatBytes(a.totalBytes),
                        subtitle: (a) =>
                            'App ${formatBytes(a.appBytes)} · dati ${formatBytes(a.dataBytes)} · '
                            '${idleLabel(a.daysIdle(now))}',
                        onTap: (a) => Native.openAppSettings(a.pkg),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _list({
    Widget? header,
    required List<AppInfo> apps,
    required String Function(AppInfo) trailing,
    required String Function(AppInfo) subtitle,
    required void Function(AppInfo) onTap,
    Widget Function(AppInfo)? action,
  }) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: apps.length + (header == null ? 0 : 1) + 1,
        itemBuilder: (context, i) {
          if (header != null && i == 0) {
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12), child: header);
          }
          final k = i - (header == null ? 0 : 1);
          if (k == apps.length) return const Signature();
          final a = apps[k];
          return ListTile(
            leading: a.icon == null
                ? const CircleAvatar(child: Icon(Icons.android))
                : Image.memory(a.icon!, width: 40, height: 40, gaplessPlayback: true),
            title: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitle(a), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: action == null
                ? Text(trailing(a), style: Theme.of(context).textTheme.labelLarge)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(trailing(a), style: Theme.of(context).textTheme.labelLarge),
                      SizedBox(height: 30, child: action(a)),
                    ],
                  ),
            onTap: () => onTap(a),
          );
        },
      ),
    );
  }
}
