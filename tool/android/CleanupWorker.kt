package dev.dspacelab.d_space_lab

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.text.format.Formatter
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Pulizia programmata: svuota ciò che è nel cestino da più di 30 giorni,
 * elimina le miniature (se scelto) e manda una notifica con lo spazio libero.
 * Non tocca mai foto, video o documenti.
 */
class CleanupWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        if (!Environment.isExternalStorageManager()) return Result.success()
        val ctx = applicationContext
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        @Suppress("DEPRECATION")
        val root = Environment.getExternalStorageDirectory()
        var freed = 0L
        freed += purgeTrash(root)
        if (prefs.getBoolean("thumbs", true)) {
            for (d in listOf("DCIM/.thumbnails", "Pictures/.thumbnails")) {
                freed += deleteContents(File(root, d))
            }
        }
        prefs.edit()
            .putLong("lastRun", System.currentTimeMillis())
            .putLong("lastFreed", freed)
            .apply()
        notify(ctx, root, freed)
        return Result.success()
    }

    private fun sizeOf(f: File): Long =
        if (f.isDirectory) f.walkBottomUp().filter { it.isFile }.sumOf { it.length() } else f.length()

    private fun purgeTrash(root: File): Long {
        val index = File(root, ".DSpaceLab/cestino.json")
        if (!index.exists()) return 0
        val arr = try {
            JSONArray(index.readText())
        } catch (e: Exception) {
            return 0
        }
        val limit = System.currentTimeMillis() - 30L * 24 * 3600 * 1000
        val keep = JSONArray()
        var freed = 0L
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optLong("d") < limit) {
                val f = File(o.optString("t"))
                if (f.exists()) {
                    val s = sizeOf(f)
                    if (f.deleteRecursively()) freed += s else keep.put(o)
                }
            } else {
                keep.put(o)
            }
        }
        if (keep.length() != arr.length()) {
            val tmp = File(index.path + ".tmp")
            tmp.writeText(keep.toString())
            tmp.renameTo(index)
        }
        return freed
    }

    private fun deleteContents(dir: File): Long {
        if (!dir.isDirectory) return 0
        var freed = 0L
        dir.listFiles()?.forEach { f ->
            if (f.name == ".nomedia") return@forEach
            val s = sizeOf(f)
            if (f.deleteRecursively()) freed += s
        }
        return freed
    }

    private fun notify(ctx: Context, root: File, freed: Long) {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(
                ctx, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(NotificationChannel(
            CHANNEL, "Pulizia programmata", NotificationManager.IMPORTANCE_DEFAULT))
        val st = StatFs(root.path)
        val free = st.availableBytes
        val total = st.totalBytes
        val almostFull = total > 0 && free * 10 < total
        val title = if (almostFull) "Memoria quasi piena" else "Pulizia completata"
        val freeTxt = Formatter.formatShortFileSize(ctx, free)
        val text = if (freed > 0) {
            "Liberati ${Formatter.formatShortFileSize(ctx, freed)}. Spazio libero: $freeTxt."
        } else {
            "Spazio libero: $freeTxt. Tocca per vedere cosa si può pulire."
        }
        val open = PendingIntent.getActivity(ctx, 0,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(1, n)
        } catch (e: SecurityException) {
        }
    }

    companion object {
        const val PREFS = "pulizia_programmata"
        private const val CHANNEL = "pulizia"
        private const val WORK = "pulizia"

        fun schedule(ctx: Context, enabled: Boolean, days: Int) {
            val wm = WorkManager.getInstance(ctx)
            if (!enabled) {
                wm.cancelUniqueWork(WORK)
                return
            }
            val req = PeriodicWorkRequestBuilder<CleanupWorker>(days.toLong().coerceAtLeast(1), TimeUnit.DAYS)
                .setConstraints(Constraints.Builder().setRequiresBatteryNotLow(true).build())
                .setInitialDelay(days.toLong().coerceAtLeast(1), TimeUnit.DAYS)
                .build()
            wm.enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.UPDATE, req)
        }

        fun runOnce(ctx: Context) {
            WorkManager.getInstance(ctx).enqueue(OneTimeWorkRequestBuilder<CleanupWorker>().build())
        }
    }
}
