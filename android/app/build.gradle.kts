plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase (FCM): butuh android/app/google-services.json buat jalan.
    // Di-nonaktifin dulu sampai file itu tersedia -- uncomment baris di
    // bawah kalau google-services.json sudah ditaruh di android/app/.
    // id("com.google.gms.google-services")
}

// if (file("google-services.json").exists()) {
//     apply(plugin = "com.google.gms.google-services")
// }

android {
    namespace = "com.wave.up.pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Wajib buat flutter_local_notifications (butuh Java 8+ API di
        // Android lama, mis. java.time). Tanpa ini build gagal di
        // :app:checkDebugAarMetadata.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wave.up.pos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk 23 dibutuhkan oleh firebase_messaging versi terbaru.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Diperlukan karena isCoreLibraryDesugaringEnabled = true di atas
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
