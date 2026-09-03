import java.util.Properties

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

// ============================================================
// 🔐 SIGNATURE RELEASE
// ------------------------------------------------------------
// CodeMagic génère `android/app/upload-keystore.jks` et écrit les mots de
// passe dans `android/local.properties` :
//   release.keystore.password / release.key.alias / release.key.password
//
// Si le keystore est absent (build local), on retombe sur la signature DEBUG
// (suffisant pour tester, PAS pour publier sur le Play Store). Pour publier,
// laisser CodeMagic fournir le keystore via KEYSTORE_BASE64.
// ============================================================
val keystoreProperties = Properties()
val keystorePropsFile = rootProject.file("local.properties")
if (keystorePropsFile.exists()) {
    keystorePropsFile.inputStream().use { keystoreProperties.load(it) }
}

fun keystoreProp(key: String, envName: String? = null): String? {
    keystoreProperties.getProperty(key)?.takeIf { it.isNotBlank() }?.let { return it }
    return envName?.let { System.getenv(it) }?.takeIf { it.isNotBlank() }
}

val releaseStoreFile = file(
    keystoreProp("release.keystore.storeFile", "RELEASE_STORE_FILE")
        ?: keystoreProp("UPLOAD_STORE_FILE", "UPLOAD_STORE_FILE")
        ?: "upload-keystore.jks"
)
val ksStorePassword = keystoreProp("release.keystore.password", "KEYSTORE_PASSWORD")
val ksKeyAlias = keystoreProp("release.key.alias", "KEY_ALIAS")
val ksKeyPassword = keystoreProp("release.key.password", "KEY_PASSWORD")
val hasReleaseKeystore =
    releaseStoreFile.exists() &&
        ksStorePassword != null && ksKeyAlias != null && ksKeyPassword != null

android {
    namespace = "com.noi.noi_ohada_invoice_pro"
    compileSdk = 36

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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = ksStorePassword
                keyAlias = ksKeyAlias
                keyPassword = ksKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Keystore release si présent (build CodeMagic), sinon debug (local).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
            "androidx.navigation:navigation-ui-ktx:2.8.4",
            "androidx.browser:browser:1.8.0"
        )
    }
}

flutter {
    source = "../.."
}
