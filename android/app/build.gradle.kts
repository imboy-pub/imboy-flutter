import com.android.build.gradle.internal.cxx.configure.gradleLocalProperties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin for Firebase
    id("com.google.gms.google-services")
}
val localProperties = gradleLocalProperties(rootDir, providers)
val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
val localNdkVersion = localProperties.getProperty("flutter.ndkVersion") ?: "28.2.13676358"

// cat /Users/leeyi/dev/flutter/bin/internal/engine.version
//val flutterEngineVersion = "18818009497c581ede5d8a3b8b833b81d00cebb7"

android {
    namespace = "imboy.chat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = localNdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "imboy.chat"
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
                "JPUSH_PKGNAME" to "imboy.chat",
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
            // 使用默认的调试签名配置
            // Flutter 会自动处理调试签名
        }
    }

    // 解决高德地图 SDK 重复类问题
    packaging {
        jniLibs {
            pickFirsts.add("**/lib*.so")
        }
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            pickFirsts.add("META-INF/*")
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false  // Debug 构建不进行代码压缩
            // Debug 模式下也使用 ProGuard 规则，防止 NoClassDefFoundError
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true  // 启用代码压缩和优化
            isShrinkResources = true  // 启用资源压缩
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
    }
}

// 确保 Kotlin 编译在 Java 之前完成
afterEvaluate {
    tasks.named("compileDebugJavaWithJavac") {
        dependsOn("compileDebugKotlin")
    }
    tasks.named("compileReleaseJavaWithJavac") {
        dependsOn("compileReleaseKotlin")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.databinding:viewbinding:8.2.2")
    // bcprov-jdk15to18 是它的 Java 加密核心实现（Provider），主要为 JDK 1.5 到 JDK 18 提供兼容支持。
    implementation("org.bouncycastle:bcprov-jdk15to18:1.70")

    implementation("cn.jiguang.sdk:jverification:3.2.8")

    // 高德地图 SDK - 使用 api 确保 Flutter 插件可以访问
    // 注意：3dmap 已包含 location 和 search 功能，无需单独添加 location SDK
    // 3dmap:10.0.600 包含: 地图显示、定位、地理围栏、坐标转换等核心功能
    api("com.amap.api:3dmap:10.0.600")  // 高德3D地图 SDK（包含 location 功能）

    // 以下依赖已注释，因为 3dmap 已包含这些功能
    // api("com.amap.api:location:6.4.9")  // 重复类：与 3dmap 冲突
    // api("com.amap.api:search:9.7.1")     // 重复类：与 3dmap 冲突

    // 移除了 navi-3dmap 依赖（与 3dmap 有重复类冲突）
//    implementation("com.amap.api:navi-3dmap:10.0.600_3dmap10.0.600")
//    implementation("com.amap.api:map2d:9.7.0")    // 2D地图（可选）
}
