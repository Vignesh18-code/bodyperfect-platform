import java.util.Properties
import java.util.Base64
import java.net.URI
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseKeystore = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { (keystoreProperties[it] as String?)?.isNotBlank() == true }


android {
    namespace = "com.bodyperfect.clinicapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "com.bodyperfect.clinicapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                val storeFilePath = keystoreProperties["storeFile"] as String
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// Never silently ship a debug-signed release to Play.
val verifyReleaseConfiguration = tasks.register("verifyReleaseConfiguration") {
    doLast {
        check(hasReleaseKeystore) {
            "Release signing required: configure android/key.properties with your upload keystore. Use a debug build for local testing."
        }
        val defines = (project.findProperty("dart-defines") as? String).orEmpty()
            .split(",").filter { it.isNotBlank() }.map {
                String(Base64.getDecoder().decode(it), Charsets.UTF_8)
            }
        val endpoint = defines.lastOrNull { it.startsWith("API_BASE_URL=") }
            ?.substringAfter("=")
        val uri = endpoint?.let { URI(it) }
        check(uri != null && uri.scheme == "https" && !uri.host.isNullOrBlank()
            && uri.host != "localhost" && uri.host != "127.0.0.1"
            && uri.host != "example.com" && !uri.host.endsWith(".example.com")) {
            "Release requires --dart-define=API_BASE_URL=https://YOUR_LIVE_API_HOST (no local or example endpoint)."
        }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(verifyReleaseConfiguration)
}
