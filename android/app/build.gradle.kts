import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFileCandidates = listOf(
    rootProject.file("key.properties"),
    rootProject.file("android/key.properties")
)
val keystorePropertiesFile = keystorePropertiesFileCandidates.firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    val rawBytes = Files.readAllBytes(keystorePropertiesFile.toPath())
    val utf8Text = String(rawBytes, StandardCharsets.UTF_8)
    val text = if (utf8Text.contains('\u0000')) {
        String(rawBytes, StandardCharsets.UTF_16LE)
    } else {
        utf8Text
    }

    text.lineSequence()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") }
        .forEach { line ->
            val splitIndex = line.indexOf('=')
            if (splitIndex > 0) {
                val key = line.substring(0, splitIndex).trim()
                val value = line.substring(splitIndex + 1).trim()
                keystoreProperties.setProperty(key, value)
            }
        }
}

fun keystoreProp(name: String): String {
    val value = keystoreProperties.getProperty(name)
        ?: keystoreProperties.getProperty("\uFEFF$name")
    return value?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?: error("Missing '$name' in android/key.properties")
}

android {
    namespace = "com.example.study_assistant_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.study_assistant_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProp("keyAlias")
            keyPassword = keystoreProp("keyPassword")
            storeFile = file(keystoreProp("storeFile"))
            storePassword = keystoreProp("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
