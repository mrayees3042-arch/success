package com.example.success

import android.content.ContentValues
import android.content.Context
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rayees.history/storage"
        ).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("rayees_history", Context.MODE_PRIVATE)
            when (call.method) {
                "getString" -> {
                    val key = call.arguments as? String
                    result.success(if (key == null) null else prefs.getString(key, null))
                }
                "setString" -> {
                    val args = call.arguments as? Map<*, *>
                    val key = args?.get("key") as? String
                    val value = args?.get("value") as? String
                    if (key == null || value == null) {
                        result.error("bad_args", "Missing key or value", null)
                    } else {
                        prefs.edit().putString(key, value).apply()
                        result.success(true)
                    }
                }
                "savePdfToDownloads" -> {
                    val args = call.arguments as? Map<*, *>
                    val fileName = args?.get("fileName") as? String
                    val bytes = args?.get("bytes") as? ByteArray
                    if (fileName == null || bytes == null) {
                        result.error("bad_args", "Missing fileName or bytes", null)
                    } else {
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                            val resolver = applicationContext.contentResolver
                            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                ?: throw IllegalStateException("Could not create PDF file")
                            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                                ?: throw IllegalStateException("Could not open PDF output stream")
                            values.clear()
                            values.put(MediaStore.Downloads.IS_PENDING, 0)
                            resolver.update(uri, values, null, null)
                            result.success("Downloads/$fileName")
                        } catch (error: Exception) {
                            result.error("save_failed", error.message, null)
                        }
                    }
                }
                "saveScreenshotToGallery" -> {
                    val args = call.arguments as? Map<*, *>
                    val fileName = args?.get("fileName") as? String
                    val bytes = args?.get("bytes") as? ByteArray
                    if (fileName == null || bytes == null) {
                        result.error("bad_args", "Missing fileName or bytes", null)
                    } else {
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/SuccessScreenshots")
                                put(MediaStore.Images.Media.IS_PENDING, 1)
                            }
                            val resolver = applicationContext.contentResolver
                            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                                ?: throw IllegalStateException("Could not create image file")
                            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                                ?: throw IllegalStateException("Could not open image output stream")
                            values.clear()
                            values.put(MediaStore.Images.Media.IS_PENDING, 0)
                            resolver.update(uri, values, null, null)
                            result.success("Pictures/SuccessScreenshots/$fileName")
                        } catch (error: Exception) {
                            result.error("save_failed", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
