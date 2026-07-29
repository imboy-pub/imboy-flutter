val localProperties = java.util.Properties().apply {
    load(File(rootDir, "local.properties").inputStream())
}
val flutterSdkPath = localProperties.getProperty("flutter.sdk")
    ?: error("Flutter SDK path not found in local.properties")


allprojects {
    repositories {
        // ponytail: 仅用阿里云镜像，移除 google()/mavenCentral() 默认 host
        // —— GFW 对 gradle 的 JDK TLS 握手指纹注入 RST，阿里云镜像不受影响
        // 上限：只有阿里云同步过的构件能解析。刚发布的版本、私有库、以及只在
        // Google 托管的预览版构件会直接构建失败（报"找不到依赖"而非网络错，
        // 容易误判成版本号写错）；境外/无 GFW 的 CI 也被迫走这三个国内源。
        // 升级触发：出现镜像缺件，或需要在境外 CI 构建时，改为按环境判断追加
        // google()/mavenCentral()（如读 env CN_MIRROR），而不是无条件二选一。
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // 添加 Flutter SDK 的本地 Maven 仓库
        maven {
            url = uri("$flutterSdkPath/packages/flutter_tools/gradle")
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
