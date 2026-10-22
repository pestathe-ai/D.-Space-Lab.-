# D. Space Lab

Pulizia del telefono, in stile Dom Studio. Tutto offline, tutto sul telefono.

## Novità v0.3
- **Da dove arrivano**: tocca un tipo di file (es. Immagini) e vedi i file divisi per provenienza (Fotocamera, Screenshot, WhatsApp, Sticker, Telegram, Download, file delle app, Miniature…), ognuna con un consiglio: sicuro / da controllare / tuoi.
- **Per peso**: piccolissimi, medi, grandi — spiega perché i file sono tanti ma pesano poco.
- **Scorciatoie** per tipo: screenshot vecchi, video WhatsApp, vocali vecchi, installer già usati, archivi scaricati.
- **Strumenti documenti**: versioni dello stesso file, scaricati e dimenticati, ricevuti su WhatsApp, con date vecchie, vuoti o illeggibili, molto pesanti. Gli importanti sono sempre esclusi.
- Ogni elenco ha filtri per cartella ed età, ordinamento, "Tutti", e la scelta tra cestino ed eliminazione subito.

## Novità v0.2
- **Stima del tempo**: ogni lavoro lungo mostra quanto manca e quanto è passato. La mappa compare subito; i documenti si leggono in sottofondo (si può fermare e riprendere).
- **Pulizia rapida**: miniature, log, temporanei, download interrotti, installer già usati, cestino della Galleria, cartelle vuote. Più i **residui di app disinstallate** (Android/media e cartelle con nome di app).
- **Duplicati di ogni file**: foto, video, musica, archivi. Prima per peso, poi inizio e fine, poi SHA-1 completo solo sui sospetti.
- **WhatsApp a fondo**: per tipo (foto, video, vocali, audio, documenti, GIF, sticker, stati), per età e "solo inviati". Anche Business.
- **App**: cache di ogni app (scorciatoia a "Svuota cache"), app non usate da 2 mesi con disinstallazione, app più pesanti.
- **Comprimi foto**: tre livelli, mantiene data/luogo/orientamento, l'originale va nel cestino 30 giorni.
- **Pulizia programmata**: settimanale, ogni 2 settimane o mensile; svuota il cestino scaduto e le miniature e manda una notifica.
- Il cestino ora accetta anche cartelle intere.

## v0.1
- **Mappa dello spazio**: spazio libero, cosa occupa i GB per tipo (immagini, video, audio, documenti, archivi, APK), esplora le cartelle dalla più pesante, i 200 file più grandi.
- **Documenti**: legge PDF (anche scansionati, con riconoscimento del testo), Word/Excel/PowerPoint (nuovi e vecchi), OpenDocument, RTF e testi.
  - **Scaduti**: biglietti, carte d'imbarco, prenotazioni, coupon con tutte le date nel passato.
  - **Doppioni**: file identici byte per byte; tiene il nome "originale" e fuori da Download.
  - **Importanti**: identità, contratti, buste paga, fisco, salute, banca… da conservare, mai proposti per l'eliminazione.
- **Cestino di sicurezza**: ciò che elimini resta recuperabile 30 giorni, poi sparisce da solo.

## Permessi
- "Accesso a tutti i file" (Android 11+): serve per misurare e pulire la memoria.
- "Accesso ai dati di utilizzo" (facoltativo): cache e ultimo uso delle app.
- Elenco app installate: per riconoscere i residui e gli installer già usati.
- Notifiche (facoltativo): avviso della pulizia programmata.

## Limiti
- Le cartelle `Android/data` e `Android/obb` (dati privati delle app) non sono accessibili senza root: compaiono come "App e sistema".
- Il riconoscimento di scaduti/importanti si basa su parole chiave e date: controlla sempre prima di eliminare.
- La cache delle altre app va svuotata a mano da Impostazioni: Android non lo permette alle app normali.
- La stima del tempo della prima analisi arriva solo dalla seconda volta (serve sapere quanti file ci sono).
- Compressione: solo JPEG; HEIC e PNG non vengono toccati.
