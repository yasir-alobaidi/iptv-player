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

// The TV's beta (ADR-034): `--dart-define=BIJOU_CHANNEL=beta` builds
// "Bijou Beta", its own app (id `….bijou.beta`, its own data and sign-in)
// installed beside the stable Bijou. Flutter hands dart defines to Gradle
// as `dart-defines`: each `KEY=value` base64-encoded, joined by commas.
// (`java.util.Base64` written out here would resolve `java` as Gradle's
// extension: hence the import.)
val betaChannel: Boolean =
    providers.gradleProperty("dart-defines").orNull.orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .any { it == "BIJOU_CHANNEL=beta" }

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
        applicationId =
            "io.github.yasiralobaidi.bijou" + if (betaChannel) ".beta" else ""
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = maxOf(flutter.versionCode, commitCount)
        versionName = flutter.versionName
        // About reads "Bijou 0.1.0-beta (build 245)" in the beta.
        versionNameSuffix = if (betaChannel) "-beta" else null
        manifestPlaceholders["appLabel"] = if (betaChannel) "Bijou Beta" else "Bijou"
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
