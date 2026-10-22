package dev.dspacelab.d_space_lab

import android.app.Application
import android.util.Log
import androidx.work.Configuration
import java.io.File

/**
 * Applicazione: annota l'ultimo errore grave (per mostrarlo al riavvio)
 * e prepara WorkManager solo quando serve, non all'avvio.
 */
class SpaceLabApp : Application(), Configuration.Provider {

    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            try {
                File(filesDir, CRASH_FILE).writeText(
                    "${System.currentTimeMillis()}\n${Log.getStackTraceString(e)}".take(6000))
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(t, e)
        }
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().setMinimumLoggingLevel(Log.WARN).build()

    companion object {
        const val CRASH_FILE = "ultimo_errore.txt"
    }
}
