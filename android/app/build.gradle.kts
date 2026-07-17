plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.noi.noi_ohada_invoice_pro"
    // compileSdk = 35 // Optionnel mais recommandé en 2026 pour cibler les API récentes
    compileSdkVersion 36

    defaultConfig {
        applicationId = "com.noi.noi_ohada_invoice_pro"
        // Récupère automatiquement la version minimale requise par Flutter
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
    }

kotlinOptions {
    jvmTarget = "17"
}
    buildTypes {
        release {
            // Note : Pensez à remplacer par une vraie clé de production (.jks) avant de publier sur le Play Store !
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}