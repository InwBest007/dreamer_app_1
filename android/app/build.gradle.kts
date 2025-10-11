plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") //version "4.4.3" apply false
}

android {
    ndkVersion = "27.0.12077973"
    namespace = "com.example.project_dreamer_app"
    compileSdk = 36 //flutter.compileSdkVersion เริ่มที่ 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.project_dreamer_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdkVersion(24)// ตั้งค่า minSDKVersion ให้เป็น 23 เพื่อรองรับ record package
        targetSdk = flutter.targetSdkVersion
        versionCode = 1 // flutter.versionCode
        versionName = "1.0" // flutter.versionName
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
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    implementation("com.google.firebase:firebase-firestore")
    // TODO: Add the dependencies for Firebase products you want to use
    // When using the BoM, don't specify versions in Firebase dependencies
    // https://firebase.google.com/docs/android/setup#available-libraries
}
// plugins {
//     id("com.android.application")
//     id("kotlin-android")
//     id("dev.flutter.flutter-gradle-plugin")
//     id("com.google.gms.google-services") // เพิ่มบรรทัดนี้
// }

// android {
//     ndkVersion = "27.0.12077973"
//     namespace = "com.example.project_dreamer_app"
//     compileSdk = 36 //flutter.compileSdkVersion เริ่มที่ 35

//     compileOptions {
//         sourceCompatibility = JavaVersion.VERSION_17
//         targetCompatibility = JavaVersion.VERSION_17
//     }

//     kotlinOptions {
//         jvmTarget = "17"
//     }

//     defaultConfig {
//         // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
//         applicationId = "com.example.project_dreamer_app"
//         // You can update the following values to match your application needs.
//         // For more information, see: https://flutter.dev/to/review-gradle-config.
//         minSdkVersion(24)// ตั้งค่า minSDKVersion ให้เป็น 23 เพื่อรองรับ record package
//         targetSdk = flutter.targetSdkVersion
//         versionCode = 1 // flutter.versionCode
//         versionName = "1.0" // flutter.versionName
//     }

//     buildTypes {
//         release {
//             // TODO: Add your own signing config for the release build.
//             // Signing with the debug keys for now, so `flutter run --release` works.
//             signingConfig = signingConfigs.getByName("debug")
//         }
//     }
// }

// flutter {
//     source = "../.."
// }

// dependencies {
//     // Import the Firebase BoM
//     implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
//     implementation("com.google.firebase:firebase-firestore")
//     // TODO: Add the dependencies for Firebase products you want to use
//     // When using the BoM, don't specify versions in Firebase dependencies
//     // https://firebase.google.com/docs/android/setup#available-libraries
// }