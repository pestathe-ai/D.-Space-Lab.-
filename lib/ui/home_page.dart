import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/doc_classifier.dart';
import '../core/file_types.dart';
import '../services/native.dart';
import 'app_state.dart';
import 'apps_page.dart';
import 'cleanup_page.dart';
import 'docs_page.dart';
import 'duplicates_page.dart';
import 'photos_page.dart';
import 'schedule_page.dart';
import 'whatsapp_page.dart';
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
          Status.error => _ErrorView(state: s),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: 12),
          const Text('Qualcosa è andato storto durante l\'analisi.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              state.status = Status.checking;
              state.start();
            },
            child: const Text('Riprova'),
          ),
          const SizedBox(height: 8),
          CrashCard(title: 'Dettagli per lo sviluppatore', text: state.errorText ?? ''),
        ],
      );
}

/// Mostra un errore con il tasto per copiarlo.
class CrashCard extends StatelessWidget {
  const CrashCard({super.key, required this.title, required this.text, this.onClose});
  final String title;
  final String text;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(text,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Copiato: incollalo nella chat con Claude')));
                    },
                    child: const Text('Copia'),
                  ),
                  if (onClose != null)
                    TextButton(onPressed: onClose, child: const Text('Chiudi')),
                ],
              ),
            ],
          ),
        ),
      );
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
    final p = state.scanProgress;
    final firstTime = state.expectedFiles == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ProgressPanel(
          progress: p,
          countText: '${p.done} file trovati',
          note: firstTime
              ? 'È la prima volta: la stima arriva dalla prossima analisi, '
                  'che sarà anche più veloce.'
              : 'Subito dopo vedi la mappa; i documenti si leggono in sottofondo.',
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
        if (s.crashReport != null)
          CrashCard(
            title: 'L\'ultima volta l\'app si è chiusa per un errore',
            text: s.crashReport!,
            onClose: () {
              s.crashReport = null;
              s.refreshFree();
            },
          ),
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
        _section(context, 'PULIZIA'),
        _Tile(
          icon: Icons.cleaning_services_outlined,
          title: 'Pulizia rapida',
          subtitle: _quickSubtitle(s),
          onTap: () => _go(context, CleanupPage(state: s)),
        ),
        _Tile(
          icon: Icons.copy_all_outlined,
          title: 'Duplicati di ogni file',
          subtitle: s.fileDuplicates == null
              ? (s.dupProgress.running
                  ? 'Ricerca in corso${s.dupProgress.etaText == null ? '' : ' · ${s.dupProgress.etaText}'}'
                  : 'Foto, video, musica e altro: stessi identici byte')
              : '${s.fileDuplicates!.length} gruppi · '
                  '${formatBytes(s.fileDuplicateWaste)} recuperabili',
          onTap: () => _go(context, DuplicatesPage(state: s)),
        ),
        _Tile(
          icon: Icons.chat_outlined,
          title: 'WhatsApp a fondo',
          subtitle: 'Vocali, video, documenti, GIF: per tipo e data',
          onTap: () => _go(context, WhatsAppPage(state: s)),
        ),
        _Tile(
          icon: Icons.apps_outlined,
          title: 'App: cache e inutilizzate',
          subtitle: 'Quanto occupano, quali non usi più',
          onTap: () => _go(context, AppsPage(state: s)),
        ),
        _Tile(
          icon: Icons.photo_size_select_large_outlined,
          title: 'Comprimi foto',
          subtitle: s.photoProgress.running
              ? 'In corso${s.photoProgress.etaText == null ? '' : ' · ${s.photoProgress.etaText}'}'
              : 'Stesse foto, molto meno spazio',
          onTap: () => _go(context, PhotosPage(state: s)),
        ),
        _section(context, 'ESPLORA'),
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
        _section(context, 'DOCUMENTI'),
        if (s.docsProgress.running)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ProgressPanel(
                progress: s.docsProgress,
                countText: s.docsProgress.total == 0
                    ? 'Preparo l\'elenco'
                    : '${s.docsProgress.done} di ${s.docsProgress.total} documenti nuovi',
                note: 'Puoi usare il resto dell\'app intanto. '
                    'I documenti già letti vengono saltati.',
                onStop: s.stopDocs,
                stopLabel: 'Ferma per ora',
              ),
            ),
          )
        else if (s.docsStopped)
          Card(
            child: ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: const Text('Lettura documenti in pausa'),
              subtitle: const Text('Riprende da dove era rimasta'),
              trailing: FilledButton(
                  onPressed: s.analyzeDocs, child: const Text('Riprendi')),
            ),
          ),
        _Tile(
          icon: Icons.event_busy_outlined,
          title: 'Documenti scaduti',
          subtitle: s.docs == null
              ? 'Pronti dopo la lettura'
              : '${expired.length} biglietti, prenotazioni, coupon',
          onTap: () => _go(context, DocsPage(state: s)),
        ),
        _Tile(
          icon: Icons.file_copy_outlined,
          title: 'Documenti doppi',
          subtitle: s.docs == null
              ? 'Pronti dopo la lettura'
              : '${s.duplicateGroups.length} gruppi · '
                  '${formatBytes(s.duplicateWaste)} recuperabili',
          onTap: () => _go(context, DocsPage(state: s, initial: 1)),
        ),
        _Tile(
          icon: Icons.verified_outlined,
          title: 'Documenti importanti',
          subtitle: s.docs == null
              ? 'Pronti dopo la lettura'
              : '${important.length} da conservare',
          onTap: () => _go(context, DocsPage(state: s, initial: 2)),
        ),
        _section(context, 'SICUREZZA'),
        _Tile(
          icon: Icons.delete_outline,
          title: 'Cestino',
          subtitle: s.trashItems.isEmpty
              ? 'Vuoto'
              : '${s.trashItems.length} elementi · ${formatBytes(s.trashBytes)}',
          onTap: () => _go(context, TrashPage(state: s)),
        ),
        _Tile(
          icon: Icons.event_repeat_outlined,
          title: 'Pulizia programmata',
          subtitle: 'Svuota il cestino scaduto e le miniature, con un avviso',
          onTap: () => _go(context, SchedulePage(state: s)),
        ),
        const Signature(),
      ],
    );
  }

  String _quickSubtitle(AppState s) {
    final j = s.junk;
    final r = s.residues;
    final bytes = j.fold<int>(0, (a, g) => a + g.bytes) +
        r.fold<int>(0, (a, e) => a + e.bytes);
    final n = j.fold<int>(0, (a, g) => a + g.paths.length) + r.length;
    if (n == 0) return 'Niente da pulire: ottimo!';
    return '$n elementi inutili · ${formatBytes(bytes)}';
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(letterSpacing: 1.4)),
      );

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
