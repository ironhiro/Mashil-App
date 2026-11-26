import java.net.URI
import java.util.Base64
import java.util.Properties

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
    namespace = "dev.ironhiro.mashil"
    // permission_handler_android 가 compileSdk 37 이상을 요구
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.ironhiro.mashil"
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
        // AdMob 앱 ID. SDK 가 시작할 때 꼭 있어야 해서(없으면 앱이 죽음) 비우면 Google 의 테스트 앱 ID.
        // 실제 ID 는 프로덕션 env 의 ADMOB_APP_ID_ANDROID 에만 (비공개 테스트는 테스트 ID 로, MON-01)
        manifestPlaceholders["admobAppId"] = dartDefines["ADMOB_APP_ID_ANDROID"]?.takeIf { it.isNotBlank() }
            ?: "ca-app-pub-3940256099942544~3347511713"
        // 공유 링크(App Links)를 받을 호스트 = 웹 주소의 호스트 (staging: toilets-dev, prod: toilets).
        // 서버가 /.well-known/assetlinks.json 으로 이 앱의 서명 인증서를 밝혀야 확인된다 (백엔드 docs/APP-LINKS.md)
        manifestPlaceholders["appLinkHost"] =
            runCatching { URI(dartDefines["WEB_BASE_URL"] ?: "").host }.getOrNull() ?: "toilets.ironhiro.dev"
    }

    // 업로드 키 (Play 콘솔에 올리는 AAB 서명). android/key.properties 에서 읽는다 (저장소에 넣지 않음, .gitignore).
    // key.properties 가 없으면 디버그 키로 서명해 `flutter run --release` 는 되지만, 그 AAB 는 Play 에 올릴 수 없다.
    //   storeFile=<업로드 키스토어 경로>   storePassword=…   keyAlias=upload   keyPassword=…
    val keyProps = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    signingConfigs {
        if (keyProps.getProperty("storeFile") != null) {
            create("upload") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
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
