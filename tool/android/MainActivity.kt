package dev.dspacelab.d_space_lab

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Canale "dspacelab/native": permessi, spazio, apertura file, aggiornamento Galleria. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dspacelab/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)

                    "hasAllFiles" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                            Environment.isExternalStorageManager()
                    )

                    "requestAllFiles" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            try {
                                startActivity(Intent(
                                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                    Uri.parse("package:$packageName")))
                            } catch (e: Exception) {
                                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                            }
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

                    else -> result.notImplemented()
                }
            }
    }
}
