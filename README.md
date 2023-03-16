# imboy

A new Flutter project for imboy.

imboy 的Flutter项目

因为我是中国人，所以选择了[木兰宽松许可证, 第2版](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)

所有依赖的flutter包大部分是“MIT License” 和 “Apache-2.0 License”（以后陆续补充一个）

## APP截图
更多截图[来这里](./doc/appui.md)

<table>
    <td width="32%">
        <img src="https://a.imboy.pub/img/20225/25_21/ca73910gph0gio9q2pg0.png?s=dev&a=0b86216ad0e9bafa&v=672233&width=600" width="100%"/>
    </td>
    <td width="32%">
        <img src="https://a.imboy.pub/img/20225/25_21/ca73cl0gph0gio9q2pp0.png?s=dev&a=14d6648edb2dbc7c&v=962076&width=600" width="100%"/>
    </td>
    <td width="32%">
        <img src="https://a.imboy.pub/img/20225/25_22/ca73d6ogph0gio9q2psg.png?s=dev&a=bc7527a333d6e5b0&v=378962&width=600" width="100%"/>
    </td>
</table>

## 功能树

* 大概的大大小小功能实现情况：
    * TODO 48
    * OK 77

[查看](./doc/feature_0.1.0_tree.md)

## 已知待修复待完善的功能
* 聊天界面表情符弹框没法像键盘一样"点击页面其他空白处收缩回去" （已解决）
* 拍摄视频、上传视频功能（体验不是很好，一分半的视频大小为11M，有待优化）filesize":11649618,"width":640,"height":360,"duration":86876.0
* 红米A5手机，拍摄视频问题
    * https://github.com/flutter/flutter/issues/40519
    * https://github.com/fluttercandies/flutter_wechat_camera_picker/issues/12
* use-flutter-cache-manager-with-video-player 如何边下载、边缓存、边播放 https://stackoverflow.com/questions/68249750/use-flutter-cache-manager-with-video-player
* 语音消息播放之后红点需要取消（已解决）
* 一对一视频通话偶尔有问题，需要进一步优化
* 消息"长按事件"不够灵活

## flutter_dotenv

https://pub.flutter-io.cn/packages/flutter_dotenv
```
cd imboy-flutter
cp -f assets/example.env assets/.env
// 手动修改相应的配置

```

## flutter_native_splash
```
flutter pub run flutter_native_splash:create
```

## 多语言
https://github.com/jonataslaw/get_cli/tree/master/translations
```
flutter pub global activate get_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"

mkdir -p assets assets/locales lib/component/locales
// cd assets/locales/
// wget https://raw.githubusercontent.com/jonataslaw/get_cli/master/translations/zh_CN.json
// https://github.com/jonataslaw/get_cli/blob/master/translations/en.json
// 生产json文件之后执行下面命令
get generate locales assets/locales on lib/component/locales
```

## 开发环境遇到的一些问题

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

## Dart 在线运行环境
* https://www.nhooo.com/tool/dart/


## 目录规范与命名

* 新增 ./lib/page/single/ 目录，所有的 "类单页面" 都放到该目录

```
Lib
│
├──page 落地页
│   ├──single 所有的 "类单页面" 都放到该目录
│   └──login 页面落地页文件夹
│        ├──login_binding.dart => class LoginBinding
│        ├──login_logic.dart => class LoginLogic
│        ├──login_state.dart => class LoginState
│        └──login_view.dart => class LoginPage 后缀为page为落地页 唯一入口
├──component 通用组件
│        ├──extension
│             └──get_extension.dart => class GetExtension
│        ├──helper 公共方法
│             └──func.dart => 常规方法、通用方法、全局方法可以用过这个入口export 避免重复引入、可以作用通过用方法入口
│        ├──http HTTP客户端封装
│             └──http.dart =>
│        ├──ui
│             └──common.dart => class UserObject
│        ├──view
│             └──user_object.dart => class UserObject
│        └──widget
│             └──user_object.dart => class UserObject
├──store 数据集中管理
│    ├──index.dart 实例化Provider export model类
│    ├──proto pb协议转换代码
│    ├──service pb协议 yyp协议 等等转义成 dart方法
│    ├──model
│    │    ├──user_model.dart => class UserModel
│    │    └──index.dart => export all models
│    └──object
│         └──user_object.dart => class UserObject
├──config 配置中心
│    ├──index.dart 配置变量与切换方法
└──router 路由
     └──  页面映射配置、observe 方法导出

```

## plugin

```
mkdir -p plugin && cd plugin/

git clone https://gitee.com/imboy-tripartite-deps/flutter_chat_ui.git

cd flutter_chat_ui && git fetch origin leeyi && git checkout -f leeyi

```

然后在 pubspec.yaml 文件添加
```
  flutter_chat_ui:
    path: plugin/flutter_chat_ui
```

参考 https://juejin.cn/post/6844903920322478093

## 分析工具

* https://pub.flutter-io.cn/packages/fps_monitor 这是一个能在 profile/debug 模式下，直观帮助我们评估页面流畅度的工具！！


## deps:
```
arch -x86_64 pod update

arch -x86_64 pod install

```


```
cd ios
arch -x86_64 pod update

arch -x86_64 pod update flutter_webrtc

cd ios && rm -rf Pods && pod cache clean --all && pod install && cd ..
```

### deps flutter_sound_install

https://flutter-sound.canardoux.xyz/flutter_sound_install.html
On iOS you need to add usage descriptions to info.plist:


```
cd ios
pod cache clean --all
rm Podfile.lock
rm -rf .symlinks/
cd ..
flutter clean
flutter pub get
cd ios
pod update
pod repo update
pod install --repo-update
pod update
pod install
cd ..
```

### voice_message_package
```
mkdir -p plugin && cd plugin/
git clone https://gitee.com/imboy-tripartite-deps/voice_message_player.git voice_message_package
```
