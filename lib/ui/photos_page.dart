import 'package:flutter/material.dart';

import '../core/cleanup.dart';
import '../core/file_types.dart';
import '../core/storage_index.dart';
import '../services/photo_compress.dart';
import 'app_state.dart';
import 'widgets.dart';

enum _Where { camera, whatsapp, other }

extension on _Where {
  String get label => switch (this) {
        _Where.camera => 'Fotocamera',
        _Where.whatsapp => 'WhatsApp',
        _Where.other => 'Altre cartelle',
      };
}

_Where _whereOf(String path) {
  if (path.contains('/DCIM/')) return _Where.camera;
  if (path.contains('/WhatsApp')) return _Where.whatsapp;
  return _Where.other;
}

/// Risparmio tipico per ogni livello, per la stima prima di partire.
const _typicalSaving = [0.33, 0.5, 0.72];

/// Comprimi foto: stesse foto, molto meno spazio.
class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key, required this.state});
  final AppState state;

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  int preset = 1;
  final Set<_Where> where = {_Where.camera, _Where.whatsapp, _Where.other};
  Set<String>? _done;
  Object? _doneFor;

  Future<void> _loadDone(List<FileEntry> files) async {
    final d = await PhotoCompressor.alreadyDone(files);
    if (mounted) setState(() => _done = d);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final idx = s.index;
        final t = Theme.of(context).textTheme;
        final all = idx == null
            ? const <FileEntry>[]
            : idx.files.where((f) => isCompressCandidate(s.root, f)).toList();
        if (!identical(_doneFor, idx)) {
          _doneFor = idx;
          _loadDone(all);
        }
        final done = _done ?? const <String>{};
        final todo = all
            .where((f) => !done.contains(f.path) && where.contains(_whereOf(f.path)))
            .toList()
          ..sort((a, b) => b.size.compareTo(a.size));
        final bytes = todo.fold<int>(0, (a, f) => a + f.size);
        final estimate = (bytes * _typicalSaving[preset]).round();
        final p = s.photoProgress;
        final last = s.lastCompress;

        return Scaffold(
          appBar: AppBar(title: const Text('Comprimi foto')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (p.running)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ProgressPanel(
                      progress: p,
                      countText: '${p.done} di ${p.total} foto · '
                          'risparmiati ${formatBytes(s.photoSaved)}',
                      note: 'Puoi tornare indietro: continua da sola.',
                      onStop: s.stopPhotos,
                    ),
                  ),
                )
              else if (last != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fatto!', style: t.titleLarge),
                        const SizedBox(height: 6),
                        Text('${last.compressed} foto compresse, '
                            '${formatBytes(last.saved)} risparmiati.'
                            '${last.skipped > 0 ? ' ${last.skipped} lasciate com\'erano (non conveniva).' : ''}'),
                        const SizedBox(height: 6),
                        const Text(
                            'Gli originali sono nel cestino per 30 giorni. '
                            'Guarda qualche foto in Galleria: se ti piacciono, '
                            'svuota gli originali e lo spazio si libera subito.'),
                        if (last.compressed > 0 &&
                            s.trashItems.any((i) => last.originals.contains(i.originalPath)))
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: FilledButton(
                              onPressed: () async {
                                final freed = await s.purgeCompressedOriginals();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text('Liberati ${formatBytes(freed)}')));
                                }
                              },
                              child: const Text('Svuota gli originali'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!p.running) ...[
                Text('QUANTO COMPRIMERE', style: t.labelMedium?.copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 8),
                for (var i = 0; i < compressPresets.length; i++)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: i == preset
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: i == preset ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => setState(() => preset = i),
                      leading: Icon(i == preset
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked),
                      title: Text(compressPresets[i].name),
                      subtitle: Text(compressPresets[i].description),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('QUALI FOTO', style: t.labelMedium?.copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final w in _Where.values)
                      FilterChip(
                        label: Text(w.label),
                        selected: where.contains(w),
                        onSelected: (v) =>
                            setState(() => v ? where.add(w) : where.remove(w)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.photo_library_outlined,
                  text: _done == null
                      ? 'Conto le foto…'
                      : '${todo.length} foto JPEG sopra 1,5 MB · ${formatBytes(bytes)}. '
                          'Risparmio stimato: circa ${formatBytes(estimate)}.'
                          '${done.isNotEmpty ? ' (${done.length} già fatte prima: le salto.)' : ''}',
                ),
                const InfoCard(
                  icon: Icons.verified_user_outlined,
                  text: 'Data, luogo e orientamento restano. Ogni originale va nel '
                      'cestino per 30 giorni; se il guadagno è sotto il 15% la '
                      'foto non viene toccata.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  onPressed: todo.isEmpty || _done == null
                      ? null
                      : () => _confirm(todo, bytes, estimate),
                  icon: const Icon(Icons.compress),
                  label: Text(todo.isEmpty
                      ? 'Nessuna foto da comprimere'
                      : 'Comprimi ${todo.length} foto'),
                ),
              ],
              const Signature(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirm(List<FileEntry> todo, int bytes, int estimate) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Comprimere ${todo.length} foto?'),
        content: Text(
            'Livello "${compressPresets[preset].name}". Risparmio stimato circa '
            '${formatBytes(estimate)}. Serve un po\' di tempo: vedrai quanto manca.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Comprimi')),
        ],
      ),
    );
    if (ok == true) {
      widget.state.compressPhotos(todo, compressPresets[preset]);
    }
  }
}
