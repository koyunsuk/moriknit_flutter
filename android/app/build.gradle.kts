plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.moriknit.moriknit_flutter"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 기본 applicationId — flavor 미지정 시 사용자 앱으로 동작
        applicationId = "com.moriknit.moriknit_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appAuthRedirectScheme"] = "com.moriknit.app"
        // 이슈 #815 — flavor 없이 빌드 시 user flavor로 자동 fallback
        // 기존 'flutter build apk --debug' 명령어 호환성 보장 (Codemagic 등)
        missingDimensionStrategy("app", "user")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // 이슈 #815 — 사용자 앱과 어드민 앱을 별도 APK로 분리하기 위한 flavors
    flavorDimensions += "app"
    productFlavors {
        create("user") {
            dimension = "app"
            // 기본 applicationId 그대로 사용 (사용자 앱)
            resValue("string", "app_name", "MoriKnit")
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.moriknit.admin_mobile"
            resValue("string", "app_name", "모리니트 어드민")
            manifestPlaceholders["appAuthRedirectScheme"] = "com.moriknit.admin_mobile"
        }
        create("seller") {
            dimension = "app"
            applicationId = "com.moriknit.android.seller"
            resValue("string", "app_name", "모리니트 셀러")
            manifestPlaceholders["appAuthRedirectScheme"] = "com.moriknit.android.seller"
        }
    }
}

flutter {
    source = "../.."
}
