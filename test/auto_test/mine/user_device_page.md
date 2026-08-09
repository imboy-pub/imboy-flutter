# `page/mine/user_device/user_device_page.dart`

> 功能点 14 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 进入页面加载登录设备列表 | 已通过 | 批次57 | 0 | 0 | 0 | 真机 logcat 实锤 GET user_device/page?page=1&size=1000+8 台设备渲染（当前1+其他7） |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 展示顶部设备管理说明卡片 | 已通过 | 批次57 | 0 | 0 | 0 | 真机「你的帐号在以下设备中登录过，你可以删除设备…」；代码 L100-117 loginDeviceManagementTips+info 图标 |
| 无待办 | - | `page/mine/user_device/user_device_page.dart` | 分组标题不与页面标题重复 | 已通过 | 批次18 | 1 | 1 | 0 | |
| 无待办 | - | `page/mine/user_device/user_device_page.dart` | 设备名为空时显示兜底名称 | 已通过 | 批次18 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 当前设备显示本机徽标 | 已通过 | 批次57 | 0 | 0 | 0 | 真机「MRD-AL00 当前设备 在线」徽标；代码 L180-193 currentDid==deviceId 渲染 currentDevice 蓝色小徽标 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 展示在线离线状态点与文案 | 已通过 | 批次57 | 0 | 0 | 0 | 真机 当前设备「在线」+7 台「离线」；代码 L204-218 iosGreen/iosGray 6px 圆点+online/offline 文案 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 展示最后活跃时间相对格式 | 已通过 | 批次57 | 0 | 0 | 0 | 真机「1小时前」相对格式；代码 datetime.dart:27-30 两天内走 _formatRelativeTime |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 按设备类型映射对应图标 | 已通过 | 批次57 | 0 | 0 | 0 | 代码确认 L255-269 全分支映射（ios/iphone→phone_iphone、android→phone_android、macos→laptop_mac、windows→laptop_windows、web→web、desktop→desktop_mac、default→devices）；语义树无图标仅代码层 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 点击设备条目进入设备详情 | 已通过 | 批次57 | 0 | 0 | 0 | 真机点 iPhone 条目→设备详情页（名称/类型/离线/最近活跃时间/安全说明渲染） |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 左滑显示强制下线与删除操作 | 已通过 | 批次57 | 0 | 0 | 0 | 真机左滑「其他设备」弹出「下线」+「删除」操作面板；代码 L227-253 Slidable+endActionPane |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 离线设备的强制下线按钮禁用 | 已通过 | 批次57 | 0 | 0 | 0 | 真机点「下线」无确认框弹出（disabled 点击穿透进详情页）+详情页「让该设备下线」(disabled)；代码 onPressed: model.online?…:null；语义树误标 clickable 实测禁用 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 强制下线前弹出二次确认框 | 已通过 | 批次57 | 0 | 0 | 0 | 代码确认 L277-305 _showForceOfflineDialog（forceDeviceOfflineConfirm+取消/强制下线）；离线禁用态无法真机弹出，在线设备仅当前设备不可左滑 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 删除设备前弹出二次确认框 | 已通过 | 批次57 | 0 | 0 | 0 | 真机实锤「删除后，下次在该设备登录时需要进行安全验证。」+取消/删除(isDestructiveAction)；未执行删除 |
| 回归复测 | 2026-08-07 | `page/mine/user_device/user_device_page.dart` | 当前设备不提供滑动删除操作 | 已通过 | 批次57 | 0 | 0 | 0 | 真机左滑当前设备无任何操作面板；代码 L226 isCurrentDevice 直接 return itemTile 不包 Slidable |
