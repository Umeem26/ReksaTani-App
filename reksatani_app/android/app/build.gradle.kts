import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kredensial rilis ada di android/key.properties, yang tidak masuk git. Isinya:
// storePassword, keyPassword, keyAlias, dan storeFile (relatif terhadap android/app).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val adaKunciRilis = keystorePropertiesFile.exists()
if (adaKunciRilis) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.reksatani.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.reksatani.app"
        minSdkVersion(24)
        targetSdkVersion(flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (adaKunciRilis) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Jatuh ke kunci debug HANYA bila android/key.properties tidak ada, supaya
            // `flutter run --release` tetap jalan. APK bertanda tangan debug bukan
            // untuk dibagikan: kuncinya tidak rahasia dan berbeda di tiap mesin.
            signingConfig = signingConfigs.getByName(if (adaKunciRilis) "release" else "debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
