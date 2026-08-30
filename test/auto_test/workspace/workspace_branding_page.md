# `page/workspace/workspace_branding_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 0 / 待处理 2
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/workspace_branding_page.dart` | 从成员管理页治理区 Branding 入口进入 /workspace/:wsId/branding 编辑页 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_branding_page.dart` | 进入时回填当前 branding：名称（空则回落工作区名）/logo/主色 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_branding_page.dart` | 名称输入框可输入且上限 200 字符 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_branding_page.dart` | logo 输入框展示标签与 URL 提示 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_branding_page.dart` | 主色输入框展示占位提示与 helper 格式说明 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 待修复 | 2026-08-30 | `page/workspace/workspace_branding_page.dart` | 输入合法主色值时预览方块实时变色并提示已应用 | 有BUG待修 | 批次W2R1 | 1 | 0 | 1 | 输#FF0000预览仍默认蓝不实时刷新 |
| 无待办 | - | `page/workspace/workspace_branding_page.dart` | 主色为空或非法时预览方块回落主题默认色并提示回落文案 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_branding_page.dart` | 非法色值点保存 toast 提示色值非法且不发请求 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 待修复 | 2026-08-30 | `page/workspace/workspace_branding_page.dart` | 保存成功 toast 提示并自动返回，壳内工作区名称/主色立即生效 | 有BUG待修 | 批次W2R1 | 1 | 0 | 1 | 存#FF0000成功但壳仍默认蓝重进回填空 |
| 阻塞 | 需临时工作区归档后测 | `page/workspace/workspace_branding_page.dart` | 已归档工作区顶部展示归档横幅且保存按钮禁用（服务端 980 兜底） | 未测 | 批次W2R1 | 0 | 0 | 0 | 种子工作区不可归档；create临时区可解 |
| 阻塞 | 需非Owner可达编辑页入口 | `page/workspace/workspace_branding_page.dart` | 非 Owner 保存被服务端拒绝并透出错误消息（仅 Owner 可改） | 未测 | 批次W2R1 | 0 | 0 | 0 | 治理区仅Owner可见无深链入口 |
