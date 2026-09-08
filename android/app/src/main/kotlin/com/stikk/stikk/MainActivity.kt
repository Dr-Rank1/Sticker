package com.stikk.stikk

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private var pendingResult: MethodChannel.Result? = null
    private var stikkChannel: MethodChannel? = null
    private var pendingStikkPath: String? = null

    private val addPackLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        deliverAddPackResult(result.resultCode, result.data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_ADD_STICKER_PACK -> addStickerPack(call, result)
                    else -> result.notImplemented()
                }
            }
        stikkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STIKK_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_GET_INITIAL_STIKK -> {
                        result.success(pendingStikkPath)
                        pendingStikkPath = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        val initialStikk = extractStikkPath(intent)
        if (initialStikk != null) {
            pendingStikkPath = initialStikk
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = extractStikkPath(intent) ?: return
        pendingStikkPath = path
        stikkChannel?.invokeMethod(METHOD_ON_STIKK_FILE, path)
    }

    private fun addStickerPack(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error(ERROR_ALREADY_IN_PROGRESS, "Another export is already running.", null)
            return
        }

        val identifier = call.argument<String>("identifier")
        val name = call.argument<String>("name")
        val publisher = call.argument<String>("publisher")
        val trayIconPath = call.argument<String>("trayIconPath")
        val stickerPaths = (call.argument<List<*>>("stickerPaths") ?: emptyList<Any>())
            .map { it.toString() }
            .filter { it.isNotBlank() }
        val imageDataVersion = call.argument<String>("imageDataVersion") ?: "1"
        val animated = call.argument<Boolean>("animated") ?: true

        if (identifier.isNullOrBlank() ||
            name.isNullOrBlank() ||
            publisher.isNullOrBlank() ||
            trayIconPath.isNullOrBlank() ||
            stickerPaths.isNullOrEmpty()
        ) {
            result.error(ERROR_INVALID_ARGUMENTS, "Missing sticker pack data.", null)
            return
        }

        val stagedId = try {
            StickerPackStore.stagePack(
                context = this,
                identifier = identifier,
                name = name,
                publisher = publisher,
                trayIconPath = trayIconPath,
                stickerPaths = stickerPaths,
                imageDataVersion = imageDataVersion,
                animated = animated,
            )
        } catch (error: Exception) {
            result.error(ERROR_FILE_COPY_FAILED, error.message, null)
            return
        }

        pendingResult = result
        if (!launchEnableStickerPack(stagedId, name)) {
            pendingResult = null
            result.error(ERROR_WHATSAPP_NOT_INSTALLED, "WhatsApp is not installed.", null)
        }
    }

    private fun launchEnableStickerPack(identifier: String, name: String): Boolean {
        val intent = stickerPackIntent(identifier, name)
        return try {
            addPackLauncher.launch(intent)
            true
        } catch (_: ActivityNotFoundException) {
            tryLaunch(intent.setPackage(WHATSAPP_PACKAGE)) ||
                tryLaunch(intent.setPackage(WHATSAPP_BUSINESS_PACKAGE))
        } catch (_: Exception) {
            tryLaunch(intent.setPackage(WHATSAPP_PACKAGE)) ||
                tryLaunch(intent.setPackage(WHATSAPP_BUSINESS_PACKAGE))
        }
    }

    private fun tryLaunch(intent: Intent): Boolean {
        return try {
            addPackLauncher.launch(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun stickerPackIntent(identifier: String, name: String): Intent {
        return Intent(ACTION_ENABLE_STICKER_PACK).apply {
            putExtra(EXTRA_STICKER_PACK_ID, identifier)
            putExtra(EXTRA_STICKER_PACK_AUTHORITY, BuildConfig.CONTENT_PROVIDER_AUTHORITY)
            putExtra(EXTRA_STICKER_PACK_NAME, name)
        }
    }

    private fun deliverAddPackResult(resultCode: Int, data: Intent?) {
        val pending = pendingResult ?: return
        pendingResult = null

        when (resultCode) {
            Activity.RESULT_OK -> pending.success(true)
            Activity.RESULT_CANCELED -> {
                val validationError = data?.getStringExtra(EXTRA_VALIDATION_ERROR)
                if (!validationError.isNullOrBlank()) {
                    pending.error(ERROR_VALIDATION, validationError, null)
                } else {
                    pending.error(ERROR_CANCELLED, "WhatsApp did not add the pack.", null)
                }
            }
            else -> pending.error(ERROR_CANCELLED, "WhatsApp did not add the pack.", null)
        }
    }

    override fun onDestroy() {
        try {
            pendingResult?.error(ERROR_CANCELLED, "Export was interrupted.", null)
        } catch (_: Exception) {
            // The Flutter engine may already have been torn down.
        }
        pendingResult = null
        super.onDestroy()
    }

    private fun extractStikkPath(intent: Intent?): String? {
        if (intent == null) return null
        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> extraStream(intent)
            else -> null
        } ?: return null
        if (!looksLikeStikk(intent, uri)) return null
        return copyUriToCache(uri)
    }

    private fun looksLikeStikk(intent: Intent, uri: Uri): Boolean {
        // VIEW filters only match .stikk files or our pack MIME type.
        if (intent.action == Intent.ACTION_VIEW) return true
        val mime = (intent.type ?: contentResolver.getType(uri) ?: "").lowercase()
        if (mime.contains("stikk") ||
            mime == "application/zip" ||
            mime == "application/octet-stream"
        ) {
            return true
        }
        val path = (uri.lastPathSegment ?: uri.toString()).lowercase()
        return path.contains(".stikk")
    }

    private fun extraStream(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        if (uri.scheme == "file") {
            val path = uri.path
            if (!path.isNullOrBlank() && File(path).exists()) return path
        }
        return try {
            val out = File(cacheDir, "import_${System.currentTimeMillis()}.stikk")
            contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            out.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        const val CHANNEL = "com.stickerapp/whatsapp_export"
        const val METHOD_ADD_STICKER_PACK = "addStickerPack"
        const val STIKK_CHANNEL = "com.stikk.stikk/stikk_files"
        const val METHOD_GET_INITIAL_STIKK = "getInitialStikkFile"
        const val METHOD_ON_STIKK_FILE = "onStikkFile"

        const val ACTION_ENABLE_STICKER_PACK = "com.whatsapp.intent.action.ENABLE_STICKER_PACK"
        const val EXTRA_STICKER_PACK_ID = "sticker_pack_id"
        const val EXTRA_STICKER_PACK_AUTHORITY = "sticker_pack_authority"
        const val EXTRA_STICKER_PACK_NAME = "sticker_pack_name"
        const val EXTRA_VALIDATION_ERROR = "validation_error"

        const val WHATSAPP_PACKAGE = "com.whatsapp"
        const val WHATSAPP_BUSINESS_PACKAGE = "com.whatsapp.w4b"

        const val ERROR_WHATSAPP_NOT_INSTALLED = "WHATSAPP_NOT_INSTALLED"
        const val ERROR_VALIDATION = "VALIDATION_ERROR"
        const val ERROR_CANCELLED = "CANCELLED"
        const val ERROR_ALREADY_IN_PROGRESS = "ALREADY_IN_PROGRESS"
        const val ERROR_INVALID_ARGUMENTS = "INVALID_ARGUMENTS"
        const val ERROR_FILE_COPY_FAILED = "FILE_COPY_FAILED"
    }
}
