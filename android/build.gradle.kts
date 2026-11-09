val localProperties = java.util.Properties().apply {
    load(File(rootDir, "local.properties").inputStream())
}
val flutterSdkPath = localProperties.getProperty("flutter.sdk")
    ?: error("Flutter SDK path not found in local.properties")
// Local development retains mirrors; overseas CI explicitly selects official repositories.
val useMavenMirror = providers.gradleProperty("imboyUseMavenMirror")
    .orElse("true").get().toBooleanStrict()

// Firebase 配置只在开发机或 CI 注入 google-services.json 后启用。无配置的
// 开源/契约构建不应为了一个未使用的插件访问 Google Maven，避免网络波动阻断 APK。
// ⚠️ Kotlin DSL 限制：buildscript 块必须是脚本顶层块，不能放在 if 里
// （org.gradle.kotlin.dsl 会抛 InternalError "This should not happen"），
// 且 buildscript 作用域无法引用脚本顶层 val——条件判断须块内内联；
// 插件的实际 apply 由 app/build.gradle.kts 按同一条件执行。
buildscript {
    val useMavenMirror = providers.gradleProperty("imboyUseMavenMirror")
        .orElse("true").get().toBooleanStrict()
    val hasGoogleServicesJson = java.io.File(rootDir, "app/google-services.json").isFile
    repositories {
        if (hasGoogleServicesJson) {
            if (useMavenMirror) {
                maven { url = uri("https://maven.aliyun.com/repository/public") }
                maven { url = uri("https://maven.aliyun.com/repository/google") }
            }
            google()
            mavenCentral()
        }
    }
    dependencies {
        if (hasGoogleServicesJson) {
            classpath("com.google.gms:google-services:4.4.2")
        }
    }
}


allprojects {
    repositories {
        if (useMavenMirror) {
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/central") }
        } else {
            google()
            mavenCentral()
        }
        // 添加 Flutter SDK 的本地 Maven 仓库
        maven {
            url = uri("$flutterSdkPath/packages/flutter_tools/gradle")
        }
    }
}

// 插件的 buildscript 不受 allprojects.repositories 管辖，必须在子项目
// 求值前应用同一选择。官方模式不注入镜像，避免镜像 5xx 阻断插件 AGP 解析。
subprojects {
    buildscript {
        repositories {
            if (useMavenMirror) {
                maven { url = uri("https://maven.aliyun.com/repository/public") }
                maven { url = uri("https://maven.aliyun.com/repository/google") }
                maven { url = uri("https://maven.aliyun.com/repository/central") }
            } else {
                google()
                mavenCentral()
            }
        }
    }
}

// Patrol E2E：AGP 的 consistent resolution 会把 androidx.test 对齐到传递依赖里的
// 1.2.0，而 PatrolJUnitRunner 覆写的 shouldWaitForActivitiesToComplete() 在 1.2.0
// 中尚不存在 → :patrol:compileDebugJavaWithJavac 报"方法不会覆盖超类型的方法"。
// force 比 strictly 优先级更高，是唯一能压过自动对齐的手段。
// ponytail: 只 force 这两个 androidx.test 构件，不做全量版本治理。
// 上限：将来 patrol 升级要求更高的 runner 时，这里的 1.5.2 会反过来把它压低，
// 症状同样是 NoSuchMethodError / 覆写失败——升级 patrol 后先来这里同步版本。
allprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.test:runner:1.5.2")
            force("androidx.test:monitor:1.6.1")
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
