val localProperties = java.util.Properties().apply {
    load(File(rootDir, "local.properties").inputStream())
}
val flutterSdkPath = localProperties.getProperty("flutter.sdk")
    ?: error("Flutter SDK path not found in local.properties")


allprojects {
    repositories {
        google()
        mavenCentral()
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
