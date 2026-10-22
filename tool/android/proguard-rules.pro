# ML Kit: usiamo solo l'alfabeto latino, gli altri pacchetti non sono inclusi.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# WorkManager (pulizia programmata): Room crea il database per riflessione.
# Senza queste regole R8 toglie il costruttore e l'app si chiude all'avvio.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class dev.dspacelab.d_space_lab.** { *; }
