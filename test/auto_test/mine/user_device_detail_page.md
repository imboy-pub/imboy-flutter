# `page/mine/user_device/user_device_detail_page.dart`

> 功能点 14 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 展示设备图标名称与类型卡片 | 已通过 | 批次58 | 0 | 0 | 0 | 真机 iPhone「iPhone iOS 26.5.2」/MRD-AL00「android 28」/其他设备「未知」；图标代码确认 L445-465 全分支映射 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 展示设备在线离线状态指示 | 已通过 | 批次58 | 0 | 0 | 0 | 真机 当前设备「在线」+其他设备「离线」；代码同列表页 iosGreen/iosGray 圆点 |
| 无待办 | - | `page/mine/user_device/user_device_detail_page.dart` | 设备类型为空时兜底显示未知 | 已通过 | 批次18 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 点击设备名称进入改名页 | 已通过 | 批次58 | 0 | 0 | 0 | 真机点设备名称行→「设置设备名称」页（输入框+完成按钮）；未提交 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 改名成功后详情页名称即时更新 | 已通过 | 批次58 | 0 | 0 | 0 | 代码确认 L483-505 ChangeNamePage callback→changeName API→setState 名称即时更新；写操作未执行 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 格式化展示最后活跃时间 | 已通过 | 批次58 | 0 | 0 | 0 | 真机「2026-08-08 11:45:10」全格式（dateTimeFmt yyyy-MM-dd HH:mm:ss relative:false） |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 无活跃时间时显示未知 | 已通过 | 批次58 | 0 | 0 | 0 | 代码确认 L470-473 lastActiveAt<=0→t.common.unknown；真机全部设备有时间无法构造 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 展示活跃时间说明提示卡片 | 已通过 | 批次58 | 0 | 0 | 0 | 真机「当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时…」说明卡片 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 非当前设备才显示下线按钮 | 已通过 | 批次58 | 0 | 0 | 0 | 真机双验：非当前设备详情有「让该设备下线」；当前设备 MRD-AL00 详情仅删除按钮无下线 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 设备离线时下线按钮置灰禁用 | 已通过 | 批次58 | 0 | 0 | 0 | 真机「让该设备下线」disabled；代码 onPressed: model.online?…:null |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 强制下线二次确认并下发指令 | 已通过 | 批次58 | 0 | 0 | 0 | 代码确认 L385-410 forceDeviceOfflineConfirm+取消/确认(isDestructive)+_forceOffline L429-437 API+forceOfflineCommandSent 提示；离线设备无法真机触发 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 删除设备按钮用 iosRed 破坏色 | 已通过 | 批次58 | 0 | 0 | 0 | 代码确认 L350-379 AppColors.getIosRed 背景0.1alpha+前景iosRed+红色描边+delete_outline 图标 |
| 无待办 | — | `page/mine/user_device/user_device_detail_page.dart` | 删除设备二次确认并返回列表 | 已通过 | 批次27 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 切换语言后页面文案即时刷新 | 已通过 | 批次58 | 0 | 0 | 0 | 代码确认 页面全 t.common/t.account slang 响应式键无硬编码；语言切换全局机制批次52 已验证 |
