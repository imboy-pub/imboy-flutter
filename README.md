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



## 功能 (单个功能实现了，)
* 用户登录（隐藏密码、显示密码，登录密码传输基于RSA算法加密传输） OK
    * “在其他设备登录了”同类型设备强制下线功能（提示"你的账号于19:20在[设备名称]设备上登录了"）
* 用户Email注册功能（获取Email验证码，密码传输基于RSA算法加密传输）OK
* 用户通过Email找回密码 OK
* 用户退出 OK
* 一对一语音通话功能 OK
* 一对一视频通话功能 OK
  * “音视频通话悬浮”功能 OK
  * 一对一视频通话切换网络不掉线 OK(webrtc支持的功能)
* 单聊 数据聊天分页 OK
* 单聊 聊天消息长按右键菜单 OK
* 单聊 右键菜单之删除消息功能 OK
* 单聊 右键菜单之复制消息功能 OK
* 单聊 右键菜单之撤回文本消息功能 OK
    * 发送消息到服务器，服务判断对端是否在线
        * 在线，投递消息给TO, 收到TO的回复后投递给FROM
        * 离线，回复消息给From，修正之前的消息（已经投递/未投递），做一个"离线的撤销消息"以便二次投递
    * 单聊 删除消息、或者撤回消息之后，需要更新对应的会话信息 OK
    * 单聊 右键菜单之撤回文本消息"重新编辑"功能 OK
    * 单聊 文本消息双击全屏显示(单击关闭之） OK
    * *
    * 发送表情消息 OK
    * 单聊 右键菜单之引用消息功能 OK
      * 引用文本消息 OK
      * 引用语音消息 OK
      * 引用图片消息 OK
      * 引用视频消息 OK
      * 引用文件消息 OK
      * 引用位置消息 TODO
    * 单聊 右键菜单之转发消息功能 TODO
    * 单聊 右键菜单之收藏消息功能 TODO
    * 单聊 右键菜单之多选消息功能 TODO
* 未读消息提醒 OK
* 我的
  * 单击头像，预览图像功能 OK
  * 个人主页
    * 更换用户头像功能 OK 
    * 更换昵称 OK
    * 设置性别 OK 参考微信效果
    * 设置个性签名 OK
    * 设置地区 OK 参考微信效果
    * 我的二维码功能 OK （二维码名片，扫描二维码，保存二维码到相册功能）
    * 扫描二维码添加好友功能 TODO
    * 修改密码功能 TODO
    * 我的地址管理 TODO
    * 登录设备列表 TODO
    * 修改登录设备备注名称  TODO
    * 用户基本信息变更后通知好友 TODO
* APP启动引导动画 OK (启动时间大概需要6秒，待优化之)
* 删除会话 OK
* 搜索联系人 TODO
* 添加分组、编辑分组、删除分组 TODO
* 发送图片 OK
    * 拍摄照片上传 OK
    * 聊天界面“单击or双击图片”全屏展示，再单击图片取消全屏 OK
    * 压缩上传 OK
    * 文件秒传功能（首先通过文件sha1值查询存储服务是否已经上传过，再重新上传） OK
* 发送视频、拍摄短视频 OK
* 发送文件 OK
* 语音消息录音、发送、播放功能 OK
* 删除消息（清理消息对应的缓存附件，删除会话，清理所有会话对应的消息的缓存附件） TODO
* 附件上传进度条 OK (引入 flutter_easyloading，体验待优化)
* 添加好友 TODO
  * 扫描二维码添加好友 OK
  * 申请添加好友页面 OK
  * 确认申请好友页面 OK
  * 删除好友申请记录 OK
  * 删除好友功能 OK
  * 
* 多语言支持 OK(服务端还没有支持多语言、很多文案还没有配置多语言)
* 创建群 TODO
* 群聊天 TODO
* 群其他功能 TODO
* 以.env文件来管理APP环境相关的常量配置

## 已知待修复待完善的功能
* 聊天界面表情符弹框没法像键盘一样"点击页面其他空白处收缩回去" （已解决）
* 拍摄视频、上传视频功能（体验不是很好，一分半的视频大小为11M，有待优化）filesize":11649618,"width":640,"height":360,"duration":86876.0
* 红米A5手机，拍摄视频问题
    * https://github.com/flutter/flutter/issues/40519
    * https://github.com/fluttercandies/flutter_wechat_camera_picker/issues/12
* use-flutter-cache-manager-with-video-player 如何边下载、边缓存、边播放 https://stackoverflow.com/questions/68249750/use-flutter-cache-manager-with-video-player
* 语音消息播放之后红点需要取消
* 一对一视频通话偶尔有问题，需要进一步优化

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

## ISAR
https://isar.dev/tutorials/quickstart.html
```
flutter pub run build_runner build --help

flutter pub run build_runner build --delete-conflicting-outputs
flutter pub run build_runner build

```

## 临时解决 CocoaPods not installed. Skipping pod install

https://github.com/flutter/flutter/issues/97251
```
open /Applications/Android\ Studio\ 4.2\ Preview.app
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
cd plugin/

git submodule add https://gitee.com/imboy-tripartite-deps/flutter_chat_ui.git flutter_chat_ui

git submodule add --force https://gitee.com/imboy-tripartite-deps/flutter_chat_ui.git flutter_chat_ui

cd flutter_chat_ui/

git fetch origin leeyi && git checkout -f leeyi

git submodule add https://gitee.com/imboy-tripartite-deps/popup_menu.git popup_menu

```

然后在 pubspec.yaml 文件添加
```

  flutter_chat_ui:
    path: plugin/flutter_chat_ui
  popup_menu:
    path: plugin/popup_menu
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