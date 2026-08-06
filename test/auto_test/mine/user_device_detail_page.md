# `page/mine/user_device/user_device_detail_page.dart`

> 功能点 14 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 展示设备图标名称与类型卡片 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 展示设备在线离线状态指示 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 无待办 | - | `page/mine/user_device/user_device_detail_page.dart` | 设备类型为空时兜底显示未知 | 已通过 | 批次18 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 点击设备名称进入改名页 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 改名成功后详情页名称即时更新 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 格式化展示最后活跃时间 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 无活跃时间时显示未知 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 展示活跃时间说明提示卡片 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 非当前设备才显示下线按钮 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 设备离线时下线按钮置灰禁用 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 强制下线二次确认并下发指令 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 删除设备按钮用 iosRed 破坏色 | 待重验 | 批次18 | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/mine/user_device/user_device_detail_page.dart` | 删除设备二次确认并返回列表 | BUG已修待验 | 批次26 | 1 | 0 | 1 | 本轮新发现并已修：_deleteDevice 用 dialog builder context，pop 后 mounted 恒 false，「返回设备列表」从未执行 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_detail_page.dart` | 切换语言后页面文案即时刷新 | 待重验 | 批次18 | 0 | 0 | 0 | |
