# imboy

A new Flutter project for imboy.

imboy 的Flutter项目

因为我是中国人，所以选择了[木兰宽松许可证, 第2版](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)

所有依赖的flutter包大部分是“MIT License” 和 “Apache-2.0 License”（以后陆续补充一个）

## APP截图
更多截图[来这里](./doc/appui.md)

<table>
    <td width="32%">
        <img src="https://a.imboy.pub/img/20225/25_21/ca73910gph0gio9q2pg0.png?s=open&a=4e2498d2673bf43d&v=1687988290&width=600" width="100%"/>
    </td>
    <td width="32%">
        <img src="https://a.imboy.pub/img/20225/25_21/ca73cl0gph0gio9q2pp0.png?s=open&a=1ffbf5e386ad0272&v=1687988290&width=600" width="100%"/>
    </td>
    <td width="32%">
        <img src="https://a.imboy.pub/img/20225/25_22/ca73d6ogph0gio9q2psg.png?s=open&a=b2a2bd2380208f87&v=1687988290&width=600" width="100%"/>
    </td>
</table>

## 功能树

* 大概的大大小小功能实现情况：
    * TODO 40
    * OK 108

[查看](./doc/feature_0.1.0_tree.md)

## Version
力求基于“语义化版本控制的规范”([语义化版本 2.0.0](https://semver.org/lang/zh-CN/))实施版本管理.

Strive to implement version management based on "Specification for Semantic version Control"([Semantic Versioning 2.0.0](https://semver.org/)).

## 已知待修复待完善的功能
* 聊天界面表情符弹框没法像键盘一样"点击页面其他空白处收缩回去" （已解决）
* 拍摄视频、上传视频功能（体验不是很好，一分半的视频大小为11M，有待优化）filesize":11649618,"width":640,"height":360,"duration":86876.0
* 红米A5手机，拍摄视频问题
    * https://github.com/flutter/flutter/issues/40519
    * https://github.com/fluttercandies/flutter_wechat_camera_picker/issues/12
* use-flutter-cache-manager-with-video-player 如何边下载、边缓存、边播放 https://stackoverflow.com/questions/68249750/use-flutter-cache-manager-with-video-player
* 语音消息播放之后红点需要取消（已解决）
* 一对一视频通话偶尔有问题，需要进一步优化（以优化，可以进一步调整体验）
* 消息"长按事件"不够灵活（已解决）

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
参考 [FAQ](./doc/FAQ.md)

## 目录规范与命名

* 新增 ./lib/page/single/ 目录，所有的 "类单页面" 都放到该目录
* 避免 master/slave 等术语

Old | New | 说明
---|---|---
master | main | 主要的
slave | subordinate | 从属的
blacklist | denylist | 拒绝名单

```
.env
Lib
│
├──page 落地页
│   ├──single 所有的 "类单页面" 都放到该目录
│   └──login 页面落地页文件夹
│        ├──login_binding.dart => class LoginBinding 可省略
│        ├──login_logic.dart => class LoginLogic
│        ├──login_state.dart => class LoginState 可省略
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
## init
```
cd imboyflutter
cp assets/example.env ./.env
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

## macos
```
open macos/Runner.xcworkspace

```

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

cd ios && rm -rf Podfile.lock pods .symlink Runner.xcworkspace && pod install --repo-update && flutter clean && flutter pub get && pod update && cd ..
```

### deps flutter_dotenv

https://pub.flutter-io.cn/packages/flutter_dotenv
```
cd imboy-flutter
cp -f assets/example.env assets/.env
// 手动修改相应的配置

```

### deps flutter_native_splash
```
dart run flutter_native_splash:create
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
