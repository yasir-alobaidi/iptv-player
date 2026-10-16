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
