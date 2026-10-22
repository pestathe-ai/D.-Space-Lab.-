import 'package:flutter/material.dart';

import '../core/cleanup.dart' show relativeTo;
import '../core/file_types.dart';
import '../core/origin.dart';
import '../core/storage_index.dart';
import 'app_state.dart';
import 'widgets.dart';

enum _Age { all, m3, y1, y2 }

extension on _Age {
  String get label => switch (this) {
        _Age.all => 'Qualsiasi data',
        _Age.m3 => 'Più di 3 mesi',
        _Age.y1 => 'Più di 1 anno',
        _Age.y2 => 'Più di 2 anni',
      };
  int get days => switch (this) {
        _Age.all => 0,
        _Age.m3 => 90,
        _Age.y1 => 365,
        _Age.y2 => 730,
      };
}

/// Colore e testo del consiglio.
(Color, String, IconData) adviceStyle(Advice a) => switch (a) {
      Advice.safe => (const Color(0xFF2E8B57), 'Sicuro da eliminare', Icons.check_circle_outline),
      Advice.check => (const Color(0xFFF28C38), 'Da controllare', Icons.visibility_outlined),
      Advice.keep => (const Color(0xFF1D3A8A), 'Tuoi: di solito si tengono', Icons.favorite_border),
    };

class AdviceChip extends StatelessWidget {
  const AdviceChip(this.advice, {super.key});
  final Advice advice;

  @override
  Widget build(BuildContext context) {
    final (c, text, icon) = adviceStyle(advice);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Elenco di file da esaminare e pulire, con filtri.
///
/// [files] viene filtrato da solo contro l'indice: ciò che finisce nel
/// cestino sparisce dall'elenco.
class FileListPage extends StatefulWidget {
  const FileListPage({
    super.key,
    required this.state,
    required this.title,
    required this.files,
    this.explanation,
    this.advice,
    this.badge,
    this.excludedNote,
    this.preselectAll = false,
  });

  final AppState state;
  final String title;
  final List<FileEntry> files;
  final String? explanation;
  final Advice? advice;
  final String? Function(FileEntry f)? badge;
  final String? excludedNote;
  final bool preselectAll;

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  final Set<String> selected = {};
  String? folder;
  _Age age = _Age.all;
  bool byDate = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectAll) selected.addAll(widget.files.map((f) => f.path));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final t = Theme.of(context).textTheme;
        final alive = s.index?.sizeOf ?? const <String, int>{};
        final files = widget.files.where((f) => alive.containsKey(f.path)).toList();
        selected.removeWhere((p) => !alive.containsKey(p));
        final folders = topFolders(s.root, files);
        final limit = DateTime.now().millisecondsSinceEpoch - age.days * 86400000;
        final shown = files
            .where((f) =>
                (folder == null ||
                    relativeTo(s.root, f.path).startsWith('$folder/')) &&
                (age == _Age.all || f.modifiedMs < limit))
            .toList()
          ..sort(byDate
              ? (a, b) => a.modifiedMs.compareTo(b.modifiedMs)
              : (a, b) => b.size.compareTo(a.size));
        final shownBytes = shown.fold<int>(0, (a, f) => a + f.size);
        final allSel = shown.isNotEmpty && shown.every((f) => selected.contains(f.path));
        final rows = shown.length > 500 ? 500 : shown.length;

        return Scaffold(
          appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
          bottomNavigationBar: CleanBar(
            paths: selected,
            state: s,
            onDone: () => setState(selected.clear),
            suggestNow: widget.advice == Advice.safe,
          ),
          body: CustomScrollView(
            slivers: [
              if (widget.explanation != null || widget.advice != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.advice != null) AdviceChip(widget.advice!),
                        if (widget.explanation != null) ...[
                          const SizedBox(height: 6),
                          Text(widget.explanation!, style: t.bodyMedium),
                        ],
                        if (widget.excludedNote != null) ...[
                          const SizedBox(height: 6),
                          Text(widget.excludedNote!, style: t.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              if (folders.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      children: [
                        _chip('Tutte le cartelle', folder == null,
                            () => setState(() => folder = null)),
                        for (final d in folders)
                          _chip('${d.dir.split('/').last} · ${formatBytes(d.bytes)}',
                              folder == d.dir, () => setState(() => folder = d.dir)),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    children: [
                      for (final a in _Age.values)
                        _chip(a.label, age == a, () => setState(() => age = a)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${shown.length} file · ${formatBytes(shownBytes)}',
                            style: t.titleSmall),
                      ),
                      TextButton(
                        onPressed: () => setState(() => byDate = !byDate),
                        child: Text(byDate ? 'Dal più vecchio' : 'Dal più pesante'),
                      ),
                      TextButton(
                        onPressed: shown.isEmpty
                            ? null
                            : () => setState(() {
                                  final ps = shown.map((f) => f.path);
                                  allSel ? selected.removeAll(ps) : selected.addAll(ps);
                                }),
                        child: Text(allSel ? 'Nessuno' : 'Tutti'),
                      ),
                    ],
                  ),
                ),
              ),
              if (shown.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Niente qui 🎉')),
                ),
              SliverList.separated(
                itemCount: rows + (shown.length > rows ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  if (i == rows) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Ne mostro $rows. "Tutti" seleziona comunque '
                          'tutti e ${shown.length}.',
                          style: t.bodySmall),
                    );
                  }
                  final f = shown[i];
                  return FileRow(
                    path: f.path,
                    size: f.size,
                    subtitle: '${_where(s.root, f)} · ${shortDate(f.modified)}',
                    badge: widget.badge?.call(f),
                    selected: selected.contains(f.path),
                    onSelect: (v) => setState(
                        () => v ? selected.add(f.path) : selected.remove(f.path)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _where(String root, FileEntry f) {
    final rel = relativeTo(root, f.dir);
    return rel.isEmpty ? 'Memoria' : rel;
  }

  Widget _chip(String l, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(l), selected: sel, onSelected: (_) => onTap()),
      );
}
