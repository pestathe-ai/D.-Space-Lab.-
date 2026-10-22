import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';

import 'ui/app_state.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Invece della schermata grigia, un messaggio leggibile.
  ErrorWidget.builder = (d) => Material(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Errore: ${d.exceptionAsString()}',
              style: const TextStyle(fontSize: 12)),
        ),
      );
  await pdfrxFlutterInitialize();
  runApp(const SpaceLabApp());
}

class SpaceLabApp extends StatefulWidget {
  const SpaceLabApp({super.key});

  @override
  State<SpaceLabApp> createState() => _SpaceLabAppState();
}

class _SpaceLabAppState extends State<SpaceLabApp> {
  final state = AppState();

  // Stile Dom Studio "Domus": blu-casa, arancio-tetto, carta, Sora.
  ThemeData _theme(Brightness b) {
    final light = b == Brightness.light;
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D3A8A),
      brightness: b,
    ).copyWith(
      primary: light ? const Color(0xFF1D3A8A) : const Color(0xFF8FA9F2),
      onPrimary: light ? Colors.white : const Color(0xFF121621),
      primaryContainer: light ? const Color(0xFFE6ECFA) : const Color(0xFF24305A),
      onPrimaryContainer: light ? const Color(0xFF1D3A8A) : const Color(0xFF8FA9F2),
      secondary: light ? const Color(0xFFF28C38) : const Color(0xFFF5A05A),
      surface: light ? const Color(0xFFFFF8F0) : const Color(0xFF121621),
      surfaceContainerLow: light ? Colors.white : const Color(0xFF1B2130),
      onSurface: light ? const Color(0xFF14213D) : const Color(0xFFF3ECE3),
      onSurfaceVariant: light ? const Color(0xFF5B6475) : const Color(0xFFA7AFBE),
      outlineVariant: light ? const Color(0xFFE8DCCB) : const Color(0xFF2C3446),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: cs);
    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      textTheme: GoogleFonts.soraTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.sora(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        titleTextStyle: GoogleFonts.sora(
            fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'D. Space Lab',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomePage(state: state),
      );
}
