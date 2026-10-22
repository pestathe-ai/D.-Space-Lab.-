# Note per continuare lo sviluppo

Stato: **v0.1 scritta ma mai compilata** (la prima build su GitHub Actions va ancora fatta e verificata).

## Com'è fatto
- Flutter, compilato su GitHub Actions (`.github/workflows/build-apk.yml`), APK firmato con la chiave di sviluppo in `tool/signing/`.
- `android/` non è nel repo: lo genera `tool/setup_platforms.sh` (permessi, FileProvider, MainActivity nativa da `tool/android/`, icone da `tool/icon/res`, regole R8 per ML Kit).
- Canale nativo `dspacelab/native`: accesso a tutti i file, radice memoria, spazio totale/libero, apertura file, aggiornamento Galleria.
- `lib/core/`: logica pura testata (tipi file, indice memoria, classificazione documenti, estrazione testo Office/RTF/binari).
- `lib/services/`: lettura documenti (pdfrx + OCR ML Kit), cestino 30 giorni, ponte nativo.
- `lib/ui/`: home (mappa), esplora/file grandi, documenti (scaduti/doppioni/importanti), cestino.

## Stile
Dom Studio "Domus": blu-casa #1D3A8A, arancio-tetto #F28C38, carta #FFF8F0, carattere Sora, firma "un'app Dom Studio". Icona: casa-documento con grafico a torta.

## Prossime versioni (funzioni tipo SD Maid, migliorate)
1. Residui di app disinstallate (cartelle orfane in Android/media e nella memoria)
2. File di sistema inutili: log, temporanei, .thumbnails, cartelle vuote
3. Duplicati di qualsiasi file (stesso motore SHA-1 dei documenti)
4. WhatsApp a fondo: vocali, video, documenti, GIF per tipo e data
5. Cache delle app: dimensioni con StorageStatsManager + scorciatoia "Svuota cache" (niente automazioni fragili)
6. App inutilizzate (permesso Utilizzo app) con disinstallazione
7. Compressione foto
8. Pulizia programmata con notifica

App sorella: D. Gallery Lab (repo pestathe-ai/D.-Gallery-Lab) — non va modificata da qui.
