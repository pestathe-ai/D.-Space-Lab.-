/// Riconosce documenti scaduti e importanti dal testo (tutto offline).
library;

const _mesi = {
  'gen': 1, 'gennaio': 1, 'jan': 1, 'january': 1,
  'feb': 2, 'febbraio': 2, 'february': 2,
  'mar': 3, 'marzo': 3, 'march': 3,
  'apr': 4, 'aprile': 4, 'april': 4,
  'mag': 5, 'maggio': 5, 'may': 5,
  'giu': 6, 'giugno': 6, 'jun': 6, 'june': 6,
  'lug': 7, 'luglio': 7, 'jul': 7, 'july': 7,
  'ago': 8, 'agosto': 8, 'aug': 8, 'august': 8,
  'set': 9, 'settembre': 9, 'sep': 9, 'sept': 9, 'september': 9,
  'ott': 10, 'ottobre': 10, 'oct': 10, 'october': 10,
  'nov': 11, 'novembre': 11, 'november': 11,
  'dic': 12, 'dicembre': 12, 'dec': 12, 'december': 12,
};

final _numeric = RegExp(r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})\b');
final _iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
final _dayMonth = RegExp(
    r'\b(\d{1,2})\s+([a-zà]{3,10})\.?\s+(\d{4})\b', caseSensitive: false);
final _monthDay = RegExp(
    r'\b([a-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})\b', caseSensitive: false);

DateTime? _make(int y, int m, int d) {
  if (y < 100) y += 2000;
  if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m ? dt : null; // scarta 31/02 ecc.
}

/// Tutte le date plausibili trovate nel testo (formati italiani e inglesi).
List<DateTime> findDates(String text) {
  final out = <DateTime>[];
  for (final m in _iso.allMatches(text)) {
    final d = _make(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (d != null) out.add(d);
  }
  for (final m in _numeric.allMatches(text)) {
    // in Italia giorno/mese/anno
    final d = _make(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    if (d != null) out.add(d);
  }
  for (final m in _dayMonth.allMatches(text)) {
    final mon = _mesi[m[2]!.toLowerCase()];
    if (mon == null) continue;
    final d = _make(int.parse(m[3]!), mon, int.parse(m[1]!));
    if (d != null) out.add(d);
  }
  for (final m in _monthDay.allMatches(text)) {
    final mon = _mesi[m[1]!.toLowerCase()];
    if (mon == null) continue;
    final d = _make(int.parse(m[3]!), mon, int.parse(m[2]!));
    if (d != null) out.add(d);
  }
  return out;
}

/// Parole che indicano qualcosa con una scadenza (biglietti, prenotazioni…).
const ticketWords = {
  'carta d\'imbarco': 'Carta d\'imbarco',
  'boarding pass': 'Carta d\'imbarco',
  'gate': 'Volo',
  'volo': 'Volo',
  'flight': 'Volo',
  'biglietto': 'Biglietto',
  'ticket': 'Biglietto',
  'trenitalia': 'Treno',
  'italo': 'Treno',
  'frecciarossa': 'Treno',
  'carrozza': 'Treno',
  'prenotazione': 'Prenotazione',
  'booking': 'Prenotazione',
  'check-in': 'Prenotazione',
  'check-out': 'Prenotazione',
  'conferma dell\'ordine': 'Ordine',
  'coupon': 'Coupon',
  'buono sconto': 'Coupon',
  'voucher': 'Coupon',
  'codice sconto': 'Coupon',
  'valido fino': 'Scadenza',
  'valid until': 'Scadenza',
  'ingresso': 'Evento',
  'posto': 'Evento',
  'settore': 'Evento',
  'concerto': 'Evento',
  'evento': 'Evento',
  'qr code': 'Biglietto',
};

/// Parole che indicano un documento da conservare.
const importantWords = {
  'carta d\'identità': 'Documento d\'identità',
  'carta di identità': 'Documento d\'identità',
  'passaporto': 'Passaporto',
  'patente di guida': 'Patente',
  'codice fiscale': 'Codice fiscale',
  'tessera sanitaria': 'Tessera sanitaria',
  'contratto': 'Contratto',
  'busta paga': 'Busta paga',
  'cedolino': 'Busta paga',
  'certificazione unica': 'Certificazione Unica',
  'modello 730': 'Dichiarazione dei redditi',
  'dichiarazione dei redditi': 'Dichiarazione dei redditi',
  'polizza': 'Assicurazione',
  'assicurazione': 'Assicurazione',
  'referto': 'Documento medico',
  'diagnosi': 'Documento medico',
  'certificato medico': 'Documento medico',
  'diploma': 'Titolo di studio',
  'laurea': 'Titolo di studio',
  'atto notarile': 'Atto notarile',
  'rogito': 'Atto notarile',
  'mutuo': 'Mutuo',
  'estratto conto': 'Banca',
  'garanzia': 'Garanzia',
  'fattura': 'Fattura',
  'ricevuta fiscale': 'Ricevuta',
  'bolletta': 'Bolletta',
  'agenzia delle entrate': 'Fisco',
  'inps': 'INPS',
};

class DocFacts {
  const DocFacts({
    required this.textChars,
    required this.ticketHits,
    required this.importantHits,
    this.latestDateMs,
  });

  final int textChars;

  /// Etichette trovate (es. "Volo", "Biglietto").
  final List<String> ticketHits;
  final List<String> importantHits;

  /// Data più recente trovata nel testo.
  final int? latestDateMs;

  Map<String, Object?> toJson() => {
        'c': textChars,
        't': ticketHits,
        'i': importantHits,
        'd': latestDateMs,
      };

  static DocFacts fromJson(Map<String, dynamic> m) => DocFacts(
        textChars: (m['c'] as num?)?.toInt() ?? 0,
        ticketHits: [for (final e in (m['t'] as List? ?? const [])) '$e'],
        importantHits: [for (final e in (m['i'] as List? ?? const [])) '$e'],
        latestDateMs: (m['d'] as num?)?.toInt(),
      );
}

List<String> _hits(String lower, Map<String, String> words) {
  final out = <String>{};
  words.forEach((w, label) {
    // parole brevi: solo come parola intera
    if (w.length <= 5) {
      if (RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(lower)) out.add(label);
    } else if (lower.contains(w)) {
      out.add(label);
    }
  });
  return out.toList()..sort();
}

DocFacts extractFacts(String text) {
  final lower = text.toLowerCase();
  final dates = findDates(text);
  dates.sort();
  return DocFacts(
    textChars: text.replaceAll(RegExp(r'\s'), '').length,
    ticketHits: _hits(lower, ticketWords),
    importantHits: _hits(lower, importantWords),
    latestDateMs: dates.isEmpty ? null : dates.last.millisecondsSinceEpoch,
  );
}

enum DocVerdict { expired, important, other }

/// Scaduto: almeno 2 indizi da "biglietto" e tutte le date nel passato.
/// Importante: parole da documento da conservare (e non scaduto).
DocVerdict classify(DocFacts f, DateTime now) {
  final strongTicket = f.ticketHits.length >= 2 ||
      f.ticketHits.contains('Carta d\'imbarco') ||
      f.ticketHits.contains('Coupon');
  if (strongTicket && f.latestDateMs != null) {
    final latest = DateTime.fromMillisecondsSinceEpoch(f.latestDateMs!);
    // nel dubbio vince "importante" (es. fattura di un volo)
    if (f.importantHits.isEmpty && latest.isBefore(now.subtract(const Duration(days: 1)))) {
      return DocVerdict.expired;
    }
  }
  if (f.importantHits.isNotEmpty) return DocVerdict.important;
  return DocVerdict.other;
}

/// Nome "copia": "fattura (1).pdf", "fattura-1.pdf", "Copia di fattura.pdf".
bool looksLikeCopyName(String name) {
  final n = name.toLowerCase();
  return RegExp(r'\(\d+\)\.[a-z0-9]+$').hasMatch(n) ||
      RegExp(r'[-_ ]\d\.[a-z0-9]+$').hasMatch(n) ||
      n.startsWith('copia di ') ||
      n.startsWith('copy of ') ||
      n.contains(' - copia');
}
