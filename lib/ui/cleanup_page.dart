import 'package:flutter/material.dart';

import '../core/cleanup.dart';
import '../core/file_types.dart';
import 'app_state.dart';
import 'widgets.dart';

/// Pulizia rapida: file inutili e residui di app disinstallate.
class CleanupPage extends StatefulWidget {
  const CleanupPage({super.key, required this.state});
  final AppState state;

  @override
  State<CleanupPage> createState() => _CleanupPageState();
}

class _CleanupPageState extends State<CleanupPage> {
  final Set<String> selected = {};
  final Set<JunkKind> _open = {};
  bool _init = false;
  bool _busy = false;

  String _rel(String p) => relativeTo(widget.state.root, p);

  String _where(String p) {
    final rel = _rel(p);
    final i = rel.lastIndexOf('/');
    return i <= 0 ? 'Memoria' : rel.substring(0, i);
  }

  void _toggleAll(Iterable<String> paths, bool on) => setState(() {
        if (on) {
          selected.addAll(paths);
        } else {
          selected.removeAll(paths);
        }
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final junk = s.junk;
        final residues = s.residues;
        if (!_init) {
          _init = true;
          for (final g in junk.where((g) => g.preselected)) {
            selected.addAll(g.paths);
          }
          // i residui li scegli tu: potrebbero essere salvataggi di un gioco
        }
        final alive = <String>{
          for (final g in junk) ...g.paths,
          for (final r in residues) r.dir,
        };
        selected.removeWhere((p) => !alive.contains(p));
        final sizes = <String, int>{
          ...s.index?.sizeOf ?? const {},
          for (final r in residues) r.dir: r.bytes,
        };
        final bytes = selected.fold<int>(0, (a, p) => a + (sizes[p] ?? 0));
        final emptyAll = {
          for (final g in junk)
            if (g.kind == JunkKind.emptyDirs) ...g.paths,
        };
        final emptySel = selected.where(emptyAll.contains).toSet();
        final t = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Pulizia rapida')),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _clean(selected.toList(), emptySel, bytes,
                        residues.any((r) => selected.contains(r.dir))),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: Text(selected.isEmpty
                    ? 'Niente di selezionato'
                    : 'Pulisci ${selected.length} · ${formatBytes(bytes)}'),
              ),
            ),
          ),
          body: junk.isEmpty && residues.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Niente da pulire qui: il telefono è in ordine.',
                      textAlign: TextAlign.center),
                ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (junk.isNotEmpty) ...[
                      Text('FILE INUTILI',
                          style: t.labelMedium?.copyWith(letterSpacing: 1.4)),
                      const SizedBox(height: 8),
                      for (final g in junk) _junkCard(g),
                    ],
                    if (residues.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('RESIDUI DI APP DISINSTALLATE',
                          style: t.labelMedium?.copyWith(letterSpacing: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                          'Cartelle lasciate da app che non sono più sul telefono. '
                          'Controlla prima di pulire: a volte sono salvataggi o '
                          'file che vuoi tenere.',
                          style: t.bodySmall),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            for (final r in residues)
                              CheckboxListTile(
                                value: selected.contains(r.dir),
                                onChanged: (v) => _toggleAll([r.dir], v ?? false),
                                title: Text(r.pkg,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '${_rel(r.dir)}\n${r.files} file · ${formatBytes(r.bytes)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                isThreeLine: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const InfoCard(
                      icon: Icons.shield_outlined,
                      text: 'Foto, video e documenti non vengono mai '
                          'proposti qui. Le cartelle di sistema e quelle '
                          'principali restano dove sono, anche se vuote.',
                    ),
                    const Signature(),
                  ],
                ),
        );
      },
    );
  }

  Widget _junkCard(JunkGroup g) {
    final all = g.paths.every(selected.contains);
    final some = g.paths.any(selected.contains);
    final open = _open.contains(g.kind);
    final sizes = widget.state.index?.sizeOf ?? const <String, int>{};
    final shown = open ? g.paths.take(300).toList() : const <String>[];
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              tristate: true,
              value: all ? true : (some ? null : false),
              onChanged: (_) => _toggleAll(g.paths, !all),
            ),
            title: Text(g.title),
            subtitle: Text(
                '${g.description}\n${g.paths.length} · '
                '${g.kind == JunkKind.emptyDirs ? 'nessuno spazio, solo ordine' : formatBytes(g.bytes)}'),
            isThreeLine: true,
            trailing: IconButton(
              icon: Icon(open ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(
                  () => open ? _open.remove(g.kind) : _open.add(g.kind)),
            ),
          ),
          for (final p in shown)
            CheckboxListTile(
              dense: true,
              value: selected.contains(p),
              onChanged: (v) => _toggleAll([p], v ?? false),
              title: Text(nameOf(p), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${_where(p)}'
                  '${g.kind == JunkKind.emptyDirs ? '' : ' · ${formatBytes(sizes[p] ?? 0)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          if (open && g.paths.length > shown.length)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('… e altri ${g.paths.length - shown.length}'),
            ),
        ],
      ),
    );
  }

  Future<void> _clean(List<String> paths, Set<String> empties, int bytes,
      bool hasResidues) async {
    final now = await askDeleteMode(context,
        count: paths.length, bytes: bytes, suggestNow: !hasResidues);
    if (now == null) return;
    setState(() => _busy = true);
    final r = await widget.state.clean(paths, empties, now: now);
    if (!mounted) return;
    setState(() {
      _busy = false;
      selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(now
            ? 'Puliti ${r.count} elementi · liberati ${formatBytes(r.freed)}'
            : '${r.count} elementi nel cestino')));
  }
}
