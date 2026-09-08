# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# JNI
-keepclasseswithmembernames class * {
    native <methods>;
}

# WhatsApp sticker ContentProvider contract. Column names and URI paths must
# remain readable so WhatsApp can query pack metadata and WebP assets.
-keep class com.stikk.stikk.StickerContentProvider { *; }
-keep class com.stikk.stikk.StickerPackStore { *; }
-keep class com.stikk.stikk.BuildConfig { *; }
-keepclassmembers class com.stikk.stikk.StickerContentProvider {
    public static final java.lang.String *;
}

# FFmpeg Kit
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# ML Kit selfie segmentation
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**

# Hive
-keep class hive.** { *; }
-dontwarn hive.**
