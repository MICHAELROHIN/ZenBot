plugins {
    id("com.android.application") // Android application plugin
    id("org.jetbrains.kotlin.android") // Corrected from 'kotlin-android' to proper plugin ID
    id("com.google.gms.google-services") // Google Services plugin
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.zen_bot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Use a single ndkVersion declaration, overriding Flutter's default

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.zen_bot"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Using debug keys for now
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0")) // Firebase BOM
    implementation("com.google.firebase:firebase-analytics") // Example Firebase dependency
    implementation("com.google.firebase:firebase-auth") // Add if using authentication
    // Add other Firebase dependencies as needed
}

flutter {
    source = "../.."
}