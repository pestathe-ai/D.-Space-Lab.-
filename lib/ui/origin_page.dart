import 'package:flutter/material.dart';

import '../core/cleanup.dart';
import '../core/file_types.dart';
import '../core/origin.dart';
import '../core/storage_index.dart';
import 'app_state.dart';
import 'doc_tools_page.dart';
import 'file_list_page.dart';
import 'widgets.dart';

/// "Da dove arrivano": i file di un tipo divisi per provenienza, con un
/// consiglio per ciascuna e scorciatoie per i casi tipici.
class OriginPage extends StatelessWidget {
  const OriginPage({super.key, required this.state, this.kind});
  final AppState state;
  final FileKind? kind;

  void _open(BuildContext c, Widget p) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => p));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final idx = state.index;
        if (idx == null) return const Scaffold();
        final t = Theme.of(context).textTheme;
        final files = kind == null
            ? idx.files
            : idx.files.where((f) => f.kind == kind).toList();
        final total = files.fold<int>(0, (a, f) => a + f.size);
        final groups = state.originGroups(kind);
        final title = kind?.label ?? 'Tutti i file';
        final now = DateTime.now().millisecondsSinceEpoch;
        int ago(int days) => now - days * 86400000;

        // fasce di peso: spiegano perché i file sono tanti ma pesano poco
        final tiny = files.where((f) => f.size < 50 * 1024).toList();
        final mid = files
            .where((f) => f.size >= 50 * 1024 && f.size < 1024 * 1024)
            .toList();
        final big = files.where((f) => f.size >= 1024 * 1024).toList();

        final shortcuts = <_Shortcut>[
          if (kind == FileKind.image) ...[
            _Shortcut(
              'Screenshot più vecchi di 3 mesi',
              'Catture dello schermo che probabilmente non ti servono più.',
              Advice.check,
              files
                  .where((f) =>
                      state.originFor(f) == Origin.screenshots &&
                      f.modifiedMs < ago(90))
                  .toList(),
            ),
            _Shortcut(
              'Immagini di WhatsApp più vecchie di 6 mesi',
              'Foto ricevute nelle chat, esclusi gli sticker.',
              Advice.check,
              files
                  .where((f) =>
                      state.originFor(f) == Origin.whatsapp &&
                      f.modifiedMs < ago(182))
                  .toList(),
            ),
          ],
          if (kind == FileKind.video) ...[
            _Shortcut('Video sopra i 200 MB', 'I più pesanti, uno per uno.',
                Advice.check, files.where((f) => f.size > 200 * 1024 * 1024).toList()),
            _Shortcut(
              'Video di WhatsApp più vecchi di 3 mesi',
              'Video inoltrati nelle chat: spesso visti una volta.',
              Advice.check,
              files
                  .where((f) =>
                      state.originFor(f) == Origin.whatsapp &&
                      f.modifiedMs < ago(90))
                  .toList(),
            ),
          ],
          if (kind == FileKind.audio)
            _Shortcut(
              'Vocali di WhatsApp più vecchi di 3 mesi',
              'Messaggi vocali già ascoltati.',
              Advice.check,
              files
                  .where((f) =>
                      whatsappInfo(state.root, f.path)?.kind == WaKind.voice &&
                      f.modifiedMs < ago(90))
                  .toList(),
            ),
          if (kind == FileKind.apk)
            _Shortcut(
              'Installer di app già installate',
              'Hai già l\'app (stessa versione o più nuova): il file non serve.',
              Advice.safe,
              files.where((f) => state.installedApks.contains(f.path)).toList(),
            ),
          if (kind == FileKind.archive)
            _Shortcut(
              'Archivi scaricati più di 3 mesi fa',
              'ZIP e simili in Download: spesso già estratti.',
              Advice.check,
              files
                  .where((f) =>
                      state.originFor(f) == Origin.downloads &&
                      f.modifiedMs < ago(90))
                  .toList(),
            ),
        ].where((s) => s.files.isNotEmpty).toList();

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${files.length} file · ${formatBytes(total)}', style: t.titleLarge),
              const SizedBox(height: 12),
              if (kind == FileKind.document)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.handyman_outlined),
                    title: const Text('Strumenti per i documenti'),
                    subtitle: const Text(
                        'Scaduti, doppioni, versioni, dimenticati, illeggibili…'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, DocToolsPage(state: state)),
                  ),
                ),
              _label(context, 'PER PESO'),
              Card(
                child: Column(
                  children: [
                    _bucket(context, 'Piccolissimi (sotto 50 KB)',
                        'Icone, sticker, anteprime: tanti file, poco spazio', tiny),
                    const Divider(height: 1),
                    _bucket(context, 'Medi (50 KB – 1 MB)', null, mid),
                    const Divider(height: 1),
                    _bucket(context, 'Grandi (oltre 1 MB)',
                        'Qui di solito si libera più spazio', big),
                  ],
                ),
              ),
              if (shortcuts.isNotEmpty) ...[
                _label(context, 'SCORCIATOIE'),
                for (final sc in shortcuts)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bolt_outlined),
                      title: Text(sc.title),
                      subtitle: Text(
                          '${sc.files.length} file · ${formatBytes(sc.files.fold<int>(0, (a, f) => a + f.size))}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                          context,
                          FileListPage(
                            state: state,
                            title: sc.title,
                            files: sc.files,
                            explanation: sc.explanation,
                            advice: sc.advice,
                          )),
                    ),
                  ),
              ],
              _label(context, 'DA DOVE ARRIVANO'),
              for (final g in groups) _originCard(context, g, total),
              const Signature(),
            ],
          ),
        );
      },
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.4)),
      );

  Widget _bucket(BuildContext context, String title, String? hint, List<FileEntry> files) {
    final bytes = files.fold<int>(0, (a, f) => a + f.size);
    return ListTile(
      title: Text(title),
      subtitle: Text('${files.length} file · ${formatBytes(bytes)}'
          '${hint == null ? '' : '\n$hint'}'),
      isThreeLine: hint != null,
      trailing: const Icon(Icons.chevron_right),
      onTap: files.isEmpty
          ? null
          : () => _open(
              context,
              FileListPage(
                state: state,
                title: title,
                files: files,
                badge: (f) => state.originFor(f).label,
              )),
    );
  }

  Widget _originCard(BuildContext context, OriginGroup g, int total) {
    final t = Theme.of(context).textTheme;
    final frac = total == 0 ? 0.0 : g.bytes / total;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(
            context,
            FileListPage(
              state: state,
              title: '${g.origin.label}${kind == null ? '' : ' · ${kind!.label}'}',
              files: g.files,
              explanation: g.origin.explanation,
              advice: g.origin.advice,
            )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(g.origin.label, style: t.titleMedium)),
                  Text(formatBytes(g.bytes), style: t.labelLarge),
                ],
              ),
              const SizedBox(height: 4),
              Text('${g.files.length} file', style: t.bodySmall),
              const SizedBox(height: 8),
              SizeBar(fraction: frac, color: adviceStyle(g.origin.advice).$1),
              const SizedBox(height: 8),
              AdviceChip(g.origin.advice),
              const SizedBox(height: 6),
              Text(g.origin.explanation, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut {
  _Shortcut(this.title, this.explanation, this.advice, this.files);
  final String title;
  final String explanation;
  final Advice advice;
  final List<FileEntry> files;
}
