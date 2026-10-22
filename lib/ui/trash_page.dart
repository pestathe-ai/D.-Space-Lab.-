import 'package:flutter/material.dart';

import '../core/file_types.dart';
import '../services/trash.dart';
import 'app_state.dart';
import 'widgets.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key, required this.state});
  final AppState state;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final Set<String> selected = {};
  bool busy = false;

  Future<void> _run(Future<String> Function() action) async {
    setState(() => busy = true);
    final msg = await action();
    if (!mounted) return;
    setState(() {
      busy = false;
      selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final items = [...s.trashItems]
          ..sort((a, b) => b.deletedMs.compareTo(a.deletedMs));
        final sel = items.where((i) => selected.contains(i.trashPath)).toList();
        final target = sel.isEmpty ? items : sel;
        return Scaffold(
          appBar: AppBar(title: Text('Cestino · ${formatBytes(s.trashBytes)}')),
          bottomNavigationBar: items.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50)),
                            onPressed: busy || sel.isEmpty
                                ? null
                                : () => _run(() async {
                                      final n = await s.restore(sel);
                                      return '$n file ripristinati';
                                    }),
                            child: const Text('Ripristina'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            onPressed: busy ? null : () => _confirmPurge(target),
                            child: Text(sel.isEmpty ? 'Svuota tutto' : 'Elimina (${sel.length})'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          body: items.isEmpty
              ? const Center(child: Text('Il cestino è vuoto'))
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'I file restano qui 30 giorni, poi vengono eliminati da '
                        'soli. Lo spazio si libera davvero solo svuotando il cestino.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    for (final it in items) ...[
                      FileRow(
                        path: it.originalPath,
                        size: it.size,
                        subtitle: 'Eliminato il ${shortDate(it.deleted)} · '
                            'resta ${_daysLeft(it)} giorni',
                        selected: selected.contains(it.trashPath),
                        onTap: () => setState(() {
                          if (!selected.remove(it.trashPath)) {
                            selected.add(it.trashPath);
                          }
                        }),
                        onSelect: (v) => setState(() => v
                            ? selected.add(it.trashPath)
                            : selected.remove(it.trashPath)),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
        );
      },
    );
  }

  int _daysLeft(TrashItem it) {
    final left = 30 - DateTime.now().difference(it.deleted).inDays;
    return left < 0 ? 0 : left;
  }

  Future<void> _confirmPurge(List<TrashItem> items) async {
    final bytes = items.fold<int>(0, (s, i) => s + i.size);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Eliminare definitivamente ${items.length} file?'),
        content: Text('Liberi ${formatBytes(bytes)}. Non si potranno più recuperare.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final freed = await widget.state.purge(items);
      return '${formatBytes(freed)} liberati';
    });
  }
}
