import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release signing --------------------------------------------------------
// Reads android/key.properties (see RELEASE_GUIDE.md). Without it, release
// builds are signed with the debug key so they still run on a test phone.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// --- AdMob app ID -----------------------------------------------------------
// Taken from lib/config/ads_config.dart so all ad IDs live in ONE file.
val adsConfigText = rootProject.file("../lib/config/ads_config.dart").readText()
fun dartString(name: String): String =
    Regex(name + """\s*=\s*'([^']*)'""").find(adsConfigText)?.groupValues?.get(1)
        ?: throw GradleException("$name not found in lib/config/ads_config.dart")
val useTestAds = Regex("""useTestAds\s*=\s*(true|false)""").find(adsConfigText)?.groupValues?.get(1) != "false"
val admobAppId = if (useTestAds) dartString("testAppId") else dartString("realAppId")
if (admobAppId.contains("XXXX")) {
    throw GradleException(
        "Put your real AdMob app ID into lib/config/ads_config.dart (realAppId), or set useTestAds = true."
    )
}

android {
    namespace = "com.toffetwist.toffeetwist"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Your unique app ID on Google Play. It can never change after the first upload.
        applicationId = "com.toffetwist.toffeetwist"
        // Android 7.0+. (The latest Google Mobile Ads plugin needs at least 24.)
        minSdk = 24
        // The API level Google Play currently requires for new apps and updates.
        targetSdk = 36
        // Taken from "version:" in pubspec.yaml (e.g. 1.0.0+1 -> name 1.0.0, code 1).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
