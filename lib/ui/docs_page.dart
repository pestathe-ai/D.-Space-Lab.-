import 'package:flutter/material.dart';

import '../core/doc_classifier.dart';
import '../core/file_types.dart';
import '../services/doc_analyzer.dart';
import 'app_state.dart';
import 'widgets.dart';

/// Documenti: scaduti, doppioni, importanti.
class DocsPage extends StatefulWidget {
  const DocsPage({super.key, required this.state, this.initial = 0});
  final AppState state;
  final int initial;

  @override
  State<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends State<DocsPage> {
  final Set<String> selected = {};
  bool _dupInit = false;

  String _where(AnalyzedDoc d) {
    final root = widget.state.root;
    final dir = d.file.dir;
    return dir.length > root.length ? dir.substring(root.length + 1) : 'Memoria';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initial,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final s = widget.state;
          final expired = s.docsWith(DocVerdict.expired);
          final important = s.docsWith(DocVerdict.important);
          final dups = s.duplicateGroups;
          if (!_dupInit && s.docs != null) {
            _dupInit = true;
            for (final g in dups) {
              selected.addAll(g.skip(1).map((d) => d.file.path));
            }
          }
          selected.removeWhere((p) => !(s.index?.sizeOf.containsKey(p) ?? false));
          return Scaffold(
            appBar: AppBar(
              title: const Text('Documenti'),
              bottom: TabBar(tabs: [
                Tab(text: 'Scaduti (${expired.length})'),
                Tab(text: 'Doppioni (${dups.length})'),
                Tab(text: 'Importanti (${important.length})'),
              ]),
            ),
            bottomNavigationBar: TrashBar(
              paths: selected,
              state: s,
              onDone: () => setState(selected.clear),
            ),
            body: s.docs == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: s.docsProgress.running
                          ? ProgressPanel(
                              progress: s.docsProgress,
                              countText: '${s.docsProgress.done} di '
                                  '${s.docsProgress.total} documenti nuovi',
                              note: 'Le schede si riempiono appena finisco.',
                            )
                          : const Text('Lettura dei documenti non ancora fatta.'),
                    ),
                  )
                : TabBarView(children: [
              _expiredTab(context, expired),
              _dupTab(context, dups),
              _importantTab(context, important),
            ]),
          );
        },
      ),
    );
  }

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );

  Widget _expiredTab(BuildContext context, List<AnalyzedDoc> list) {
    if (list.isEmpty) {
      return const Center(child: Text('Nessun documento scaduto 🎉'));
    }
    final all = list.every((d) => selected.contains(d.file.path));
    return ListView(
      children: [
        _hint(context,
            'Biglietti, prenotazioni e coupon con tutte le date nel passato. '
            'Tocca per aprire, tieni premuto o usa la casella per selezionare.'),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              final ps = list.map((d) => d.file.path);
              all ? selected.removeAll(ps) : selected.addAll(ps);
            }),
            child: Text(all ? 'Deseleziona' : 'Seleziona tutti'),
          ),
        ),
        for (final d in list) ...[
          FileRow(
            path: d.file.path,
            size: d.file.size,
            subtitle: _where(d),
            badge: '${d.facts.ticketHits.join(' · ')}'
                '${d.facts.latestDateMs != null ? ' · ultima data ${shortDate(DateTime.fromMillisecondsSinceEpoch(d.facts.latestDateMs!))}' : ''}',
            selected: selected.contains(d.file.path),
            onSelect: (v) => setState(() =>
                v ? selected.add(d.file.path) : selected.remove(d.file.path)),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _dupTab(BuildContext context, List<List<AnalyzedDoc>> groups) {
    if (groups.isEmpty) {
      return const Center(child: Text('Nessun doppione 🎉'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        _hint(context,
            'File identici byte per byte. Il primo di ogni gruppo (★) è quello '
            'da tenere: le copie sono già selezionate. '
            'Spazio recuperabile: ${formatBytes(widget.state.duplicateWaste)}.'),
        for (final g in groups)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Column(
              children: [
                for (var i = 0; i < g.length; i++)
                  FileRow(
                    path: g[i].file.path,
                    size: g[i].file.size,
                    subtitle: '${i == 0 ? '★ Da tenere · ' : ''}${_where(g[i])}',
                    selected: selected.contains(g[i].file.path),
                    onSelect: (v) => setState(() => v
                        ? selected.add(g[i].file.path)
                        : selected.remove(g[i].file.path)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _importantTab(BuildContext context, List<AnalyzedDoc> list) {
    if (list.isEmpty) {
      return const Center(child: Text('Nessun documento importante trovato'));
    }
    final byLabel = <String, List<AnalyzedDoc>>{};
    for (final d in list) {
      byLabel.putIfAbsent(d.facts.importantHits.first, () => []).add(d);
    }
    final labels = byLabel.keys.toList()..sort();
    return ListView(
      children: [
        _hint(context,
            'Documenti da conservare: non vanno cancellati. Il consiglio è '
            'tenerne una copia su Google Drive (in arrivo l\'archiviazione '
            'automatica con D. Paper Lab).'),
        for (final l in labels) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l.toUpperCase(),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(letterSpacing: 1.4)),
          ),
          for (final d in byLabel[l]!)
            FileRow(
              path: d.file.path,
              size: d.file.size,
              subtitle: _where(d),
              badge: d.facts.importantHits.join(' · '),
            ),
        ],
      ],
    );
  }
}
