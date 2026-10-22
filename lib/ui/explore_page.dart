import 'package:flutter/material.dart';

import '../core/file_types.dart';
import 'app_state.dart';
import 'widgets.dart';

/// Esplora cartelle: cosa occupa spazio, dal più grande.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.state, required this.dir});
  final AppState state;
  final String dir;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final Set<String> selected = {};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final idx = widget.state.index;
        if (idx == null) return const Scaffold();
        final items = idx.listDir(widget.dir);
        final dirSize = idx.dirSizes[widget.dir] ?? 0;
        final isRoot = widget.dir == widget.state.root;
        final title = isRoot ? 'Memoria' : nameOf(widget.dir);
        selected.removeWhere((p) => !idx.sizeOf.containsKey(p));
        return Scaffold(
          appBar: AppBar(
            title: Text(title, overflow: TextOverflow.ellipsis),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      '${formatBytes(dirSize)} · ${items.length} elementi',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ),
          ),
          bottomNavigationBar: TrashBar(
            paths: selected,
            state: widget.state,
            onDone: () => setState(selected.clear),
          ),
          body: items.isEmpty
              ? const Center(child: Text('Cartella vuota'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final frac = dirSize == 0 ? 0.0 : it.size / dirSize;
                    if (it.isDir) {
                      final count = idx.filesByDir[it.path]?.length ?? 0;
                      return FileRow(
                        path: it.path,
                        size: it.size,
                        isDir: true,
                        fraction: frac,
                        subtitle: '${(frac * 100).toStringAsFixed(frac < 0.01 ? 1 : 0)}%'
                            '${count > 0 ? ' · $count file' : ''}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ExplorePage(state: widget.state, dir: it.path),
                          ),
                        ),
                      );
                    }
                    return FileRow(
                      path: it.path,
                      size: it.size,
                      fraction: frac,
                      subtitle: 'Modificato il ${shortDate(it.file!.modified)}',
                      selected: selected.contains(it.path),
                      onSelect: (v) => setState(() =>
                          v ? selected.add(it.path) : selected.remove(it.path)),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// I file più grandi, filtrabili per tipo.
class LargestPage extends StatefulWidget {
  const LargestPage({super.key, required this.state, this.kind});
  final AppState state;
  final FileKind? kind;

  @override
  State<LargestPage> createState() => _LargestPageState();
}

class _LargestPageState extends State<LargestPage> {
  final Set<String> selected = {};
  FileKind? kind;

  @override
  void initState() {
    super.initState();
    kind = widget.kind;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final idx = widget.state.index;
        if (idx == null) return const Scaffold();
        final list = idx.largest(kind);
        selected.removeWhere((p) => !idx.sizeOf.containsKey(p));
        final root = widget.state.root;
        return Scaffold(
          appBar: AppBar(title: const Text('File più grandi')),
          bottomNavigationBar: TrashBar(
            paths: selected,
            state: widget.state,
            onDone: () => setState(selected.clear),
          ),
          body: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _chip('Tutti', kind == null, () => setState(() => kind = null)),
                    for (final k in FileKind.values)
                      _chip(k.label, kind == k, () => setState(() => kind = k)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = list[i];
                    final rel = f.dir.length > root.length
                        ? f.dir.substring(root.length + 1)
                        : 'Memoria';
                    return FileRow(
                      path: f.path,
                      size: f.size,
                      subtitle: '$rel · ${shortDate(f.modified)}',
                      selected: selected.contains(f.path),
                      onSelect: (v) => setState(() =>
                          v ? selected.add(f.path) : selected.remove(f.path)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String l, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(l), selected: sel, onSelected: (_) => onTap()),
      );
}
