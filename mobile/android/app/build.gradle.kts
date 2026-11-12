plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// the Peera signing key comes from the environment (the build's secrets) when it is there: PEERA_KS (the file), PEERA_KS_PASS
val peeraKs: String? = System.getenv("PEERA_KS")

android {
    namespace = "my.peera.peera"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // the test version sits beside the installed Peera app; after phase 1 it becomes my.peera.app and replaces it as an update
        applicationId = "my.peera.app.dev"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase (push notifications) needs Android 7 or newer
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Android's lint check of release builds crashes on one of the plugins (a lint bug); the app's own checks run in `flutter analyze`
    lint {
        checkReleaseBuilds = false
    }

    signingConfigs {
        if (peeraKs != null) {
            create("peera") {
                storeFile = file(peeraKs)
                storePassword = System.getenv("PEERA_KS_PASS")
                keyAlias = "peera"
                keyPassword = System.getenv("PEERA_KS_PASS")
            }
        }
    }

    buildTypes {
        release {
            // without the key the build is signed with a throwaway one; it is then signed again with the Peera key
            signingConfig = if (peeraKs != null) signingConfigs.getByName("peera") else signingConfigs.getByName("debug")
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
    // the same Firebase the plugins use (firebase_core 5.1: BoM 35.1.0), so MainActivity can ask it directly
    // why a phone could not register for notifications
    implementation(platform("com.google.firebase:firebase-bom:35.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-installations")
}
