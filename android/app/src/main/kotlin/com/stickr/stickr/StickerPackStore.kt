package com.stickr.stickr

import android.content.Context
import android.net.Uri
import android.system.Os
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * Stages WhatsApp sticker packs under the app documents directory so
 * [StickerContentProvider] can map METADATA / STICKERS queries onto local
 * `.webp` files with [android.os.ParcelFileDescriptor].
 *
 * Flutter already writes user stickers through `getApplicationDocumentsDirectory()`
 * (`app_flutter` on Android). Export copies live next to that tree so WhatsApp
 * never depends on a third-party Flutter plugin to serve bytes.
 */
object StickerPackStore {
    const val TRAY_FILE_NAME = "tray.png"

    private const val ROOT_DIR = "sticker_packs"
    private const val CONTENTS_FILE = "contents.json"
    private const val FLUTTER_DOCUMENTS_DIR = "app_flutter"

    fun documentsDir(context: Context): File {
        val flutterDocs = File(context.applicationInfo.dataDir, FLUTTER_DOCUMENTS_DIR)
        if (flutterDocs.isDirectory || flutterDocs.mkdirs()) return flutterDocs
        return context.filesDir
    }

    fun root(context: Context): File {
        val documentsRoot = File(documentsDir(context), ROOT_DIR)
        val legacyRoot = File(context.filesDir, ROOT_DIR)
        if (!documentsRoot.exists() && legacyRoot.exists()) return legacyRoot
        return documentsRoot
    }

    fun packDir(context: Context, identifier: String): File = File(root(context), identifier)

    fun contentsFile(context: Context): File = File(root(context), CONTENTS_FILE)

    fun sanitizeIdentifier(raw: String): String {
        val cleaned = raw.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return cleaned.ifBlank { "pack" }
    }

    fun recoverInterruptedStaging(context: Context) {
        val root = root(context)
        if (!root.isDirectory) return

        val backupPattern = Regex("""^\.(.+)\.backup-\d+$""")
        val backups = root.listFiles()
            ?.filter { it.isDirectory && backupPattern.matches(it.name) }
            ?.groupBy { backupPattern.matchEntire(it.name)!!.groupValues[1] }
            .orEmpty()
        backups.forEach { (identifier, candidates) ->
            val destination = File(root, identifier)
            val newest = candidates.maxByOrNull(File::lastModified) ?: return@forEach
            if (!destination.exists()) {
                atomicRename(newest, destination)
            }
            candidates.filter { it.exists() }.forEach { it.deleteRecursively() }
        }

        root.listFiles()?.forEach { candidate ->
            val stalePackTemporary =
                candidate.isDirectory &&
                    candidate.name.startsWith(".") &&
                    candidate.name.contains(".tmp-")
            val staleMetadataTemporary =
                candidate.isFile &&
                    candidate.name.startsWith(".$CONTENTS_FILE.tmp-")
            if (stalePackTemporary || staleMetadataTemporary) {
                candidate.deleteRecursively()
            }
        }
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
        recoverInterruptedStaging(context)
        val id = sanitizeIdentifier(identifier)
        val root = root(context)
        if (!root.mkdirs() && !root.isDirectory) {
            throw IllegalStateException("Could not create sticker pack root directory.")
        }
        val dir = packDir(context, id)
        val transactionId = System.nanoTime().toString()
        val temporaryDir = File(root, ".$id.tmp-$transactionId")
        val backupDir = File(root, ".$id.backup-$transactionId")
        val metadataTemporary = File(root, ".$CONTENTS_FILE.tmp-$transactionId")
        if (!temporaryDir.mkdirs() || !temporaryDir.isDirectory) {
            throw IllegalStateException("Could not create temporary pack directory.")
        }

        try {
            copyRequired(File(trayIconPath), File(temporaryDir, TRAY_FILE_NAME))

            val stickerFiles = stickerPaths.mapIndexed { index, path ->
                val fileName = "sticker_$index.webp"
                copyRequired(File(path), File(temporaryDir, fileName))
                JSONObject().apply {
                    put("image_file", fileName)
                    put("source_path", path)
                    put("emojis", JSONArray())
                    put("accessibility_text", "")
                }
            }

            val packs = loadPacks(context)
                .filterNot { it.optString("identifier") == id }
                .toMutableList()
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
                put("stickers", JSONArray().also { array -> stickerFiles.forEach(array::put) })
            }

            val payload = JSONObject().put(
                "sticker_packs",
                JSONArray().also { array -> packs.forEach(array::put) },
            )
            writeSynced(metadataTemporary, payload.toString())
            commitStagedPack(
                temporaryDir = temporaryDir,
                destinationDir = dir,
                backupDir = backupDir,
                metadataTemporary = metadataTemporary,
                metadataDestination = contentsFile(context),
            )
        } finally {
            temporaryDir.deleteRecursively()
            metadataTemporary.delete()
        }

        val authority = BuildConfig.CONTENT_PROVIDER_AUTHORITY
        context.contentResolver.notifyChange(
            Uri.parse("content://$authority/metadata"),
            null,
        )
        context.contentResolver.notifyChange(
            Uri.parse("content://$authority/stickers/$id"),
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

    /**
     * Maps a WhatsApp `stickers_asset/{id}/{file}` request onto a local WebP/PNG
     * in the documents directory. Falls back to the original Flutter file if the
     * staged copy is missing but still inside the app sandbox.
     */
    fun resolveAsset(context: Context, identifier: String, fileName: String): File? {
        if (!isSafeName(identifier) || !isSafeName(fileName)) return null
        val pack = findPack(context, identifier) ?: return null

        val staged = fileInPackDir(context, identifier, fileName)
        if (staged != null) return staged

        if (fileName == pack.optString("tray_image_file")) return null
        val stickers = pack.optJSONArray("stickers") ?: return null
        for (i in 0 until stickers.length()) {
            val sticker = stickers.getJSONObject(i)
            if (sticker.optString("image_file") != fileName) continue
            val source = sticker.optString("source_path")
            if (source.isBlank()) return null
            return sandboxedFile(context, File(source))
        }
        return null
    }

    private fun fileInPackDir(context: Context, identifier: String, fileName: String): File? {
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

    private fun sandboxedFile(context: Context, candidate: File): File? {
        if (!candidate.isFile) return null
        val canonical = try {
            candidate.canonicalFile
        } catch (_: Exception) {
            return null
        }
        val dataDir = File(context.applicationInfo.dataDir).canonicalFile
        val path = canonical.path
        if (!path.startsWith(dataDir.path + File.separator) && path != dataDir.path) {
            return null
        }
        return canonical
    }

    private fun copyRequired(source: File, destination: File) {
        if (!source.isFile) {
            throw IllegalArgumentException("Missing sticker file: ${source.path}")
        }
        source.inputStream().use { input ->
            FileOutputStream(destination).use { output ->
                input.copyTo(output)
                output.flush()
                output.fd.sync()
            }
        }
        if (!destination.isFile || destination.length() == 0L) {
            throw IllegalStateException("Failed to stage sticker file: ${destination.path}")
        }
    }

    private fun writeSynced(destination: File, contents: String) {
        FileOutputStream(destination).use { output ->
            output.write(contents.toByteArray(Charsets.UTF_8))
            output.flush()
            output.fd.sync()
        }
    }

    private fun commitStagedPack(
        temporaryDir: File,
        destinationDir: File,
        backupDir: File,
        metadataTemporary: File,
        metadataDestination: File,
    ) {
        var movedExistingPack = false
        var installedNewPack = false
        try {
            if (destinationDir.exists()) {
                atomicRename(destinationDir, backupDir)
                movedExistingPack = true
            }
            atomicRename(temporaryDir, destinationDir)
            installedNewPack = true
            atomicRename(metadataTemporary, metadataDestination, replace = true)
        } catch (error: Exception) {
            if (installedNewPack) {
                destinationDir.deleteRecursively()
            }
            if (movedExistingPack && backupDir.exists()) {
                try {
                    atomicRename(backupDir, destinationDir)
                } catch (rollbackError: Exception) {
                    error.addSuppressed(rollbackError)
                }
            }
            throw error
        }
        backupDir.deleteRecursively()
    }

    private fun atomicRename(source: File, destination: File, replace: Boolean = false) {
        if (!replace && destination.exists()) {
            throw IllegalStateException("Atomic rename destination already exists.")
        }
        try {
            Os.rename(source.path, destination.path)
        } catch (error: Exception) {
            throw IllegalStateException(
                "Could not atomically rename ${source.name} to ${destination.name}.",
                error,
            )
        }
    }

    private fun isSafeName(value: String): Boolean {
        return value.isNotEmpty() &&
            !value.contains("..") &&
            !value.contains('/') &&
            !value.contains('\\')
    }
}
