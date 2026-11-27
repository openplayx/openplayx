plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.openplayx.openplayx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.openplayx.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // vlc_player 2.1.2 要求 Android API 29（Android 10）及以上，高于 Flutter 默认的 24。
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Package native libraries (VLC, Go core, ...) only for the ABIs Flutter builds for.
    // Without this a `--target-platform android-arm,android-arm64` APK still carries
    // x86_64 copies of plugin libraries that can never load without libflutter.so.
    // (abiFilters cannot be used: the Flutter Gradle plugin resets them later.)
    val flutterTargetPlatforms = project.findProperty("target-platform") as String?
    if (flutterTargetPlatforms != null && project.findProperty("split-per-abi") != "true") {
        val abiByPlatform = mapOf(
            "android-arm" to "armeabi-v7a",
            "android-arm64" to "arm64-v8a",
            "android-x64" to "x86_64",
            "android-x86" to "x86",
        )
        val wanted = flutterTargetPlatforms.split(",").mapNotNull { abiByPlatform[it.trim()] }.toSet()
        if (wanted.isNotEmpty()) {
            for (abi in abiByPlatform.values - wanted) packaging.jniLibs.excludes += "lib/$abi/**"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
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

// Bundle the Go core into this app; no separate proxy/VPN application is needed.
android.sourceSets.getByName("main").jniLibs.srcDir("../../native/remote_access/build/android")
val buildRemoteCore by tasks.registering(Exec::class) {
    workingDir = file("../../native/remote_access")
    environment("ANDROID_NDK_HOME", android.ndkDirectory.absolutePath)
    commandLine("bash", "build_android.sh")
    inputs.files(fileTree("../../native/remote_access") {
        include("*.go", "go.mod", "go.sum", "build_android.sh")
    })
    outputs.dir(file("../../native/remote_access/build/android"))
}
tasks.named("preBuild") { dependsOn(buildRemoteCore) }
