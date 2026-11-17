import java.net.URI
import java.util.Base64

// flutter run/build --dart-define-from-file=env/dev.json 의 값은 Gradle 에 "dart-defines" (base64, 쉼표 구분) 로 들어온다
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull() }
    ?.filter { it.contains("=") }
    ?.associate { it.substringBefore("=") to it.substringAfter("=") }
    ?: emptyMap()

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "kr.mashil.mashil"
    // permission_handler_android 가 compileSdk 37 이상을 요구
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.mashil.mashil"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 카카오 로그인 리다이렉트 스킴 kakao{네이티브 앱 키}
        manifestPlaceholders["kakaoNativeAppKey"] = dartDefines["KAKAO_NATIVE_APP_KEY"] ?: "MISSING_KAKAO_KEY"
        // 공유 링크(App Links)를 받을 호스트 = 웹 주소의 호스트 (staging: toilets-dev, prod: toilets).
        // 서버가 /.well-known/assetlinks.json 으로 이 앱의 서명 인증서를 밝혀야 확인된다 (백엔드 docs/APP-LINKS.md)
        manifestPlaceholders["appLinkHost"] =
            runCatching { URI(dartDefines["WEB_BASE_URL"] ?: "").host }.getOrNull() ?: "toilets.ironhiro.dev"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
