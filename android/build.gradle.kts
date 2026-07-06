val localProperties = java.util.Properties().apply {
    load(File(rootDir, "local.properties").inputStream())
}
val flutterSdkPath = localProperties.getProperty("flutter.sdk")
    ?: error("Flutter SDK path not found in local.properties")


allprojects {
    repositories {
        // ponytail: 仅用阿里云镜像，移除 google()/mavenCentral() 默认 host
        // —— GFW 对 gradle 的 JDK TLS 握手指纹注入 RST，阿里云镜像不受影响
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // 添加 Flutter SDK 的本地 Maven 仓库
        maven {
            url = uri("$flutterSdkPath/packages/flutter_tools/gradle")
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
