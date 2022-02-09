# imboy

A new Flutter project for imboy.

imboy 的Flutter项目

因为我是中国人，所以选择了[木兰宽松许可证, 第2版](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)

所有依赖的flutter包大部分是“MIT License” 和 “Apache-2.0 License”（以后陆续补充一个）


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# 功能 (单个功能实现了，)
* 用户登录（隐藏密码、显示密码，登录密码传输基于RSA算法加密传输） OK
* 用户退出 OK
* 文本聊天 数据聊天分页 OK
* 聊天消息长按右键菜单 OK
* 文本聊天 右键菜单之删除消息功能 OK
* 文本聊天 右键菜单之复制消息功能 OK
* 文本聊天 右键菜单之撤回文本消息功能 OK
    * 发送消息到服务器，服务判断对端是否在线
        * 在线，投递消息给TO, 收到TO的回复后投递给FROM
        * 离线，回复消息给From，修正之前的消息（已经投递/未投递），做一个"离线的撤销消息"以便二次投递
    * 删除消息、或者撤回消息之后，需要更新对应的会话信息 OK
    * 文本聊天 右键菜单之撤回文本消息"重新编辑"功能 OK
    * 文本消息双击全屏显示(单击关闭之） OK
    * 发送表情消息 OK
    * 文本聊天 右键菜单之转发消息功能 TODO
    * 文本聊天 右键菜单之收藏消息功能 TODO
    * 文本聊天 右键菜单之引用消息功能 TODO
    * 文本聊天 右键菜单之多选消息功能 TODO
* 未读消息提醒 OK
* 我的
    * 个人主页
* APP启动引导动画 TODO  https://github.com/jonbhanson/flutter_native_splash#readme
* 删除会话 OK
* 搜索联系人 TODO
* 添加分组、编辑分组、删除分组 TODO
* 发送小图片 TODO
* 发送文件 TODO
* 邀请注册 TODO
* 修改密码 TODO
* 添加好友 TODO
* 扫描二维码添加好友 TODO
* 修改个人资料基本信息 TODO
* 多语言支持 OK
* 创建群 TODO
* 群聊天 TODO
* 群其他功能 TODO

# 已知待修复待完善的功能
* 聊天界面表情符弹框没法想键盘一样"点击页面其他空白处收缩回去"


# 规范

## 目录规范与命名
```
Lib
│
├──page 落地页
│   └──login 页面落地页文件夹
│        ├──login_binding.dart => class LoginBinding 
│        ├──login_logic.dart => class LoginLogic 
│        ├──login_state.dart => class LoginState 
│        └──login_view.dart => class LoginPage 后缀为page为落地页 唯一入口
├──component 通用组件
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
├──helper 公共方法
│    └──index.dart 常规方法、通用方法、全局方法可以用过这个入口export 避免重复引入、可以作用通过用方法入口
├──config 配置中心
│    ├──index.dart 配置变量与切换方法
└──router 路由
     └──  页面映射配置、observe 方法导出

```

## plugin

```
cd plugin/

git submodule add https://gitee.com/imboy-pub/flutter_chat_ui.git flutter_chat_ui

git submodule add https://gitee.com/imboy-pub/popup_menu.git popup_menu

```

然后在 pubspec.yaml 文件添加
```

  flutter_chat_ui:
    path: plugin/flutter_chat_ui
  popup_menu:
    path: plugin/popup_menu
```


参考 https://juejin.cn/post/6844903920322478093

## 多语言
https://github.com/jonataslaw/get_cli/tree/master/translations
```
flutter pub global activate get_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"

mkdir -p assets assets/locales
// cd assets/locales/
// wget https://raw.githubusercontent.com/jonataslaw/get_cli/master/translations/zh_CN.json
// https://github.com/jonataslaw/get_cli/blob/master/translations/en.json
// 生产json文件之后执行下面命令
get generate locales assets/locales on helper
```

## 临时解决 CocoaPods not installed. Skipping pod install

https://github.com/flutter/flutter/issues/97251
```
open /Applications/Android\ Studio\ 4.2\ Preview.app
```
