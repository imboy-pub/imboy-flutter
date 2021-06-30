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


# 规范

## 目录规范与命名
```
Lib
│
├──page 落地页
│   └──user 页面模块文件夹
│       └──login 页面落地页文件夹
│            └──user_login.dart => class UserLoginPage 后缀为page为落地页 唯一入口
│            └──user_login_button.dart => class UserLoginButton 非公共部分页面子组件
├──component 通用组件
│        └──Modal
│            └──alert.dart => class ModalAlertComponent
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

参考 https://juejin.cn/post/6844903920322478093