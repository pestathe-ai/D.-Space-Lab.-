import 'package:flutter/material.dart';

import '../core/file_types.dart';
import '../services/native.dart';
import 'app_state.dart';

/// Colori per i tipi di file, ricavati dalla palette Dom Studio.
Color kindColor(FileKind k) => switch (k) {
      FileKind.image => const Color(0xFF1D3A8A),
      FileKind.video => const Color(0xFFF28C38),
      FileKind.audio => const Color(0xFF8FA9F2),
      FileKind.document => const Color(0xFF5B6475),
      FileKind.archive => const Color(0xFFF5C08A),
      FileKind.apk => const Color(0xFF3F63C9),
      FileKind.other => const Color(0xFFB9A88F),
    };

IconData kindIcon(FileKind k) => switch (k) {
      FileKind.image => Icons.image_outlined,
      FileKind.video => Icons.movie_outlined,
      FileKind.audio => Icons.music_note_outlined,
      FileKind.document => Icons.description_outlined,
      FileKind.archive => Icons.inventory_2_outlined,
      FileKind.apk => Icons.android,
      FileKind.other => Icons.insert_drive_file_outlined,
    };

String shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Barra orizzontale proporzionale.
class SizeBar extends StatelessWidget {
  const SizeBar({super.key, required this.fraction, this.color});
  final double fraction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: cs.outlineVariant.withValues(alpha: 0.5),
        color: color ?? cs.primary,
      ),
    );
  }
}

/// Riga di un file selezionabile.
class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.path,
    required this.size,
    required this.subtitle,
    this.selected,
    this.onSelect,
    this.fraction,
    this.isDir = false,
    this.onTap,
    this.badge,
  });

  final String path;
  final int size;
  final String subtitle;
  final bool? selected;
  final ValueChanged<bool>? onSelect;
  final double? fraction;
  final bool isDir;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final kind = kindOf(path);
    return InkWell(
      onTap: onTap ?? (isDir ? null : () => Native.openFile(path)),
      onLongPress: onSelect == null ? null : () => onSelect!(!(selected ?? false)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDir
                  ? Theme.of(context).colorScheme.primaryContainer
                  : kindColor(kind).withValues(alpha: 0.15),
              child: Icon(isDir ? Icons.folder_outlined : kindIcon(kind),
                  color: isDir
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : kindColor(kind),
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameOf(path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall),
                  if (badge != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary)),
                    ),
                  if (fraction != null) ...[
                    const SizedBox(height: 6),
                    SizeBar(fraction: fraction!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(formatBytes(size), style: t.labelLarge),
            if (selected != null)
              Checkbox(
                  value: selected,
                  onChanged: (v) => onSelect?.call(v ?? false)),
            if (isDir && selected == null)
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// Pulsante in basso: sposta nel cestino.
class TrashBar extends StatelessWidget {
  const TrashBar({super.key, required this.paths, required this.state, this.onDone});
  final Set<String> paths;
  final AppState state;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final sizes = state.index?.sizeOf ?? const <String, int>{};
    final bytes = paths.fold<int>(0, (s, p) => s + (sizes[p] ?? 0));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: paths.isEmpty
              ? null
              : () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('Spostare ${paths.length} file nel cestino?'),
                      content: Text(
                          'Liberi ${formatBytes(bytes)} quando svuoti il cestino. '
                          'Fino ad allora (e per 30 giorni) puoi ripristinarli.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Annulla')),
                        FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Sposta')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final n = await state.moveToTrash(paths);
                  onDone?.call();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$n file nel cestino')));
                  }
                },
          icon: const Icon(Icons.delete_outline),
          label: Text(paths.isEmpty
              ? 'Tieni premuto per selezionare'
              : 'Sposta nel cestino (${paths.length} · ${formatBytes(bytes)})'),
        ),
      ),
    );
  }
}

class Signature extends StatelessWidget {
  const Signature({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text.rich(
        TextSpan(
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          children: const [
            TextSpan(text: "un'app "),
            TextSpan(
                text: 'Dom Studio', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Avanzamento di un lavoro lungo: barra, conteggio, tempo trascorso e stima.
class ProgressPanel extends StatelessWidget {
  const ProgressPanel({
    super.key,
    required this.progress,
    required this.countText,
    this.onStop,
    this.stopLabel = 'Ferma',
    this.note,
  });

  final Progress progress;
  final String countText;
  final VoidCallback? onStop;
  final String stopLabel;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final eta = progress.etaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${progress.phase}…', style: t.titleMedium),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 8,
            backgroundColor: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text(countText, style: t.bodyMedium)),
            if (progress.fraction != null)
              Text('${(progress.fraction! * 100).floor()}%',
                  style: t.labelLarge),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.schedule, size: 16, color: cs.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                eta == null
                    ? 'Calcolo il tempo che manca… (trascorsi ${progress.elapsedText})'
                    : 'Mancano $eta · trascorsi ${progress.elapsedText}',
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note!, style: t.bodySmall),
        ],
        if (onStop != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onStop, child: Text(stopLabel)),
          ),
      ],
    );
  }
}

/// Scheda informativa con icona, usata nelle schermate introduttive.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// Chiede come eliminare: nel cestino (recuperabile) o subito.
/// Restituisce null se l'utente annulla, true per "subito".
Future<bool?> askDeleteMode(BuildContext context,
    {required int count, required int bytes, bool suggestNow = false}) {
  return showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Pulire $count element${count == 1 ? 'o' : 'i'}?'),
      content: Text(
        'Puoi spostarli nel cestino (recuperabili per 30 giorni) oppure '
        'eliminarli subito e liberare ${formatBytes(bytes)} adesso.'
        '${suggestNow ? '\n\nSono file che il telefono non usa: eliminarli subito è sicuro.' : ''}',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Nel cestino')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elimina subito')),
      ],
    ),
  );
}

/// Pulsante in basso che chiede: nel cestino o eliminare subito.
class CleanBar extends StatelessWidget {
  const CleanBar({
    super.key,
    required this.paths,
    required this.state,
    this.onDone,
    this.suggestNow = false,
  });
  final Set<String> paths;
  final AppState state;
  final VoidCallback? onDone;
  final bool suggestNow;

  @override
  Widget build(BuildContext context) {
    final sizes = state.index?.sizeOf ?? const <String, int>{};
    final bytes = paths.fold<int>(0, (s, p) => s + (sizes[p] ?? 0));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: paths.isEmpty
              ? null
              : () async {
                  final now = await askDeleteMode(context,
                      count: paths.length, bytes: bytes, suggestNow: suggestNow);
                  if (now == null) return;
                  final r = await state.clean(paths.toList(), const {}, now: now);
                  onDone?.call();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(now
                            ? '${r.count} file eliminati · liberati ${formatBytes(r.freed)}'
                            : '${r.count} file nel cestino')));
                  }
                },
          icon: const Icon(Icons.delete_outline),
          label: Text(paths.isEmpty
              ? 'Seleziona i file da togliere'
              : 'Togli ${paths.length} · ${formatBytes(bytes)}'),
        ),
      ),
    );
  }
}
