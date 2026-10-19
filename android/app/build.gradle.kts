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

// The build's dart defines. Flutter hands them to Gradle as `dart-defines`:
// each `KEY=value` base64-encoded, joined by commas. (`java.util.Base64`
// written out here would resolve `java` as Gradle's extension: hence the
// import.)
val dartDefines: Map<String, String> =
    providers.gradleProperty("dart-defines").orNull.orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .mapNotNull { entry ->
            entry.split("=", limit = 2).takeIf { it.size == 2 }?.let { it[0] to it[1] }
        }
        .toMap()

// The TV's beta (ADR-034): `--dart-define=BIJOU_CHANNEL=beta` builds
// "Bijou Beta", its own app (id `….bijou.beta`, its own data and sign-in)
// installed beside the stable Bijou.
val betaChannel: Boolean = dartDefines["BIJOU_CHANNEL"] == "beta"

// The picture's own layer (T1, ADR-035 §1): in every build since the
// Bedroom TV's go; `--dart-define=BIJOU_VIDEO_LAYER=off` builds the texture
// instead, `=clear` the layer with no window background. Dart reads the same.
val videoLayer: String = dartDefines["BIJOU_VIDEO_LAYER"].orEmpty()

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
        // The cover with a BETA pill, so the two apps' circles differ on
        // the TV (tools/brand/make_icons.py, ADR-041).
        val icons = if (betaChannel) "ic_launcher_beta" else "ic_launcher"
        manifestPlaceholders["appIcon"] = "@mipmap/$icons"
        manifestPlaceholders["appRoundIcon"] = "@mipmap/${icons}_round"
        manifestPlaceholders["appBanner"] = if (betaChannel) "@drawable/banner_beta" else "@drawable/banner"
        buildConfigField(
            "boolean",
            "VIDEO_LAYER",
            (videoLayer != "off").toString(),
        )
        buildConfigField("boolean", "VIDEO_LAYER_CLEAR_WINDOW", (videoLayer == "clear").toString())
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
