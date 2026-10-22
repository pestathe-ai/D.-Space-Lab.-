import 'package:flutter/material.dart';

import '../core/file_types.dart';
import '../services/native.dart';
import 'app_state.dart';
import 'widgets.dart';

/// Pulizia programmata con notifica.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.state});
  final AppState state;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> with WidgetsBindingObserver {
  bool enabled = false;
  int days = 7;
  bool thumbs = true;
  int lastRun = 0, lastFreed = 0;
  bool notif = true;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final m = await Native.getSchedule();
    final n = await Native.hasNotifications();
    if (!mounted) return;
    setState(() {
      enabled = m['enabled'] == true;
      days = (m['days'] as num?)?.toInt() ?? 7;
      thumbs = m['thumbs'] != false;
      lastRun = (m['lastRun'] as num?)?.toInt() ?? 0;
      lastFreed = (m['lastFreed'] as num?)?.toInt() ?? 0;
      notif = n;
      loaded = true;
    });
  }

  Future<void> _save() async {
    await Native.setSchedule(enabled: enabled, days: days, thumbs: thumbs);
    if (enabled && !notif) await Native.requestNotifications();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pulizia programmata')),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    value: enabled,
                    onChanged: (v) {
                      setState(() => enabled = v);
                      _save();
                    },
                    title: const Text('Pulizia automatica'),
                    subtitle: Text(enabled
                        ? 'Attiva: ogni ${days == 7 ? 'settimana' : days == 14 ? '2 settimane' : 'mese'}'
                        : 'Spenta'),
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Text('OGNI QUANTO', style: t.labelMedium?.copyWith(letterSpacing: 1.4)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('Settimana')),
                      ButtonSegment(value: 14, label: Text('2 settimane')),
                      ButtonSegment(value: 30, label: Text('Mese')),
                    ],
                    selected: {days},
                    onSelectionChanged: (v) {
                      setState(() => days = v.first);
                      _save();
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      value: thumbs,
                      onChanged: (v) {
                        setState(() => thumbs = v);
                        _save();
                      },
                      title: const Text('Elimina anche le miniature'),
                      subtitle: const Text(
                          'Anteprime delle foto in DCIM e Pictures: il telefono le ricrea.'),
                    ),
                  ),
                  if (!notif)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_off_outlined),
                        title: const Text('Notifiche spente'),
                        subtitle: const Text(
                            'La pulizia funziona lo stesso, ma non riceverai l\'avviso.'),
                        trailing: TextButton(
                            onPressed: () async {
                              await Native.requestNotifications();
                              await Future<void>.delayed(const Duration(seconds: 1));
                              _load();
                            },
                            child: const Text('Attiva')),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Native.runCleanupNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Pulizia avviata: arriva una notifica a breve')));
                      }
                      await Future<void>.delayed(const Duration(seconds: 4));
                      await _load();
                      await widget.state.refreshFree();
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Prova adesso'),
                  ),
                ],
                if (lastRun > 0) ...[
                  const SizedBox(height: 12),
                  InfoCard(
                    icon: Icons.history,
                    text: 'Ultima pulizia: ${shortDate(DateTime.fromMillisecondsSinceEpoch(lastRun))}'
                        ' · liberati ${formatBytes(lastFreed)}',
                  ),
                ],
                const SizedBox(height: 8),
                const InfoCard(
                  icon: Icons.shield_outlined,
                  text: 'Cosa fa: svuota ciò che è nel cestino di D. Space Lab da '
                      'più di 30 giorni, elimina le miniature (se vuoi) e ti avvisa '
                      'con lo spazio libero, o se la memoria è quasi piena. '
                      'Non tocca mai foto, video, documenti o app. Parte solo '
                      'con la batteria non scarica.',
                ),
                const Signature(),
              ],
            ),
    );
  }
}
