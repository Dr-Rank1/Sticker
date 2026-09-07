package com.stikk.stikk

import android.content.ContentProvider
import android.content.ContentValues
import android.content.UriMatcher
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.text.TextUtils
import org.json.JSONArray
import org.json.JSONObject
import java.io.FileNotFoundException

/**
 * Exposes pack metadata, tray icons, and WebP stickers to WhatsApp.
 *
 * URI paths and cursor column names match WhatsApp's sticker ContentProvider contract
 * and must not be renamed.
 */
class StickerContentProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        synchronized(MATCHER) {
            if (!matcherInitialized) {
                val authority = BuildConfig.CONTENT_PROVIDER_AUTHORITY
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
            METADATA_CODE -> packMetadataCursor(uri, identifier = null)
            METADATA_CODE_FOR_SINGLE_PACK -> packMetadataCursor(uri, identifier = uri.lastPathSegment)
            STICKERS_CODE -> stickersCursor(uri, identifier = uri.lastPathSegment)
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }

    override fun getType(uri: Uri): String {
        return when (MATCHER.match(uri)) {
            METADATA_CODE -> "vnd.android.cursor.dir/vnd.com.whatsapp.provider.sticker_pack"
            METADATA_CODE_FOR_SINGLE_PACK ->
                "vnd.android.cursor.item/vnd.com.whatsapp.provider.sticker_pack"
            STICKERS_CODE -> "vnd.android.cursor.dir/vnd.com.whatsapp.provider.sticker"
            STICKERS_ASSET_CODE -> {
                val fileName = uri.lastPathSegment.orEmpty()
                if (fileName.endsWith(".png", ignoreCase = true)) "image/png" else "image/webp"
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor {
        val pfd = openFile(uri, mode) ?: throw FileNotFoundException("File not found $uri")
        return AssetFileDescriptor(pfd, 0, AssetFileDescriptor.UNKNOWN_LENGTH)
    }

    override fun openTypedAssetFile(
        uri: Uri,
        mimeTypeFilter: String,
        opts: Bundle?,
    ): AssetFileDescriptor {
        return openAssetFile(uri, "r")
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        if (MATCHER.match(uri) != STICKERS_ASSET_CODE) {
            throw IllegalArgumentException("Unknown URI: $uri")
        }
        val segments = uri.pathSegments
        if (segments.size < 3) {
            throw FileNotFoundException("File not found $uri")
        }
        val ctx = context ?: throw FileNotFoundException("File not found $uri")
        val file = StickerPackStore.resolveAsset(ctx, segments[1], segments[2])
            ?: throw FileNotFoundException("File not found $uri")
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    private fun packMetadataCursor(uri: Uri, identifier: String?): Cursor {
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
            val packId = pack.optString("identifier")
            if (identifier != null && identifier != packId) continue
            cursor.newRow()
                .add(packId)
                .add(pack.optString("name"))
                .add(pack.optString("publisher"))
                .add(pack.optString("tray_image_file"))
                .add(pack.optString("android_play_store_link"))
                .add(pack.optString("ios_app_store_link"))
                .add(pack.optString("publisher_email"))
                .add(pack.optString("publisher_website"))
                .add(pack.optString("privacy_policy_website"))
                .add(pack.optString("license_agreement_website"))
                .add(pack.optString("image_data_version"))
                .add(if (pack.optBoolean("avoid_cache")) 1 else 0)
                .add(if (pack.optBoolean("animated_sticker_pack")) 1 else 0)
        }
        cursor.setNotificationUri(ctx.contentResolver, uri)
        return cursor
    }

    private fun stickersCursor(uri: Uri, identifier: String?): Cursor {
        val ctx = context ?: throw IllegalStateException("Context is null")
        val cursor = MatrixCursor(
            arrayOf(
                STICKER_FILE_NAME_IN_QUERY,
                STICKER_EMOJI_IN_QUERY,
                STICKER_ACCESSIBILITY_TEXT_IN_QUERY,
            ),
        )
        val pack = identifier?.let { StickerPackStore.findPack(ctx, it) }
        val stickers: JSONArray? = pack?.optJSONArray("stickers")
        if (stickers != null) {
            for (i in 0 until stickers.length()) {
                val sticker: JSONObject = stickers.getJSONObject(i)
                val emojis = sticker.optJSONArray("emojis")
                val emojiList = buildList {
                    if (emojis != null) {
                        for (j in 0 until emojis.length()) add(emojis.optString(j))
                    }
                }
                cursor.addRow(
                    arrayOf(
                        sticker.optString("image_file"),
                        TextUtils.join(",", emojiList),
                        sticker.optString("accessibility_text"),
                    ),
                )
            }
        }
        cursor.setNotificationUri(ctx.contentResolver, uri)
        return cursor
    }

    companion object {
        private const val METADATA = "metadata"
        private const val STICKERS = "stickers"
        private const val STICKERS_ASSET = "stickers_asset"

        private const val METADATA_CODE = 1
        private const val METADATA_CODE_FOR_SINGLE_PACK = 2
        private const val STICKERS_CODE = 3
        private const val STICKERS_ASSET_CODE = 4

        private const val STICKER_PACK_IDENTIFIER_IN_QUERY = "sticker_pack_identifier"
        private const val STICKER_PACK_NAME_IN_QUERY = "sticker_pack_name"
        private const val STICKER_PACK_PUBLISHER_IN_QUERY = "sticker_pack_publisher"
        private const val STICKER_PACK_ICON_IN_QUERY = "sticker_pack_icon"
        private const val ANDROID_APP_DOWNLOAD_LINK_IN_QUERY = "android_play_store_link"
        private const val IOS_APP_DOWNLOAD_LINK_IN_QUERY = "ios_app_download_link"
        private const val PUBLISHER_EMAIL = "sticker_pack_publisher_email"
        private const val PUBLISHER_WEBSITE = "sticker_pack_publisher_website"
        private const val PRIVACY_POLICY_WEBSITE = "sticker_pack_privacy_policy_website"
        private const val LICENSE_AGREEMENT_WEBSITE = "sticker_pack_license_agreement_website"
        private const val IMAGE_DATA_VERSION = "image_data_version"
        private const val AVOID_CACHE = "whatsapp_will_not_cache_stickers"
        private const val ANIMATED_STICKER_PACK = "animated_sticker_pack"
        private const val STICKER_FILE_NAME_IN_QUERY = "sticker_file_name"
        private const val STICKER_EMOJI_IN_QUERY = "sticker_emoji"
        private const val STICKER_ACCESSIBILITY_TEXT_IN_QUERY = "sticker_accessibility_text"

        private val MATCHER = UriMatcher(UriMatcher.NO_MATCH)
        private var matcherInitialized = false
    }
}
