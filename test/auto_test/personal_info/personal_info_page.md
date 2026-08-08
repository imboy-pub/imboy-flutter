# `page/personal_info/personal_info/personal_info_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需人工产品决策：删除该页面或接线入口（与 more_page BUG#59 同类，合并决策） | `page/personal_info/personal_info/personal_info_page.dart` | 页面可达性与路由接线 | 未测 | 批次30 | 1 | 0 | 1 | BUG：/personal_info 根路径全仓零跳转点（rg 全仓扫描：mine 页头像 L161 跳 /personal_info/profile 即本页替代者；profile_page 只跳子路由；git log -S 证实从未存在根路径跳转）；真机 UI 无任何入口可达。批次19+23「已通过」记录为历史版本所留，当前版本不可复现。删除或接线=产品决策，代码侧无可修项 |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 头像区渲染昵称与账号ID | 已通过 | 批次19+23 | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 基本信息组展示昵称账号邮箱 | 已通过 | 批次19+23 | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/personal_info/personal_info_page.dart` | 整页滚动全览无布局溢出 | 已通过 | 批次19+23 | 0 | 0 | 0 | |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 点昵称行跳转设置页并回填 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 点头像打开大图预览页 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 点相机角标弹出头像操作面板 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 拍照入口唤起相机取图 | 未测 | - | 0 | 0 | 0 | 需真机相机，模拟器不可验 |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 相册入口选图进入裁剪页 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 裁剪后上传头像并刷新显示 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 点我的二维码跳转二维码页 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | BUG 决策接线后 | `page/personal_info/personal_info/personal_info_page.dart` | 点更多信息跳转更多资料页 | 未测 | - | 0 | 0 | 0 | 目标页 MorePage 存 BUG#59 死页面争议 |
