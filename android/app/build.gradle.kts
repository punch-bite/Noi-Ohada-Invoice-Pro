plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    // ✅ Use a valid version – 2.1.4 exists and works
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation("androidx.navigation:navigation-fragment-ktx:2.8.4")
    implementation("androidx.navigation:navigation-ui-ktx:2.8.4")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("androidx.multidex:multidex:2.0.1")
}

android {
    namespace = "com.noi.noi_ohada_invoice_pro"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.noi.noi_ohada_invoice_pro"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
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

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ⚠️ Forcer des versions AndroidX compatibles avec AGP 8.7.3.
// Les dépendances transitives récentes (activity 1.12.x, core 1.18.x)
// exigent AGP >= 8.9.1 ; on les épingle donc à des versions compatibles.
configurations.configureEach {
    resolutionStrategy {
        force(
            "androidx.core:core:1.13.1",
            "androidx.core:core-ktx:1.13.1",
            "androidx.activity:activity:1.9.3",
            "androidx.activity:activity-ktx:1.9.3",
            "androidx.lifecycle:lifecycle-runtime:2.8.7",
            "androidx.lifecycle:lifecycle-runtime-ktx:2.8.7",
            "androidx.lifecycle:lifecycle-viewmodel:2.8.7",
            "androidx.navigation:navigation-common:2.8.4",
            "androidx.navigation:navigation-common-ktx:2.8.4",
            "androidx.navigation:navigation-runtime:2.8.4",
            "androidx.navigation:navigation-runtime-ktx:2.8.4",
            "androidx.navigation:navigation-fragment:2.8.4",
            "androidx.navigation:navigation-fragment-ktx:2.8.4",
            "androidx.navigation:navigation-ui:2.8.4",
            "androidx.navigation:navigation-ui-ktx:2.8.4"
        )
    }
}

flutter {
    source = "../.."
}
