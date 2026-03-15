plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing: Codemagic sets CM_KEYSTORE_PATH, CM_KEYSTORE_PASSWORD, CM_KEY_ALIAS, CM_KEY_PASSWORD.
val storePath = System.getenv("CM_KEYSTORE_PATH")
val storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
val keyAliasEnv = System.getenv("CM_KEY_ALIAS")
val keyPasswordEnv = System.getenv("CM_KEY_PASSWORD")
val keystoreFile = storePath?.let { path -> file(path) }
val hasReleaseSigning = keystoreFile != null && keystoreFile.isFile &&
    !storePassword.isNullOrBlank() && !keyAliasEnv.isNullOrBlank() && !keyPasswordEnv.isNullOrBlank()

android {
    namespace = "com.pixap.pixap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        if (hasReleaseSigning && keystoreFile != null) {
            create("release") {
                storeFile = keystoreFile
                storePassword = storePassword!!
                keyAlias = keyAliasEnv!!
                keyPassword = keyPasswordEnv!!
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pixap.pixap"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
