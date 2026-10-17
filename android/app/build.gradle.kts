import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google TV's home keeps an app's icon from its first install until the
// version code changes (ADR-028), and pubspec's build number never did:
// the code is the commit count, so every update is a new version. A
// larger --build-number still wins; with no history (CI's shallow
// checkout) it is pubspec's.
val commitCount: Int =
    runCatching {
        providers.exec { commandLine("git", "rev-list", "--count", "HEAD") }
            .standardOutput.asText.get().trim().toInt()
    }.getOrDefault(0)

// The TV video-layer trial (docs/plans/tv-video-layer-t0.md): true only when
// the build passes `--dart-define=BIJOU_VIDEO_LAYER=true`. Flutter hands its
// dart defines to Gradle as the `dart-defines` property: each `KEY=value`
// UTF-8, base64-encoded, the entries joined by commas. Release builds never
// pass it, so MainActivity stays as it is.
val videoLayer: Boolean =
    providers.gradleProperty("dart-defines").orNull.orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .any { it == "BIJOU_VIDEO_LAYER=true" }

android {
    // The Google TV app's own id (docs/07, ADR-020): the desktop's
    // `io.github.yasiralobaidi.iptvplayer` keeps its first name only
    // because data is saved under it; nothing is saved under this one yet.
    namespace = "io.github.yasiralobaidi.bijou"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "io.github.yasiralobaidi.bijou"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = maxOf(flutter.versionCode, commitCount)
        versionName = flutter.versionName
        buildConfigField("boolean", "VIDEO_LAYER", videoLayer.toString())
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            // Sideloaded for personal use (docs/07): the debug key until
            // TV-5's packaging gives the app a key of its own.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
