import 'package:flutter/material.dart';

import '../core/doc_classifier.dart';
import '../core/file_types.dart';
import '../services/native.dart';
import 'app_state.dart';
import 'docs_page.dart';
import 'explore_page.dart';
import 'trash_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});
  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) widget.state.onResume();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('D. Space Lab'),
          actions: [
            if (s.status == Status.ready)
              IconButton(
                  tooltip: 'Ricalcola',
                  onPressed: s.scan,
                  icon: const Icon(Icons.refresh)),
          ],
        ),
        body: switch (s.status) {
          Status.checking => const Center(child: CircularProgressIndicator()),
          Status.unsupported => const _Message(
              icon: Icons.phone_android,
              text: 'D. Space Lab richiede Android 11 o successivo.'),
          Status.needPermission => const _Permission(),
          Status.scanning => _Progress(state: s),
          Status.ready => _Dashboard(state: s),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _Permission extends StatelessWidget {
  const _Permission();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.folder_open_outlined,
            size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Guardiamo cosa occupa spazio',
            style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
          'Per misurare e pulire la memoria, D. Space Lab ha bisogno '
          'dell\'"Accesso a tutti i file". Tutto resta sul telefono: '
          'nessun file viene inviato online.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: Native.requestAllFiles,
          child: const Text('Apri impostazioni'),
        ),
        const SizedBox(height: 8),
        const Text('Attiva l\'interruttore e torna qui.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        const Signature(),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final frac = state.total == 0 ? null : state.done / state.total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${state.phase}…',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            LinearProgressIndicator(
                value: frac, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 12),
            Text(state.total == 0
                ? 'Un momento'
                : '${state.done} di ${state.total} documenti'),
            const SizedBox(height: 8),
            const Text('I documenti già letti vengono saltati.',
                style: TextStyle(fontSize: 12)),
            if (state.total > 0)
              TextButton(
                  onPressed: state.cancel,
                  child: const Text('Salta il resto per ora')),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.state});
  final AppState state;

  void _go(BuildContext c, Widget p) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => p));

  @override
  Widget build(BuildContext context) {
    final s = state;
    final idx = s.index!;
    final t = Theme.of(context).textTheme;
    final used = s.deviceTotal - s.deviceFree;
    final scanned = idx.totalBytes;
    final systemApps = (used - scanned).clamp(0, used);
    final kinds = FileKind.values
        .where((k) => (idx.kindTotals[k] ?? 0) > 0)
        .toList()
      ..sort((a, b) => idx.kindTotals[b]!.compareTo(idx.kindTotals[a]!));
    final expired = s.docsWith(DocVerdict.expired);
    final important = s.docsWith(DocVerdict.important);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scheda "eroe": l'unico gradiente ammesso, blu-casa → arancio-tetto.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1D3A8A), Color(0xFFF28C38)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SPAZIO LIBERO',
                  style: t.labelMedium?.copyWith(
                      color: Colors.white70, letterSpacing: 1.4)),
              const SizedBox(height: 4),
              Text(formatBytes(s.deviceFree),
                  style: t.displaySmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: s.deviceTotal == 0 ? 0 : used / s.deviceTotal,
                  minHeight: 8,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text('${formatBytes(used)} usati su ${formatBytes(s.deviceTotal)}',
                  style: t.bodySmall?.copyWith(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COSA OCCUPA SPAZIO',
                    style: t.labelMedium?.copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 12),
                _StackedBar(
                  parts: [
                    for (final k in kinds) (idx.kindTotals[k]!, kindColor(k)),
                    (systemApps, Theme.of(context).colorScheme.outlineVariant),
                  ],
                ),
                const SizedBox(height: 12),
                for (final k in kinds)
                  _legend(context, kindColor(k), k.label,
                      '${formatBytes(idx.kindTotals[k]!)} · ${idx.kindCounts[k]} file',
                      onTap: () => _go(context, LargestPage(state: s, kind: k))),
                _legend(context, Theme.of(context).colorScheme.outlineVariant,
                    'App e sistema', '${formatBytes(systemApps)} · non accessibili'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Tile(
          icon: Icons.folder_outlined,
          title: 'Esplora cartelle',
          subtitle: 'Scendi nelle cartelle, dalla più pesante',
          onTap: () => _go(context, ExplorePage(state: s, dir: s.root)),
        ),
        _Tile(
          icon: Icons.sort,
          title: 'File più grandi',
          subtitle: 'I 200 file che pesano di più',
          onTap: () => _go(context, LargestPage(state: s)),
        ),
        _Tile(
          icon: Icons.event_busy_outlined,
          title: 'Documenti scaduti',
          subtitle: '${expired.length} biglietti, prenotazioni, coupon',
          onTap: () => _go(context, DocsPage(state: s)),
        ),
        _Tile(
          icon: Icons.file_copy_outlined,
          title: 'Documenti doppi',
          subtitle: '${s.duplicateGroups.length} gruppi · '
              '${formatBytes(s.duplicateWaste)} recuperabili',
          onTap: () => _go(context, DocsPage(state: s, initial: 1)),
        ),
        _Tile(
          icon: Icons.verified_outlined,
          title: 'Documenti importanti',
          subtitle: '${important.length} da conservare',
          onTap: () => _go(context, DocsPage(state: s, initial: 2)),
        ),
        _Tile(
          icon: Icons.delete_outline,
          title: 'Cestino',
          subtitle: s.trashItems.isEmpty
              ? 'Vuoto'
              : '${s.trashItems.length} file · ${formatBytes(s.trashBytes)}',
          onTap: () => _go(context, TrashPage(state: s)),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IN ARRIVO', style: t.labelMedium?.copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 8),
                const Text(
                  'Residui di app disinstallate · File di sistema inutili · '
                  'Duplicati di ogni tipo · WhatsApp a fondo · Cache delle app · '
                  'App inutilizzate · Compressione foto · Pulizia programmata',
                ),
              ],
            ),
          ),
        ),
        const Signature(),
      ],
    );
  }

  Widget _legend(BuildContext context, Color c, String label, String value,
          {VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: c, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              Text(value, style: Theme.of(context).textTheme.bodySmall),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      );
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.parts});
  final List<(int, Color)> parts;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<int>(0, (s, p) => s + p.$1);
    if (total == 0) return const SizedBox(height: 14);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (final p in parts)
              if (p.$1 > 0)
                Expanded(
                  flex: (p.$1 * 1000 ~/ total).clamp(1, 1000),
                  child: Container(color: p.$2),
                ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
