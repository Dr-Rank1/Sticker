import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream ->
        keystoreProperties.load(stream)
    }
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? {
    return keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environmentName)?.takeIf { it.isNotBlank() }
}

val releaseKeyAlias = releaseSigningValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "ANDROID_KEY_PASSWORD")
val releaseStorePassword = releaseSigningValue("storePassword", "ANDROID_STORE_PASSWORD")
val releaseStorePath = releaseSigningValue("storeFile", "ANDROID_STORE_FILE")
val releaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.substringAfterLast(':').contains("release", ignoreCase = true)
}

if (releaseBuildRequested) {
    val missingValues = listOfNotNull(
        "keyAlias / ANDROID_KEY_ALIAS".takeIf { releaseKeyAlias == null },
        "keyPassword / ANDROID_KEY_PASSWORD".takeIf { releaseKeyPassword == null },
        "storePassword / ANDROID_STORE_PASSWORD".takeIf { releaseStorePassword == null },
        "storeFile / ANDROID_STORE_FILE".takeIf { releaseStorePath == null },
    )
    if (missingValues.isNotEmpty()) {
        throw GradleException(
            "Release signing is not configured. Provide android/key.properties " +
                "or all Android signing environment variables. Missing: " +
                missingValues.joinToString(),
        )
    }
    val releaseStoreFile = file(requireNotNull(releaseStorePath))
    if (!releaseStoreFile.isFile) {
        throw GradleException(
            "Release signing keystore does not exist: ${releaseStoreFile.absolutePath}",
        )
    }
}

android {
    namespace = "com.stickr.stickr"
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        val appId = "com.stickr.stickr"
        applicationId = appId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during the build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val contentProviderAuthority = "$appId.stickercontentprovider"
        buildConfigField(
            "String",
            "CONTENT_PROVIDER_AUTHORITY",
            "\"$contentProviderAuthority\"",
        )
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
            storePassword = releaseStorePassword
            storeFile = releaseStorePath?.let(::file)
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            firebaseCrashlytics {
                mappingFileUploadEnabled = true
                nativeSymbolUploadEnabled = true
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.activity:activity-ktx:1.10.1")
}
