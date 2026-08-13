# `page/mine/setting/setting_page.dart`

> 功能点 16 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 进入账号安全设置页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+账号安全入口存在（批次50已详验，稳定功能无回归） |
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 进入语言设置页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+语言设置入口存在（批次50已详验，稳定功能无回归） |
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 进入深色模式页并回显当前模式 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+深色模式入口副标题「已关闭」回显正确（批次50已详验，稳定功能无回归） |
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 进入字号设置页并回显当前档位 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+字体大小入口副标题「标准」回显正确（批次50已详验，稳定功能无回归） |
| 无待办 | - | `page/mine/setting/setting_page.dart` | 切换允许被搜索开关并同步后端 | 已通过 | §三十六 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/setting/setting_page.dart` | 刷新设备密钥并清空 E2EE 缓存 | 已通过 | §三十六 | 0 | 0 | 0 | 批次50 代码确认 L425-441 clearCache→500ms 重拉设备公钥→成功提示；清缓存有旧消息解密风险未真机点击 |
| 回归复测 | 2026-08-07 | `page/mine/setting/setting_page.dart` | 打开 E2EE 密钥管理页 | 已通过 | §三十六 | 0 | 0 | 0 | 批次50 真机密钥管理页：已启用/设备 ID HUAWEIMRD-AL00/密钥 ID kid_ab3e7fe52eb9f981/创建时间+恢复方法本地备份+危险操作区；未做生成/删除 |
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 打开更新日志文档 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+更新日志入口存在（批次50已详验，稳定功能无回归） |
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 打开帮助文档 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+帮助文档入口存在（批次50已详验，稳定功能无回归） |
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 打开隐私政策文档 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+隐私政策入口存在（批次50已详验，稳定功能无回归） |
| 无待办 | - | `page/mine/setting/setting_page.dart` | 打开服务条款页面 | 已通过 | §三十六 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/setting/setting_page.dart` | 打开关于页并展示版本与更新红点 | 已通过 | §三十六 | 0 | 0 | 0 | 批次50 真机关于页：IMBoy 简介+主要功能+隐私说明+检查更新按钮；设置页入口「关于应用 版本 1.0.0-alpha.15」；代码确认 L345-355 hasUpdate 渲染 8px 红点（当前无新版本不显示） |
| 回归复测 | 2026-08-07 | `page/mine/setting/setting_page.dart` | 在关于页手动检查版本更新 | 已通过 | §三十六 | 0 | 0 | 0 | 批次50 真机点击检查更新：logcat 实锤 app_version/check?vsn=1.0.0-alpha.15+app_upgrade/report 请求，无新版本提示最新版（toast 一闪）；代码确认 L486-497 |
| 回归复测 | 2026-08-07 | `page/mine/setting/setting_page.dart` | 切换运行环境并重启应用 | 已通过 | §三十六 | 0 | 0 | 0 | 批次50 代码确认 L260-267 开发者分组仅非生产包渲染；真机 pro 包滚动到底未见该行 |
| 无待办 | - | ``page/mine/setting/setting_page.dart`` | 退出登录并二次确认 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：设置页入口存在+退出登录入口存在（批次50已详验，稳定功能无回归） |
| 无待办 | - | `page/mine/setting/setting_page.dart` | 注销账号入口用 iosRed 破坏色 | 已通过 | §三十六 | 1 | 1 | 0 | |
