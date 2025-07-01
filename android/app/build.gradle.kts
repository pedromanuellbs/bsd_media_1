plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin untuk Firebase
    id("com.google.gms.google-services")
}

android {
    namespace   = "com.bsdmedia.dbmedia"
    compileSdk  = flutter.compileSdkVersion   // biasanya 33
    ndkVersion  = "27.0.12077973"             // pakai NDK 27

    defaultConfig {
        applicationId = "com.bsdmedia.dbmedia"
        minSdk        = 23                    // ≥ 23 untuk Firebase Auth
        targetSdk     = flutter.targetSdkVersion
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            // kalau belum punya signingConfig release, gunakan debug sementara
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
