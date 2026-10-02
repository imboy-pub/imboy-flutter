import com.android.build.gradle.internal.cxx.configure.gradleLocalProperties
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 仅在实际有 Firebase 配置时应用插件；CI 未配置 secret 时仍可构建可验证的 APK。
if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}
val localProperties = gradleLocalProperties(rootDir, providers)
val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
val localNdkVersion = localProperties.getProperty("flutter.ndkVersion") ?: "28.2.13676358"
val productFeatures = Properties().apply {
    file("product-features.properties").inputStream().use { load(it) }
}
val locationCompiled = productFeatures.getProperty("location") == "true"

// ── 白标 flavor 配方（EPGZ-06 W4；计划 §7.3 白标 + §7.4 JPush）──────────────
// 客户品牌值一律**不入库**：本地/CI 从 android/local.properties（已 gitignore，
// 见 android/.gitignore:6 / 本工程 git check-ignore 实测）读取 wl.* 与
// jpush.appKey；缺值回落到与 base 逐值等价的占位（IMBoy / 既有图标 / 既有主色），
// 绝不编造客户品牌名、图标、资质或密钥。非 ASCII 显示名请写 \uXXXX
// （java.util.Properties 按 ISO-8859-1 读取 local.properties）。
//
// Dart 侧同一份配方的键名合同见
// lib/modules/enterprise_oa/enterprise_oa_runtime_config.dart（经 --dart-define 下发）：
//   flutter build apk --debug --flavor gzCustomer \
//     --dart-define=IMBOY_WL_FLAVOR=gzCustomer \
//     --dart-define=IMBOY_WL_APPLICATION_ID=<客户 applicationId> \
//     --dart-define=IMBOY_WL_DISPLAY_NAME=<显示名> \
//     --dart-define=IMBOY_WL_PRIMARY_COLOR=<#RRGGBB> \
//     --dart-define=IMBOY_WL_OA_LABEL=<OA Tab 名> \
//     --dart-define=IMBOY_WL_OA_ORIGIN=<https://oa.example.com> \
//     --dart-define=IMBOY_WL_OA_ENTRY_ENABLED=true \
//     --dart-define=IMBOY_WL_OA_APPLICATION_KEY=<OA 应用标识 8..128> \
//     --dart-define=IMBOY_WL_OA_REDIRECT_URI=<与 origin 同源的 redirect>
//   （OA 四项未注入时 fail-closed：入口不出现，见 runtime_config 文档）
//
// ⚠️ 副作用的代价（有意为之）：本工程一旦有 productFlavor，Android 构建从此
//    **必须显式带 --flavor**——standard = 原 imboy 基线（applicationId 不变），
//    gzCustomer = 广州客户白标。仓内 5 处调用点已同步补 --flavor standard。
// ⚠️ 启动图/图标资产未提供（BLOCKED_EXTERNAL）时沿用 base 资产；客户资产落点：
//    flavor 级 res 覆盖 main 的 flutter_native_splash 产物——
//    android/app/src/gzCustomer/res/drawable/launch_background.xml（含 drawable-v21）
//    覆盖启动图；android/app/src/gzCustomer/res/mipmap-*/wl_ic_launcher.png +
//    local.properties 里 wl.icon=@mipmap/wl_ic_launcher 覆盖图标。
val baseApplicationId = "pub.imboy.app"
val wlFlavorId = "gzCustomer"
val wlApplicationIdSuffix =
    localProperties.getProperty("wl.applicationIdSuffix") ?: ".gzcustomer"
val wlDisplayName =
    localProperties.getProperty("wl.displayName")?.takeIf { it.isNotBlank() } ?: "IMBoy"
val wlAppIcon = localProperties.getProperty("wl.icon") ?: "@mipmap/ic_launcher"
val wlPrimaryColor = localProperties.getProperty("wl.primaryColor") ?: "#2474E5"
val jpushAppKeyInjected = !localProperties.getProperty("jpush.appKey").isNullOrEmpty()
// 构建期自证（只报**有无**，绝不回显密钥值）：CI 日志可直接判读推送是否具备真机条件。
logger.lifecycle(
    "白标配方: flavor=$wlFlavorId appId=$baseApplicationId$wlApplicationIdSuffix " +
        "label=$wlDisplayName icon=$wlAppIcon " +
        "JPush AppKey=${if (jpushAppKeyInjected) "已注入(local.properties)" else "未注入(空占位,真机推送不可用)"}"
)

// cat /Users/leeyi/dev/flutter/bin/internal/engine.version
//val flutterEngineVersion = "18818009497c581ede5d8a3b8b833b81d00cebb7"

android {
    namespace = "pub.imboy.app"
    // permission_handler_android 14.x requires API 37; keep this explicit so
    // the release build does not silently fall back to Flutter's older default.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
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
        // 三端统一应用标识（Android/iOS/macOS）：pub.imboy.app
        // 白标 flavor 在此值上追加 applicationIdSuffix（见 productFlavors）。
        applicationId = baseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        minSdkVersion(24)

        // Patrol E2E：instrumentation runner + 测试间清数据（保证用例隔离）
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"

        // 添加多Dex支持
        multiDexEnabled = true
        resourceConfigurations += listOf("en", "zh-rCN")
        // Manifest 占位符
        manifestPlaceholders.putAll(
            mutableMapOf(
                "JPUSH_PKGNAME" to "pub.imboy.app",
                "JPUSH_CHANNEL" to "developer-default",
                // 未配置极光推送时仍须完成 Manifest 占位替换，社区/CI Release
                // 使用空值；真实应用密钥继续由 local.properties 覆盖。
                "JPUSH_APPKEY" to (localProperties.getProperty("jpush.appKey") ?: "")
            )
        )
    }

    // 白标 flavor（单一维度 brand，不 fork 工程结构）。
    //   standard   基线：与原 imboy 行为逐值等价（applicationId / 显示名 / 图标不变）
    //   gzCustomer 广州客户白标：值全部来自 local.properties，缺值走与 base 等价的占位
    flavorDimensions += "brand"
    productFlavors {
        create("standard") {
            dimension = "brand"
        }
        create(wlFlavorId) {
            dimension = "brand"
            applicationIdSuffix = wlApplicationIdSuffix
            // 显示名：resValue 落点（Android 惯例；客户也可用 flavor res 覆盖同名 string）
            resValue("string", "wl_app_name", wlDisplayName)
            // 主题色占位：客户主色的落点；未提供时 = 项目既有主色 (#2474E5)
            resValue("color", "wl_primary", wlPrimaryColor)
            manifestPlaceholders.putAll(
                mutableMapOf(
                    // 图标引用：默认沿用 base 图标，客户给图后指向 @mipmap/wl_ic_launcher
                    "WL_APP_ICON" to wlAppIcon,
                    // JPush 硬要求：JPUSH_PKGNAME 必须等于最终包名，故随后缀联动
                    "JPUSH_PKGNAME" to (baseApplicationId + wlApplicationIdSuffix)
                )
            )
        }
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

    // 解决高德地图 SDK 重复类问题，剔除 BouncyCastle 等依赖的签名文件防止 SecurityException
    packaging {
        jniLibs {
            pickFirsts.add("**/lib*.so")
        }
        resources {
            excludes += "META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/*.SF"
            excludes += "META-INF/*.DSA"
            excludes += "META-INF/*.RSA"
            excludes += "META-INF/*.EC"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
        }
    }

    // Patrol E2E：用 AndroidX Test Orchestrator 跑，每个 Dart 测试独立进程
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
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
            // JVerification 一键登录要求包签名与极光后台登记一致，不一致时
            // init 回调 code=8004（真机日志：1011 appSign or bundleId invalid）。
            // 因此有 release 签名配置时 debug 也用 release 签名；无配置（如
            // CI/新环境缺 local.properties 四件套）回落 Flutter 默认 debug 签名。
            signingConfig = if (localProperties.getProperty("storeFile") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

// 确保 Kotlin 编译在 Java 之前完成。
// 白标 flavor 引入后变体任务名带 flavor 前缀（compileStandardDebugJavaWithJavac /
// compileGzCustomerDebugJavaWithJavac …），原先写死的 compileDebugJavaWithJavac 在
// 配置期直接报 "Task with name 'compileDebugJavaWithJavac' not found"，因此改为按
// 实际存在的任务名动态解析：不写死变体，新增 flavor 自动覆盖。
afterEvaluate {
    tasks.matching { it.name.endsWith("JavaWithJavac") }.configureEach {
        val kotlinTask = name.removeSuffix("JavaWithJavac") + "Kotlin"
        tasks.findByName(kotlinTask)?.let { dependsOn(it) }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Patrol E2E：测试编排器（配合 testOptions.execution）
    androidTestUtil("androidx.test:orchestrator:1.5.1")

    // 显式抬高 androidx.test，否则 AGP 的 consistent resolution 会把 runner 对齐到
    // 传递依赖里的 1.2.0，而 PatrolJUnitRunner 覆写的 shouldWaitForActivitiesToComplete()
    // 在 1.2.0 中尚不存在 → :patrol:compileDebugJavaWithJavac 编译失败。
    androidTestImplementation("androidx.test:runner:1.5.2")
    androidTestImplementation("androidx.test:monitor:1.6.1")

    // flutter 3.47 tool 内部不一致 workaround：GeneratedPluginRegistrant 生成时
    // 注册全部插件（含 dev_dependencies 的 patrol / integration_test），但
    // gradle 注入侧（flutter_tools PluginHandler.kt）对 dev 插件「只在非 release
    // 注入依赖」→ release 编译报「程序包不存在」。显式补齐 release 依赖使
    // registrant 可解析；两插件在 release 运行时空转（无测试驱动接入），无副作用。
    // 从 dev_dependencies 移除 patrol / integration_test 时同步删除此处。
    releaseImplementation(project(":patrol"))
    releaseImplementation(project(":integration_test"))

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.databinding:viewbinding:8.2.2")
    // bcprov-jdk15to18 是它的 Java 加密核心实现（Provider），主要为 JDK 1.5 到 JDK 18 提供兼容支持。
    implementation("org.bouncycastle:bcprov-jdk15to18:1.70")

    implementation("cn.jiguang.sdk:jverification:3.2.8")

    // Flutter 会为 pubspec 中的 Android 插件生成全量注册表；即使 Base
    // 没有 location 功能，amap_flutter_location 的注册仍需它的运行时 SDK。
    // 3dmap:10.0.600 自身打包了 location 类，与独立 location SDK 同时在
    // classpath 会 checkDebugDuplicateClasses 重复类冲突，两者必须互斥。
    if (locationCompiled) {
        api("com.amap.api:3dmap:10.0.600")
    } else {
        api("com.amap.api:location:6.5.0")
    }

    // 移除了 navi-3dmap 依赖（与 3dmap 有重复类冲突）
//    implementation("com.amap.api:navi-3dmap:10.0.600_3dmap10.0.600")
//    implementation("com.amap.api:map2d:9.7.0")    // 2D地图（可选）
}

// ── Flutter CLI 无 --flavor 调用的产物名适配 ─────────────────────────
// flutter 工具在无 --flavor 时按 app-<abi>-<mode>.apk（无 flavor 段）定位产物
// （flutter_tools gradle.dart listApkPaths），而 AGP 变体产物名恒带
// flavor 段（app-standard-<abi>-debug.apk）→ assembleDebug（跨 flavor 聚合）
// 构建成功后 CLI 仍报 "failed to produce an .apk" 而退出。
// 本任务把 standard 变体产物补拷为无 flavor 名，仅供无 --flavor 的调用命中；
// 显式 --flavor standard 等调用走 assembleStandard<Mode>，不触发本任务。
// 三种 mode 全覆盖：debug（IDE 点 Run 默认）/ profile / release。
listOf("debug", "profile", "release").forEach { mode ->
    val modeCapitalized = mode.replaceFirstChar { it.uppercase() }
    tasks.register<Copy>("copyStandardApksWithoutFlavorName$modeCapitalized") {
        dependsOn("assembleStandard$modeCapitalized")
        from(layout.buildDirectory.dir("outputs/apk/standard/$mode"))
        include("app-standard-*.apk")
        rename { it.replace("-standard", "") }
        into(layout.buildDirectory.dir("outputs/flutter-apk"))
    }
    tasks.matching { it.name == "assemble$modeCapitalized" }.configureEach {
        finalizedBy("copyStandardApksWithoutFlavorName$modeCapitalized")
    }
}
