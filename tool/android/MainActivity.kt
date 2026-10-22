package dev.dspacelab.d_space_lab

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Process
import android.os.StatFs
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

/** Canale "dspacelab/native": permessi, spazio, file, app, compressione, pulizia programmata. */
class MainActivity : FlutterActivity() {

    private fun bg(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            val r = try {
                Result.success(work())
            } catch (e: Throwable) {
                Result.failure(e)
            }
            runOnUiThread {
                r.fold(
                    { result.success(it) },
                    { result.error("native", it.message ?: it.toString(), null) })
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dspacelab/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)

                    "hasAllFiles" -> result.success(Environment.isExternalStorageManager())

                    "requestAllFiles" -> {
                        try {
                            startActivity(Intent(
                                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                        }
                        result.success(null)
                    }

                    "storageRoot" -> {
                        @Suppress("DEPRECATION")
                        result.success(Environment.getExternalStorageDirectory().absolutePath)
                    }

                    "storageStats" -> {
                        @Suppress("DEPRECATION")
                        val st = StatFs(Environment.getExternalStorageDirectory().absolutePath)
                        result.success(mapOf("total" to st.totalBytes, "free" to st.availableBytes))
                    }

                    "scanMedia" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        if (paths.isNotEmpty()) {
                            MediaScannerConnection.scanFile(applicationContext, paths.toTypedArray(), null, null)
                        }
                        result.success(null)
                    }

                    "openFile" -> {
                        try {
                            val f = File(call.argument<String>("path")!!)
                            val uri = FileProvider.getUriForFile(this, "$packageName.files", f)
                            val ext = f.extension.lowercase()
                            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "*/*"
                            val i = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mime)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(i, "Apri con"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    // ---- app installate ----
                    "installedPackages" -> bg(result) {
                        packageManager.getInstalledPackages(0).map { it.packageName }
                    }

                    "installedApks" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        bg(result) { installedApks(paths) }
                    }

                    "hasUsageAccess" -> result.success(hasUsageAccess())

                    "requestUsageAccess" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS,
                                Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        }
                        result.success(null)
                    }

                    "appsInfo" -> bg(result) { appsInfo() }

                    "openAppSettings" -> {
                        val pkg = call.argument<String>("pkg")!!
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$pkg")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }

                    "uninstall" -> {
                        val pkg = call.argument<String>("pkg")!!
                        @Suppress("DEPRECATION")
                        startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))
                        result.success(null)
                    }

                    // ---- foto ----
                    "compressJpeg" -> {
                        val src = call.argument<String>("src")!!
                        val dst = call.argument<String>("dst")!!
                        val quality = call.argument<Int>("quality") ?: 80
                        val maxSide = call.argument<Int>("maxSide") ?: 4096
                        bg(result) { compressJpeg(src, dst, quality, maxSide) }
                    }

                    // ---- notifiche e pulizia programmata ----
                    "hasNotifications" -> result.success(hasNotifications())

                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT >= 33 && !hasNotifications()) {
                            ActivityCompat.requestPermissions(this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
                        }
                        result.success(null)
                    }

                    "getSchedule" -> {
                        val p = getSharedPreferences(CleanupWorker.PREFS, Context.MODE_PRIVATE)
                        result.success(mapOf(
                            "enabled" to p.getBoolean("enabled", false),
                            "days" to p.getInt("days", 7),
                            "thumbs" to p.getBoolean("thumbs", true),
                            "lastRun" to p.getLong("lastRun", 0L),
                            "lastFreed" to p.getLong("lastFreed", 0L),
                        ))
                    }

                    "setSchedule" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val days = call.argument<Int>("days") ?: 7
                        val thumbs = call.argument<Boolean>("thumbs") ?: true
                        getSharedPreferences(CleanupWorker.PREFS, Context.MODE_PRIVATE).edit()
                            .putBoolean("enabled", enabled)
                            .putInt("days", days)
                            .putBoolean("thumbs", thumbs)
                            .apply()
                        CleanupWorker.schedule(applicationContext, enabled, days)
                        result.success(null)
                    }

                    "runCleanupNow" -> {
                        CleanupWorker.runOnce(applicationContext)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasNotifications(): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** APK la cui app è già installata nella stessa versione o più nuova. */
    private fun installedApks(paths: List<String>): List<String> {
        val out = ArrayList<String>()
        for (p in paths) {
            try {
                val info = packageManager.getPackageArchiveInfo(p, 0) ?: continue
                val inst = try {
                    packageManager.getPackageInfo(info.packageName, 0)
                } catch (e: PackageManager.NameNotFoundException) {
                    null
                } ?: continue
                if (inst.longVersionCode >= info.longVersionCode) out.add(p)
            } catch (e: Exception) {
            }
        }
        return out
    }

    private fun iconPng(ai: ApplicationInfo): ByteArray? = try {
        val d = packageManager.getApplicationIcon(ai)
        val size = 96
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        d.draw(c)
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        out.toByteArray()
    } catch (e: Exception) {
        null
    }

    /** App dell'utente con spazio occupato, cache e ultimo uso. */
    private fun appsInfo(): List<Map<String, Any?>> {
        val pm = packageManager
        val now = System.currentTimeMillis()
        val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val used = try {
            usage.queryAndAggregateUsageStats(now - 365L * 24 * 3600 * 1000, now)
        } catch (e: Exception) {
            emptyMap()
        }
        val ssm = getSystemService(Context.STORAGE_STATS_SERVICE) as StorageStatsManager
        val user = Process.myUserHandle()
        val out = ArrayList<Map<String, Any?>>()
        for (ai in pm.getInstalledApplications(0)) {
            val system = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
            if (system || ai.packageName == packageName) continue
            var app = 0L
            var data = 0L
            var cache = 0L
            try {
                val st = ssm.queryStatsForPackage(ai.storageUuid, ai.packageName, user)
                app = st.appBytes
                data = st.dataBytes
                cache = st.cacheBytes
            } catch (e: Exception) {
            }
            val installed = try {
                pm.getPackageInfo(ai.packageName, 0).firstInstallTime
            } catch (e: Exception) {
                0L
            }
            out.add(mapOf(
                "pkg" to ai.packageName,
                "label" to pm.getApplicationLabel(ai).toString(),
                "app" to app,
                "data" to data,
                "cache" to cache,
                "lastUsed" to (used[ai.packageName]?.lastTimeUsed ?: 0L),
                "installed" to installed,
                "icon" to iconPng(ai),
            ))
        }
        return out
    }

    /**
     * Ricomprime una foto JPEG in [dst] mantenendo i dati EXIF (data, luogo,
     * orientamento, fotocamera). Restituisce la nuova dimensione in byte.
     */
    private fun compressJpeg(src: String, dst: String, quality: Int, maxSide: Int): Long {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(src, bounds)
        val w = bounds.outWidth
        val h = bounds.outHeight
        if (w <= 0 || h <= 0) return -1
        val longSide = maxOf(w, h)
        var sample = 1
        while (longSide / (sample * 2) >= maxSide * 9 / 10) sample *= 2
        var bmp = BitmapFactory.decodeFile(src, BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }) ?: return -1
        val side = maxOf(bmp.width, bmp.height)
        if (side > maxSide) {
            val f = maxSide.toFloat() / side
            val scaled = Bitmap.createScaledBitmap(bmp,
                (bmp.width * f).toInt().coerceAtLeast(1), (bmp.height * f).toInt().coerceAtLeast(1), true)
            if (scaled != bmp) bmp.recycle()
            bmp = scaled
        }
        FileOutputStream(dst).use { bmp.compress(Bitmap.CompressFormat.JPEG, quality, it) }
        bmp.recycle()
        try {
            val a = ExifInterface(src)
            val b = ExifInterface(dst)
            for (tag in EXIF_TAGS) {
                a.getAttribute(tag)?.let { b.setAttribute(tag, it) }
            }
            b.saveAttributes()
        } catch (e: Exception) {
        }
        return File(dst).length()
    }

    companion object {
        private val EXIF_TAGS = listOf(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_OFFSET_TIME,
            ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
            ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
            ExifInterface.TAG_SUBSEC_TIME,
            ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_SOFTWARE,
            ExifInterface.TAG_ARTIST,
            ExifInterface.TAG_IMAGE_DESCRIPTION,
            ExifInterface.TAG_USER_COMMENT,
            ExifInterface.TAG_F_NUMBER,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
            ExifInterface.TAG_GPS_TIMESTAMP,
            ExifInterface.TAG_GPS_DATESTAMP,
        )
    }
}
