# `page/personal_info/personal_info/personal_info_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 页面可达性与路由接线 | 已通过 | 批次125 | 1 | 1 | 0 | BUG#59 失效：workspace_account_menu.dart:180 账户 Sheet「个人资料」已 push /personal_info（接线发生在批次30 定性之后）；AT-PI01 深链验证可达 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 头像区渲染昵称与账号ID | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI01 昵称+ID: 51730 渲染 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 基本信息组展示昵称账号邮箱 | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI01 昵称/账号/登录邮箱三行 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 整页滚动全览无布局溢出 | 已通过 | 批次19+23 | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 点昵称行跳转设置页并回填 | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI04 SetNicknamePage 回填当前昵称 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 点头像打开大图预览页 | 已通过 | 批次127 | 0 | 0 | 0 | AT-PI13 正向路径全绿：造值=服务端 avatar 置公网 URL（F-13 只拒内网公网放行），重登经 login_resp.avatar 进本地缓存；列表页(192宽)+预览页(原图)两次真实下载 329351 bytes 成功，PhotoView/xmark 挂载+关闭返回断言全过；test runner 不支持截图（环境限制），功能证据=下载日志+断言链 reports/batch127/at_pi13_run1.log |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 点相机角标弹出头像操作面板 | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI06 ActionSheet 条件分支：avatar 空无查看大图项，三常驻项+取消正常 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 拍照入口唤起相机取图 | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI07 fake MediaPickerCapability 验证走 pickCamera（与相册同源 bug 已修）+裁剪页；真机相机行为转真机 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 相册入口选图进入裁剪页 | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI08 fake pickSingle(image)→CropImageRoute |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 裁剪后上传头像并刷新显示 | 已通过 | 批次125 | 1 | 1 | 0 | AT-PI09 裁剪→presign→PUT Garage→confirm→updateField 全链，缓存/DB 一致；挖出并修复 attachment_api errorCallback TypeError 真 bug（Exception 传入 (Error) 签名回调崩溃，两处） |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 点我的二维码跳转二维码页 | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI10 UserQrCodePage 渲染与返回 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 点更多信息跳转更多资料页 | 已通过 | 批次125 | 0 | 0 | 0 | AT-PI11 MorePage 可达，BUG#59 关联争议一并解除 |
