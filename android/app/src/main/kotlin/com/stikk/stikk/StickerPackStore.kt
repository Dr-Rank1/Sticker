package com.stikk.stikk

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Stages sticker packs under filesDir/sticker_packs so [StickerContentProvider]
 * can serve tray PNGs, WebP stickers, and pack metadata to WhatsApp.
 */
object StickerPackStore {
    const val TRAY_FILE_NAME = "tray.png"

    private const val ROOT_DIR = "sticker_packs"
    private const val CONTENTS_FILE = "contents.json"

    fun root(context: Context): File = File(context.filesDir, ROOT_DIR)

    fun packDir(context: Context, identifier: String): File = File(root(context), identifier)

    fun contentsFile(context: Context): File = File(root(context), CONTENTS_FILE)

    fun sanitizeIdentifier(raw: String): String {
        val cleaned = raw.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return cleaned.ifBlank { "pack" }
    }

    fun stagePack(
        context: Context,
        identifier: String,
        name: String,
        publisher: String,
        trayIconPath: String,
        stickerPaths: List<String>,
        imageDataVersion: String,
        animated: Boolean,
    ): String {
        val id = sanitizeIdentifier(identifier)
        val dir = packDir(context, id)
        if (dir.exists()) {
            dir.deleteRecursively()
        }
        if (!dir.mkdirs() && !dir.isDirectory) {
            throw IllegalStateException("Could not create pack directory.")
        }

        copyRequired(File(trayIconPath), File(dir, TRAY_FILE_NAME))

        val stickerFiles = stickerPaths.mapIndexed { index, path ->
            val fileName = "sticker_$index.webp"
            copyRequired(File(path), File(dir, fileName))
            fileName
        }

        val packs = loadPacks(context).filterNot { it.optString("identifier") == id }.toMutableList()
        packs += JSONObject().apply {
            put("identifier", id)
            put("name", name)
            put("publisher", publisher)
            put("tray_image_file", TRAY_FILE_NAME)
            put("image_data_version", imageDataVersion)
            put("avoid_cache", false)
            put("animated_sticker_pack", animated)
            put("publisher_email", "")
            put("publisher_website", "")
            put("privacy_policy_website", "")
            put("license_agreement_website", "")
            put("android_play_store_link", "")
            put("ios_app_store_link", "")
            put(
                "stickers",
                JSONArray().also { array ->
                    stickerFiles.forEach { fileName ->
                        array.put(
                            JSONObject().apply {
                                put("image_file", fileName)
                                put("emojis", JSONArray().put("✨"))
                                put("accessibility_text", "")
                            },
                        )
                    }
                },
            )
        }

        val payload = JSONObject().put(
            "sticker_packs",
            JSONArray().also { array -> packs.forEach(array::put) },
        )
        contentsFile(context).writeText(payload.toString())

        context.contentResolver.notifyChange(
            Uri.parse("content://${BuildConfig.CONTENT_PROVIDER_AUTHORITY}/metadata"),
            null,
        )
        return id
    }

    fun loadPacks(context: Context): List<JSONObject> {
        val file = contentsFile(context)
        if (!file.exists()) return emptyList()
        val array = JSONObject(file.readText()).optJSONArray("sticker_packs") ?: return emptyList()
        return List(array.length()) { array.getJSONObject(it) }
    }

    fun findPack(context: Context, identifier: String): JSONObject? {
        return loadPacks(context).firstOrNull { it.optString("identifier") == identifier }
    }

    fun resolveAsset(context: Context, identifier: String, fileName: String): File? {
        if (!isSafeName(identifier) || !isSafeName(fileName)) return null
        val pack = findPack(context, identifier) ?: return null
        val allowed = mutableSetOf(pack.optString("tray_image_file"))
        val stickers = pack.optJSONArray("stickers")
        if (stickers != null) {
            for (i in 0 until stickers.length()) {
                allowed += stickers.getJSONObject(i).optString("image_file")
            }
        }
        if (fileName !in allowed) return null

        val dir = packDir(context, identifier).canonicalFile
        val file = File(dir, fileName).canonicalFile
        if (file.parentFile?.canonicalFile != dir) return null
        if (!file.isFile) return null
        return file
    }

    private fun copyRequired(source: File, destination: File) {
        if (!source.isFile) {
            throw IllegalArgumentException("Missing sticker file: ${source.path}")
        }
        source.copyTo(destination, overwrite = true)
    }

    private fun isSafeName(value: String): Boolean {
        return value.isNotEmpty() &&
            !value.contains("..") &&
            !value.contains('/') &&
            !value.contains('\\')
    }
}
