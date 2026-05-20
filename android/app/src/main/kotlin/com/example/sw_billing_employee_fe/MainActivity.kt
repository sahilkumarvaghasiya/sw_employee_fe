package com.example.sw_billing_employee_fe

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
	private val channelName = "com.example.sw_billing_employee_fe/downloads"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"saveToDownloads" -> {
						val fileName = call.argument<String>("fileName") ?: "barcode.png"
						val bytes = call.argument<ByteArray>("bytes")
						if (bytes == null) {
							result.error("ARGUMENT_ERROR", "Missing bytes", null)
							return@setMethodCallHandler
						}

						try {
							val location = saveBytesToDownloads(fileName, bytes)
							result.success(location)
						} catch (e: Exception) {
							result.error("SAVE_FAILED", e.message, null)
						}
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun saveBytesToDownloads(fileName: String, bytes: ByteArray): String {
		// Android 10+ (API 29+): save to the public Downloads collection via MediaStore.
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val resolver = applicationContext.contentResolver
			val values = ContentValues().apply {
				put(MediaStore.Downloads.DISPLAY_NAME, fileName)
				put(MediaStore.Downloads.MIME_TYPE, "image/png")
				put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
				put(MediaStore.Downloads.IS_PENDING, 1)
			}

			val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
				?: throw IllegalStateException("Failed to create download entry")

			resolver.openOutputStream(uri)?.use { stream ->
				stream.write(bytes)
				stream.flush()
			} ?: throw IllegalStateException("Failed to open output stream")

			val done = ContentValues().apply {
				put(MediaStore.Downloads.IS_PENDING, 0)
			}
			resolver.update(uri, done, null, null)

			return uri.toString()
		}

		// Legacy devices (< API 29): best-effort write into public Downloads directory.
		@Suppress("DEPRECATION")
		val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
		if (!downloadsDir.exists()) downloadsDir.mkdirs()

		val file = File(downloadsDir, fileName)
		FileOutputStream(file).use { stream ->
			stream.write(bytes)
			stream.flush()
		}

		MediaScannerConnection.scanFile(
			applicationContext,
			arrayOf(file.absolutePath),
			arrayOf("image/png"),
			null,
		)

		return file.absolutePath
	}
}
