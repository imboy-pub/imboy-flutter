# imboy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# 功能

* App 底部菜单导航功能
* 用户登录（隐藏密码、显示密码，登录密码传输基于RSA算法加密传输）
* 用户退出
* 用户注册 TODO
* 我的
    * 个人主页
* 

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

##

使用命令行创建 database.g.dart文 件
```
# 只创建一次使用
flutter packages pub run build_runner build

# 一直在动态创建
flutter packages pub run build_runner watch

```

参考 https://juejin.cn/post/6844903920322478093