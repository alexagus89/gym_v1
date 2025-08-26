// android/app/build.gradle.kts  (nivel app)

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // El plugin de Flutter debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // Aplica Google Services aquí (sin versión)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.gym_v1"          // <-- que coincida con el que registraste en Firebase
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Usa Java 17 (recomendado con Flutter/Dart modernos)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.gym_v1"  // <-- MISMO package que en Firebase
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Para poder hacer run --release sin firmar aún
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // BoM: alinea versiones de todos los SDK de Firebase
    implementation(platform("com.google.firebase:firebase-bom:34.1.0"))

    // SDKs Firebase que usarás (puedes añadir/quitar)
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}
