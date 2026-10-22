import 'package:flutter/material.dart';

import '../core/doc_classifier.dart';
import '../core/file_types.dart';
import '../core/origin.dart';
import '../core/storage_index.dart';
import '../services/doc_analyzer.dart';
import 'app_state.dart';
import 'docs_page.dart';
import 'file_list_page.dart';
import 'origin_page.dart';
import 'widgets.dart';

/// Strumenti per capire quali documenti si possono togliere.
class DocToolsPage extends StatelessWidget {
  const DocToolsPage({super.key, required this.state});
  final AppState state;

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
        final now = DateTime.now();
        final nowMs = now.millisecondsSinceEpoch;
        int ago(int days) => nowMs - days * 86400000;

        final docs = idx.files.where((f) => f.kind == FileKind.document).toList();
        final analyzed = <String, AnalyzedDoc>{
          for (final d in state.docs?.docs ?? const <AnalyzedDoc>[]) d.file.path: d,
        };
        final ready = state.docs != null;
        bool important(FileEntry f) =>
            analyzed[f.path]?.verdict(now) == DocVerdict.important;
        final importantCount = docs.where(important).length;
        final note = importantCount == 0
            ? null
            : 'Esclusi $importantCount documenti importanti '
                '(identità, contratti, buste paga, fisco…).';
        List<FileEntry> notImportant(Iterable<FileEntry> l) =>
            l.where((f) => !important(f)).toList();

        String? badge(FileEntry f) {
          final a = analyzed[f.path];
          if (a == null) return null;
          final parts = <String>[
            ...a.facts.ticketHits,
            ...a.facts.importantHits,
            if (a.facts.latestDateMs != null)
              'ultima data ${shortDate(DateTime.fromMillisecondsSinceEpoch(a.facts.latestDateMs!))}',
          ];
          return parts.isEmpty ? null : parts.join(' · ');
        }

        final forgotten = notImportant(docs.where((f) =>
            state.originFor(f) == Origin.downloads && f.modifiedMs < ago(182)));
        final whatsapp = notImportant(docs.where((f) =>
            state.originFor(f) == Origin.whatsapp && f.modifiedMs < ago(90)));
        final unreadable = notImportant(docs.where((f) {
          if (f.size == 0) return true;
          final a = analyzed[f.path];
          return a != null && a.facts.textChars == 0 && f.size <= 40 * 1024 * 1024;
        }));
        final oldDates = notImportant(docs.where((f) {
          final d = analyzed[f.path]?.facts.latestDateMs;
          return d != null && d < ago(730);
        }));
        final huge = notImportant(docs.where((f) => f.size > 10 * 1024 * 1024));
        final versions = documentVersions(docs);
        final versionsOlder = [
          for (final g in versions) ...g.skip(1).where((f) => !important(f)),
        ];
        final expired = state.docsWith(DocVerdict.expired);

        Widget tool({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback? onTap,
          bool needsReading = false,
        }) =>
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(icon,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                title: Text(title),
                subtitle: Text(needsReading && !ready
                    ? 'Pronto quando finisce la lettura dei documenti'
                    : subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: needsReading && !ready ? null : onTap,
              ),
            );

        String sum(List<FileEntry> l) =>
            '${l.length} file · ${formatBytes(l.fold<int>(0, (a, f) => a + f.size))}';

        Widget list(String title, String explanation, List<FileEntry> files,
                {Advice advice = Advice.check, String? Function(FileEntry)? b}) =>
            FileListPage(
              state: state,
              title: title,
              files: files,
              explanation: explanation,
              advice: advice,
              excludedNote: note,
              badge: b ?? badge,
            );

        return Scaffold(
          appBar: AppBar(title: const Text('Strumenti documenti')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${docs.length} documenti · '
                  '${formatBytes(docs.fold<int>(0, (a, f) => a + f.size))}',
                  style: t.titleLarge),
              const SizedBox(height: 4),
              Text(
                  'I documenti importanti non vengono mai proposti per '
                  'l\'eliminazione negli strumenti qui sotto.',
                  style: t.bodySmall),
              if (state.docsProgress.running) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ProgressPanel(
                      progress: state.docsProgress,
                      countText: '${state.docsProgress.done} di '
                          '${state.docsProgress.total} documenti nuovi',
                      onStop: state.stopDocs,
                      stopLabel: 'Ferma per ora',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              tool(
                icon: Icons.event_busy_outlined,
                title: 'Scaduti',
                subtitle: '${expired.length} biglietti, prenotazioni, coupon passati',
                onTap: () => _open(context, DocsPage(state: state)),
                needsReading: true,
              ),
              tool(
                icon: Icons.file_copy_outlined,
                title: 'Doppioni identici',
                subtitle: '${state.duplicateGroups.length} gruppi · '
                    '${formatBytes(state.duplicateWaste)} recuperabili',
                onTap: () => _open(context, DocsPage(state: state, initial: 1)),
                needsReading: true,
              ),
              tool(
                icon: Icons.history_edu_outlined,
                title: 'Versioni dello stesso file',
                subtitle: versions.isEmpty
                    ? 'Nessuna trovata'
                    : '${versions.length} documenti con più versioni · '
                        '${sum(versionsOlder)} vecchie',
                onTap: versions.isEmpty
                    ? null
                    : () => _open(
                        context,
                        list(
                          'Versioni vecchie',
                          'Stesso nome, contenuto diverso: "contratto", '
                              '"contratto (1)", "contratto_v2", "contratto firmato"… '
                              'Qui trovi le versioni più vecchie; la più recente '
                              'resta fuori dall\'elenco. Aprile per confrontare.',
                          versionsOlder,
                          b: (f) {
                            final g = versions.firstWhere((g) => g.contains(f));
                            return 'versione più recente: ${g.first.name}';
                          },
                        )),
              ),
              tool(
                icon: Icons.download_outlined,
                title: 'Scaricati e dimenticati',
                subtitle: '${sum(forgotten)} · in Download da più di 6 mesi',
                onTap: () => _open(
                    context,
                    list(
                        'Scaricati e dimenticati',
                        'Documenti rimasti in Download da più di 6 mesi: '
                            'spesso aperti una volta e mai più.',
                        forgotten)),
              ),
              tool(
                icon: Icons.chat_outlined,
                title: 'Ricevuti su WhatsApp',
                subtitle: '${sum(whatsapp)} · più vecchi di 3 mesi',
                onTap: () => _open(
                    context,
                    list(
                        'Documenti da WhatsApp',
                        'Ricevuti nelle chat più di 3 mesi fa. Se ti servono, '
                            'sono anche nella chat (finché non la svuoti).',
                        whatsapp)),
              ),
              tool(
                icon: Icons.history_toggle_off,
                title: 'Con date vecchie',
                subtitle: '${sum(oldDates)} · tutte le date di oltre 2 anni fa',
                needsReading: true,
                onTap: () => _open(
                    context,
                    list(
                        'Documenti datati',
                        'La data più recente scritta nel documento è di più di '
                            '2 anni fa: preventivi, avvisi, orari, menu, '
                            'comunicazioni ormai superate.',
                        oldDates)),
              ),
              tool(
                icon: Icons.block_outlined,
                title: 'Vuoti o illeggibili',
                subtitle: sum(unreadable),
                needsReading: true,
                onTap: () => _open(
                    context,
                    list(
                        'Vuoti o illeggibili',
                        'File vuoti, rovinati o senza testo leggibile (anche '
                            'con il riconoscimento del testo). Aprili: se non si '
                            'aprono, si possono togliere.',
                        unreadable)),
              ),
              tool(
                icon: Icons.unfold_more,
                title: 'Molto pesanti',
                subtitle: '${sum(huge)} · oltre 10 MB',
                onTap: () => _open(
                    context,
                    list('Documenti pesanti',
                        'Presentazioni, scansioni e PDF con molte immagini.', huge)),
              ),
              tool(
                icon: Icons.verified_outlined,
                title: 'Importanti (da tenere)',
                subtitle: '$importantCount documenti protetti',
                needsReading: true,
                onTap: () => _open(context, DocsPage(state: state, initial: 2)),
              ),
              tool(
                icon: Icons.account_tree_outlined,
                title: 'Da dove arrivano',
                subtitle: 'Download, WhatsApp, Documenti, app…',
                onTap: () =>
                    _open(context, OriginPage(state: state, kind: FileKind.document)),
              ),
              const Signature(),
            ],
          ),
        );
      },
    );
  }
}
