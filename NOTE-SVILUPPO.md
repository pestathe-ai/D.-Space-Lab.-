# Note per continuare lo sviluppo

Stato: **v0.2 compilata** (build-3 verde: analisi, test e APK firmato). Non ancora provata su un telefono vero.

## Com'è fatto
- Flutter, compilato su GitHub Actions (`.github/workflows/build-apk.yml`), APK firmato con la chiave di sviluppo in `tool/signing/`.
- `android/` non è nel repo: lo genera `tool/setup_platforms.sh` (permessi, FileProvider, MainActivity nativa da `tool/android/`, icone da `tool/icon/res`, regole R8 per ML Kit).
- Canale nativo `dspacelab/native`: accesso a tutti i file, radice memoria, spazio totale/libero, apertura file, aggiornamento Galleria.
- `lib/core/`: logica pura testata (tipi file, indice memoria, classificazione documenti, estrazione testo Office/RTF/binari).
- `lib/services/`: lettura documenti (pdfrx + OCR ML Kit), cestino 30 giorni, ponte nativo.
- `lib/ui/`: home (mappa), esplora/file grandi, documenti (scaduti/doppioni/importanti), cestino, pulizia rapida, duplicati, WhatsApp, app, comprimi foto, pulizia programmata.
- `lib/core/eta.dart`: stima del tempo (velocità sugli ultimi 20 s). `lib/services/jobs.dart`: lavori in isolate con avanzamento e stop (le funzioni-lavoro nascono a livello di file, mai dentro AppState, altrimenti l'isolate prova a copiare lo stato).
- `lib/core/cleanup.dart`: file inutili, residui app, WhatsApp, candidati alla compressione. `lib/core/duplicates.dart`: duplicati di ogni file.
- Nativo: `tool/android/MainActivity.kt` (app, utilizzo, cache, disinstalla, compressione JPEG con EXIF, notifiche) e `CleanupWorker.kt` (WorkManager). minSdk forzato a 30 da setup_platforms.sh.

## Stile
Dom Studio "Domus": blu-casa #1D3A8A, arancio-tetto #F28C38, carta #FFF8F0, carattere Sora, firma "un'app Dom Studio". Icona: casa-documento con grafico a torta.

## Fatto in v0.2
Stima del tempo, documenti in sottofondo, residui di app, file inutili, duplicati di ogni file, WhatsApp, cache e app inutilizzate, compressione foto, pulizia programmata.

## Idee per dopo
- Foto simili (raffiche, scatti quasi uguali) e foto sfocate
- Video: ricompressione
- Statistiche di quanto spazio si è liberato nel tempo
- Widget sulla schermata Home con lo spazio libero

App sorella: D. Gallery Lab (repo pestathe-ai/D.-Gallery-Lab) — non va modificata da qui.
