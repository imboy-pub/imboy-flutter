import com.android.build.gradle.internal.cxx.configure.gradleLocalProperties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
val localProperties = gradleLocalProperties(rootDir, providers)
val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
val localNdkVersion = localProperties.getProperty("flutter.ndkVersion") ?: "27.0.12077973"

// cat /Users/leeyi/dev/flutter/bin/internal/engine.version
//val flutterEngineVersion = "18818009497c581ede5d8a3b8b833b81d00cebb7"

android {
    namespace = "pub.imboy.apk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = localNdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "pub.imboy.apk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        minSdkVersion(24)

        // 添加多Dex支持
        multiDexEnabled = true
        resourceConfigurations += listOf("en", "zh-rCN")
        // Manifest 占位符
        manifestPlaceholders.putAll(
            mutableMapOf(
                "JPUSH_PKGNAME" to "pub.imboy.apk",
                "JPUSH_CHANNEL" to "developer-default"
            ).apply {
                localProperties.getProperty("jpush.appKey")?.let {
                    this["JPUSH_APPKEY"] = it
                }
            }
        )
    }

    signingConfigs {
        create("release") {
            enableV1Signing = true
            enableV2Signing = true
            localProperties.getProperty("storeFile")?.let {
                storeFile = file(it)
            }
            keyAlias = localProperties.getProperty("keyAlias")
            keyPassword = localProperties.getProperty("keyPassword")
            storePassword = localProperties.getProperty("storePassword")
        }
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
            localProperties.getProperty("storeFile")?.let {
                storeFile = file(it)
            }
            keyAlias = localProperties.getProperty("keyAlias")
            keyPassword = localProperties.getProperty("keyPassword")
            storePassword = localProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            // signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.databinding:viewbinding:8.2.2")
    // bcprov-jdk15to18 是它的 Java 加密核心实现（Provider），主要为 JDK 1.5 到 JDK 18 提供兼容支持。
    implementation("org.bouncycastle:bcprov-jdk15to18:1.70")

    implementation("cn.jiguang.sdk:jverification:3.2.8")
//    implementation("com.amap.api:location:6.4.9")
//    implementation("com.amap.api:3dmap:10.0.600")// 使用较新版本的 3D 地图
//    implementation("com.amap.api:search:9.7.1")
}
