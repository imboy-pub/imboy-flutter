
### Flutter apk最简单的瘦身方式
* https://juejin.cn/post/6844904186446872584
* https://segmentfault.com/a/1190000023163171
```
flutter build apk --obfuscate --split-debug-info=debugInfo  --target-platform android-arm,android-arm64,android-x64 --split-per-abi

💪 Building with sound null safety 💪

Running Gradle task 'assembleRelease'...                            8.4s
✓  Built build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (49.7MB).
✓  Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (59.4MB).
✓  Built build/app/outputs/flutter-apk/app-x86_64-release.apk (62.8MB).

```

针对不同 CPU 架构所代表含义，尤其 Flutter 打包 Apk 生成的三种 CPU 架构分别对应什么含义：

* x86_64： Intel 64 位，一般用于平板或者模拟器，支持 x86 以及 x86_64 CPU 架构设备。
* arm64-v8a： 第 8 代 64 位，包含 AArch32、AArch64 两个执行状态，且对应 32 、64 bit，并且支持 armeabi、armeabi-v7a 以及 arm64-v8a。
* armeabi-v7a： 第 7 代 arm v7，使用硬件浮点运算，具有高级拓展功能，兼容 armeabi 以及 armeabi-v7a，而且目前大部分手机都是这个架构。


> flutter build apk --target-platform android-arm,android-arm64,android-x64 --split-per-abi

* 首先 flutter build apk 表示当前构建 release 包；
* 后面 android-arm,android-arm64,android-x64 则是指定生成对应架构的 release 包；
* 最后的 --split-per-abi 则表示告知需要按照我们指定的类型分别打包，如果移除则直接构建包含所有 CPU 架构的 Apk 包。

### Mac本下Android项目获取调试版SHA1和发布版SHA1
```
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

keytool -list -v -keystore ~/.android/debug.keystore
```
输入密钥库口令 android 回车键，就可以看到调试版SHA1啦！

### 临时解决 CocoaPods not installed. Skipping pod install

https://github.com/flutter/flutter/issues/97251
```
open /Applications/Android\ Studio\ 4.2\ Preview.app
```

### flutter项目报错：Error: Entrypoint isn‘t within the current project
https://blog.csdn.net/lifengli123/article/details/129009577

Error: Entrypoint isn't within the current project

网上看到很多中解决办法，但是我都试了都不行；然后换了一种搜索方式搜到一篇[文章](https://stackoverflow.com/questions/57154394/webstorm-has-marked-all-files-in-a-directory-as-non-project-files)

大概是我不小心把lib文件加标记成了no project了，然后试着删掉 idea android ios dart_tool文件夹，重启as，右键项目文件夹，选择 Mark Directory as 选择 Sources Root

### 解决  flutter doctor --android-licenses 报错
https://gist.github.com/tommysdk/35053b71293d1a28d5f207ebb5abbf93

in ~/.config/fish/config.fish
```
set -x JAVA_HOME (/usr/libexec/java_home -v 19)
```
java -version

### 各个 Android Gradle 插件版本所需的 Gradle 版本

https://developer.android.google.cn/studio/releases/gradle-plugin?hl=zh-cn

Preferences -> Build -> Build Tools -> Gradle -> Gradle JDK

```
./gradlew wrapper
```
