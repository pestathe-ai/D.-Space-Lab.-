import 'package:flutter/material.dart';

import '../core/cleanup.dart';
import '../core/file_types.dart';
import '../core/storage_index.dart';
import 'app_state.dart';
import 'widgets.dart';

enum _Age { all, month, half, year }

extension on _Age {
  String get label => switch (this) {
        _Age.all => 'Tutti',
        _Age.month => 'Più di 1 mese',
        _Age.half => 'Più di 6 mesi',
        _Age.year => 'Più di 1 anno',
      };
  int get days => switch (this) {
        _Age.all => 0,
        _Age.month => 30,
        _Age.half => 182,
        _Age.year => 365,
      };
}

/// WhatsApp a fondo: tutti i file ricevuti e inviati, per tipo e data.
class WhatsAppPage extends StatefulWidget {
  const WhatsAppPage({super.key, required this.state});
  final AppState state;

  @override
  State<WhatsAppPage> createState() => _WhatsAppPageState();
}

class _WhatsAppPageState extends State<WhatsAppPage> {
  final Set<String> selected = {};
  WaKind? kind;
  _Age age = _Age.all;
  bool onlySent = false;

  Object? _cacheFor;
  List<(FileEntry, WaInfo)> _all = const [];

  List<(FileEntry, WaInfo)> _items(AppState s) {
    final idx = s.index;
    if (idx == null) return const [];
    if (!identical(_cacheFor, idx)) {
      _cacheFor = idx;
      _all = [
        for (final f in idx.files)
          if (whatsappInfo(s.root, f.path) case final info?) (f, info),
      ];
    }
    return _all;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final all = _items(s);
        final alive = s.index?.sizeOf ?? const <String, int>{};
        selected.removeWhere((p) => !alive.containsKey(p));
        final t = Theme.of(context).textTheme;

        if (all.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('WhatsApp')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Non ho trovato file di WhatsApp su questo telefono.',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }

        final byKind = <WaKind, (int, int)>{};
        for (final (f, i) in all) {
          final c = byKind[i.kind] ?? (0, 0);
          byKind[i.kind] = (c.$1 + 1, c.$2 + f.size);
        }
        final totalBytes = all.fold<int>(0, (a, e) => a + e.$1.size);
        final now = DateTime.now().millisecondsSinceEpoch;
        final limit = now - age.days * 24 * 3600 * 1000;
        final shown = all
            .where((e) =>
                (kind == null || e.$2.kind == kind) &&
                (age == _Age.all || e.$1.modifiedMs < limit) &&
                (!onlySent || e.$2.sent))
            .map((e) => e.$1)
            .toList()
          ..sort((a, b) => b.size.compareTo(a.size));
        final shownBytes = shown.fold<int>(0, (a, f) => a + f.size);
        final allShownSelected =
            shown.isNotEmpty && shown.every((f) => selected.contains(f.path));
        final kinds = byKind.keys.toList()
          ..sort((a, b) => byKind[b]!.$2.compareTo(byKind[a]!.$2));

        return Scaffold(
          appBar: AppBar(
            title: const Text('WhatsApp'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${all.length} file · ${formatBytes(totalBytes)}',
                      style: t.bodySmall),
                ),
              ),
            ),
          ),
          bottomNavigationBar: TrashBar(
            paths: selected,
            state: s,
            onDone: () => setState(selected.clear),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    children: [
                      _chip('Tutto', kind == null, () => setState(() => kind = null)),
                      for (final k in kinds)
                        _chip('${k.label} · ${formatBytes(byKind[k]!.$2)}', kind == k,
                            () => setState(() => kind = k)),
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
                      FilterChip(
                        label: const Text('Solo inviati da me'),
                        selected: onlySent,
                        onSelected: (v) => setState(() => onlySent = v),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${shown.length} file · ${formatBytes(shownBytes)}',
                            style: t.titleSmall),
                      ),
                      TextButton(
                        onPressed: shown.isEmpty
                            ? null
                            : () => setState(() {
                                  if (allShownSelected) {
                                    selected.removeAll(shown.map((f) => f.path));
                                  } else {
                                    selected.addAll(shown.map((f) => f.path));
                                  }
                                }),
                        child: Text(allShownSelected
                            ? 'Deseleziona tutti'
                            : 'Seleziona tutti'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: shown.length > 500 ? 501 : shown.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  if (i == 500) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Mostro i 500 più grandi. "Seleziona tutti" li prende '
                          'comunque tutti e ${shown.length}.',
                          style: t.bodySmall),
                    );
                  }
                  final f = shown[i];
                  final info = whatsappInfo(s.root, f.path)!;
                  return FileRow(
                    path: f.path,
                    size: f.size,
                    subtitle: '${info.kind.label}${info.sent ? ' inviato' : ''}'
                        '${info.business ? ' · Business' : ''} · ${shortDate(f.modified)}',
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

  Widget _chip(String l, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(l), selected: sel, onSelected: (_) => onTap()),
      );
}
