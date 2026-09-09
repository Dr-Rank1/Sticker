package com.stickr.stickr

import android.content.ContentProvider
import android.content.ContentValues
import android.content.UriMatcher
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException

/**
 * Pure Android ContentProvider that implements WhatsApp's sticker contract.
 *
 * URI paths, MIME types, and cursor column names are part of WhatsApp's public
 * sticker interface. Renaming them breaks Add to WhatsApp.
 *
 *   content://{applicationId}.stickercontentprovider/metadata
 *   content://{applicationId}.stickercontentprovider/metadata/{identifier}
 *   content://{applicationId}.stickercontentprovider/stickers/{identifier}
 *   content://{applicationId}.stickercontentprovider/stickers_asset/{identifier}/{file}
 */
class StickerContentProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        val ctx = context ?: return false
        val authority = BuildConfig.CONTENT_PROVIDER_AUTHORITY
        val packageName = ctx.packageName
        require(authority.startsWith(packageName)) {
            "ContentProvider authority ($authority) must start with $packageName"
        }
        StickerPackStore.recoverInterruptedStaging(ctx)
        synchronized(MATCHER) {
            if (!matcherInitialized) {
                MATCHER.addURI(authority, METADATA, METADATA_CODE)
                MATCHER.addURI(authority, "$METADATA/*", METADATA_CODE_FOR_SINGLE_PACK)
                MATCHER.addURI(authority, "$STICKERS/*", STICKERS_CODE)
                MATCHER.addURI(authority, "$STICKERS_ASSET/*/*", STICKERS_ASSET_CODE)
                matcherInitialized = true
            }
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        return when (MATCHER.match(uri)) {
            METADATA_CODE -> metadataCursor(uri, identifier = null)
            METADATA_CODE_FOR_SINGLE_PACK ->
                metadataCursor(uri, identifier = uri.lastPathSegment)
            STICKERS_CODE -> stickersCursor(uri, identifier = uri.lastPathSegment)
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }

    override fun getType(uri: Uri): String {
        val authority = BuildConfig.CONTENT_PROVIDER_AUTHORITY
        return when (MATCHER.match(uri)) {
            METADATA_CODE -> "vnd.android.cursor.dir/vnd.$authority.$METADATA"
            METADATA_CODE_FOR_SINGLE_PACK ->
                "vnd.android.cursor.item/vnd.$authority.$METADATA"
            STICKERS_CODE -> "vnd.android.cursor.dir/vnd.$authority.$STICKERS"
            STICKERS_ASSET_CODE -> {
                val fileName = uri.lastPathSegment.orEmpty()
                if (fileName.endsWith(".png", ignoreCase = true)) "image/png" else "image/webp"
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor {
        val file = resolveAssetFile(uri)
        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        return AssetFileDescriptor(pfd, 0, file.length())
    }

    override fun openTypedAssetFile(
        uri: Uri,
        mimeTypeFilter: String,
        opts: Bundle?,
    ): AssetFileDescriptor {
        return openAssetFile(uri, "r")
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val file = resolveAssetFile(uri)
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri {
        throw UnsupportedOperationException("Not supported")
    }

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
        throw UnsupportedOperationException("Not supported")
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        throw UnsupportedOperationException("Not supported")
    }

    private fun metadataCursor(uri: Uri, identifier: String?): Cursor {
        val ctx = context ?: throw IllegalStateException("Context is null")
        val cursor = MatrixCursor(
            arrayOf(
                STICKER_PACK_IDENTIFIER_IN_QUERY,
                STICKER_PACK_NAME_IN_QUERY,
                STICKER_PACK_PUBLISHER_IN_QUERY,
                STICKER_PACK_ICON_IN_QUERY,
                ANDROID_APP_DOWNLOAD_LINK_IN_QUERY,
                IOS_APP_DOWNLOAD_LINK_IN_QUERY,
                PUBLISHER_EMAIL,
                PUBLISHER_WEBSITE,
                PRIVACY_POLICY_WEBSITE,
                LICENSE_AGREEMENT_WEBSITE,
                IMAGE_DATA_VERSION,
                AVOID_CACHE,
                ANIMATED_STICKER_PACK,
            ),
        )
        for (pack in StickerPackStore.loadPacks(ctx)) {
            val packId = pack.optString(KEY_IDENTIFIER)
            if (identifier != null && identifier != packId) continue
            cursor.newRow()
                .add(packId)
                .add(pack.optString(KEY_NAME))
                .add(pack.optString(KEY_PUBLISHER))
                .add(pack.optString(KEY_TRAY_IMAGE_FILE))
                .add(pack.optString(KEY_ANDROID_PLAY_STORE_LINK))
                .add(pack.optString(KEY_IOS_APP_STORE_LINK))
                .add(pack.optString(KEY_PUBLISHER_EMAIL))
                .add(pack.optString(KEY_PUBLISHER_WEBSITE))
                .add(pack.optString(KEY_PRIVACY_POLICY_WEBSITE))
                .add(pack.optString(KEY_LICENSE_AGREEMENT_WEBSITE))
                .add(pack.optString(KEY_IMAGE_DATA_VERSION))
                .add(if (pack.optBoolean(KEY_AVOID_CACHE)) 1 else 0)
                .add(if (pack.optBoolean(KEY_ANIMATED_STICKER_PACK)) 1 else 0)
        }
        cursor.setNotificationUri(ctx.contentResolver, uri)
        return cursor
    }

    private fun stickersCursor(uri: Uri, identifier: String?): Cursor {
        val ctx = context ?: throw IllegalStateException("Context is null")
        val cursor = MatrixCursor(
            arrayOf(
                STICKER_FILE_NAME_IN_QUERY,
                STICKER_FILE_EMOJI_IN_QUERY,
                STICKER_FILE_ACCESSIBILITY_TEXT_IN_QUERY,
            ),
        )
        val pack = identifier?.let { StickerPackStore.findPack(ctx, it) }
        val stickers: JSONArray? = pack?.optJSONArray(KEY_STICKERS)
        if (stickers != null) {
            for (i in 0 until stickers.length()) {
                val sticker: JSONObject = stickers.getJSONObject(i)
                cursor.addRow(
                    arrayOf(
                        sticker.optString(KEY_IMAGE_FILE),
                        joinEmojis(sticker.optJSONArray(KEY_EMOJIS)),
                        sticker.optString(KEY_ACCESSIBILITY_TEXT),
                    ),
                )
            }
        }
        cursor.setNotificationUri(ctx.contentResolver, uri)
        return cursor
    }

    private fun resolveAssetFile(uri: Uri): File {
        if (MATCHER.match(uri) != STICKERS_ASSET_CODE) {
            throw FileNotFoundException("Unknown URI: $uri")
        }
        val segments = uri.pathSegments
        if (segments.size != 3) {
            throw FileNotFoundException("Asset URI must have 3 path segments: $uri")
        }
        val ctx = context ?: throw FileNotFoundException("File not found $uri")
        return StickerPackStore.resolveAsset(ctx, segments[1], segments[2])
            ?: throw FileNotFoundException("File not found $uri")
    }

    companion object {
        /**
         * Do not change these path or column strings. WhatsApp's sticker importer
         * matches them exactly.
         */
        const val METADATA = "metadata"
        const val STICKERS = "stickers"
        const val STICKERS_ASSET = "stickers_asset"

        const val STICKER_PACK_IDENTIFIER_IN_QUERY = "sticker_pack_identifier"
        const val STICKER_PACK_NAME_IN_QUERY = "sticker_pack_name"
        const val STICKER_PACK_PUBLISHER_IN_QUERY = "sticker_pack_publisher"
        const val STICKER_PACK_ICON_IN_QUERY = "sticker_pack_icon"
        const val ANDROID_APP_DOWNLOAD_LINK_IN_QUERY = "android_play_store_link"
        const val IOS_APP_DOWNLOAD_LINK_IN_QUERY = "ios_app_download_link"
        const val PUBLISHER_EMAIL = "sticker_pack_publisher_email"
        const val PUBLISHER_WEBSITE = "sticker_pack_publisher_website"
        const val PRIVACY_POLICY_WEBSITE = "sticker_pack_privacy_policy_website"
        const val LICENSE_AGREEMENT_WEBSITE = "sticker_pack_license_agreement_website"
        const val IMAGE_DATA_VERSION = "image_data_version"
        const val AVOID_CACHE = "whatsapp_will_not_cache_stickers"
        const val ANIMATED_STICKER_PACK = "animated_sticker_pack"
        const val STICKER_FILE_NAME_IN_QUERY = "sticker_file_name"
        const val STICKER_FILE_EMOJI_IN_QUERY = "sticker_emoji"
        const val STICKER_FILE_ACCESSIBILITY_TEXT_IN_QUERY = "sticker_accessibility_text"

        private const val METADATA_CODE = 1
        private const val METADATA_CODE_FOR_SINGLE_PACK = 2
        private const val STICKERS_CODE = 3
        private const val STICKERS_ASSET_CODE = 4

        private const val KEY_IDENTIFIER = "identifier"
        private const val KEY_NAME = "name"
        private const val KEY_PUBLISHER = "publisher"
        private const val KEY_TRAY_IMAGE_FILE = "tray_image_file"
        private const val KEY_ANDROID_PLAY_STORE_LINK = "android_play_store_link"
        private const val KEY_IOS_APP_STORE_LINK = "ios_app_store_link"
        private const val KEY_PUBLISHER_EMAIL = "publisher_email"
        private const val KEY_PUBLISHER_WEBSITE = "publisher_website"
        private const val KEY_PRIVACY_POLICY_WEBSITE = "privacy_policy_website"
        private const val KEY_LICENSE_AGREEMENT_WEBSITE = "license_agreement_website"
        private const val KEY_IMAGE_DATA_VERSION = "image_data_version"
        private const val KEY_AVOID_CACHE = "avoid_cache"
        private const val KEY_ANIMATED_STICKER_PACK = "animated_sticker_pack"
        private const val KEY_STICKERS = "stickers"
        private const val KEY_IMAGE_FILE = "image_file"
        private const val KEY_EMOJIS = "emojis"
        private const val KEY_ACCESSIBILITY_TEXT = "accessibility_text"

        private val MATCHER = UriMatcher(UriMatcher.NO_MATCH)
        private var matcherInitialized = false

        private fun joinEmojis(emojis: JSONArray?): String {
            if (emojis == null || emojis.length() == 0) return ""
            val values = ArrayList<String>(emojis.length())
            for (i in 0 until emojis.length()) {
                val value = emojis.optString(i)
                if (value.isNotBlank()) values += value
            }
            return values.joinToString(",")
        }
    }
}
