import 'package:flutter/material.dart';

import '../core/cleanup.dart' show relativeTo;
import '../core/file_types.dart';
import 'app_state.dart';
import 'widgets.dart';

/// Duplicati di qualsiasi file: stessi identici byte.
class DuplicatesPage extends StatefulWidget {
  const DuplicatesPage({super.key, required this.state});
  final AppState state;

  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends State<DuplicatesPage> {
  final Set<String> selected = {};
  Object? _initFor;
  FileKind? kind;

  String _where(String path) {
    final rel = relativeTo(widget.state.root, path);
    final i = rel.lastIndexOf('/');
    return i <= 0 ? 'Memoria' : rel.substring(0, i);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final all = s.fileDuplicates;
        if (all != null && !identical(_initFor, all)) {
          // appena trovati: propongo di togliere tutte le copie tranne una
          if (_initFor == null) {
            for (final g in all) {
              selected.addAll(g.skip(1).map((f) => f.path));
            }
          }
          _initFor = all;
        }
        final alive = s.index?.sizeOf ?? const <String, int>{};
        selected.removeWhere((p) => !alive.containsKey(p));
        final groups = (all ?? const [])
            .where((g) => kind == null || g.first.kind == kind)
            .toList();

        Widget body;
        if (s.dupProgress.running) {
          final p = s.dupProgress;
          body = Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ProgressPanel(
                progress: p,
                countText: p.total == 0
                    ? 'Preparo l\'elenco'
                    : (p.phase.startsWith('Confronto completo')
                        ? '${formatBytes(p.done)} di ${formatBytes(p.total)} letti'
                        : '${p.done} di ${p.total} file sospetti'),
                note: 'Puoi tornare indietro: la ricerca continua.',
                onStop: s.stopFileDuplicates,
              ),
            ),
          );
        } else if (all == null) {
          body = ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const InfoCard(
                icon: Icons.copy_all_outlined,
                text: 'Cerco i file identici in tutta la memoria: foto '
                    'salvate due volte, video inoltrati, canzoni copiate, '
                    'archivi scaricati più volte. Confronto il contenuto '
                    'byte per byte, non solo il nome.',
              ),
              const InfoCard(
                icon: Icons.speed,
                text: 'Prima scarto i file con peso diverso, poi controllo '
                    'inizio e fine, e leggo per intero solo i sospetti. '
                    'Durante la ricerca vedi quanto manca.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                onPressed: s.findFileDuplicates,
                icon: const Icon(Icons.search),
                label: const Text('Cerca i duplicati'),
              ),
              const Signature(),
            ],
          );
        } else if (all.isEmpty) {
          body = const Center(child: Text('Nessun duplicato: ottimo!'));
        } else {
          final kinds = {for (final g in all) g.first.kind}.toList()
            ..sort((a, b) => a.index.compareTo(b.index));
          body = Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _chip('Tutti', kind == null, () => setState(() => kind = null)),
                    for (final k in kinds)
                      _chip(k.label, kind == k, () => setState(() => kind = k)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    return Card(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Text(
                              '${g.length} copie · ${formatBytes(g.first.size)} '
                              'ciascuna · ${formatBytes(g.first.size * (g.length - 1))} recuperabili',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          for (var j = 0; j < g.length; j++)
                            FileRow(
                              path: g[j].path,
                              size: g[j].size,
                              subtitle: '${_where(g[j].path)} · ${shortDate(g[j].modified)}',
                              badge: j == 0 ? 'Consigliato da tenere' : null,
                              selected: selected.contains(g[j].path),
                              onSelect: (v) => setState(() => v
                                  ? selected.add(g[j].path)
                                  : selected.remove(g[j].path)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Duplicati'),
            actions: [
              if (all != null && !s.dupProgress.running)
                IconButton(
                    tooltip: 'Cerca di nuovo',
                    onPressed: () {
                      _initFor = null;
                      selected.clear();
                      s.findFileDuplicates();
                    },
                    icon: const Icon(Icons.refresh)),
            ],
          ),
          bottomNavigationBar: all == null || all.isEmpty || s.dupProgress.running
              ? null
              : TrashBar(
                  paths: selected,
                  state: s,
                  onDone: () => setState(selected.clear),
                ),
          body: body,
        );
      },
    );
  }

  Widget _chip(String l, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(l), selected: sel, onSelected: (_) => onTap()),
      );
}
