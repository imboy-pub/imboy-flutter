# `page/channel/channel_edit_page.dart`

> 功能点 11 个 | bug 发现 4 / 解决 4 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_edit_page.dart` | 保存成功提示并回传最新频道对象 | 已通过 | 批次18 | 1 | 1 | 0 | 历史真机保存成功（PUT 链 6-23 起存在且曾通） |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 自定义 ID 为空可补设一次、已设则锁定 | 已通过 | 批次18 | 1 | 1 | 0 |  |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 进入时回填资料并拉服务端最新覆盖 | 已通过 | 批次67 | 0 | 0 | 0 | 真机：名称 qa-batch67-edit 回填、ID 框空（未设）、描述空、类型「公开 创建后不可更改」 |
| 回归复测 | 2026-08-07 | `page/channel/channel_edit_page.dart` | 头像弹层选择与上传替换 | 待重验 | 批次18 | 0 | 0 | 0 | 未操作头像 |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 频道名称必填与 50 字上限校验 | 已通过 | 批次67 | 0 | 0 | 0 | 代码确认 L413-427：validator 必填+trim>50 报错+maxLength 50；真机名称框正常 |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 频道描述编辑与 500 字上限 | 已通过 | 批次67 | 0 | 0 | 0 | 代码确认 L437 maxLength 500；真机描述框空 |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 自定义 ID 首字母与最短四位格式校验 | 已通过 | 批次67 | 0 | 0 | 0 | 代码确认 L456-457+L118-127：maxLength 32+`^[a-zA-Z][a-zA-Z0-9_]*$`+≥4 位，空值放行 |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 标签增删与上限八个提示 | 已通过 | 批次82 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 频道类型只读展示与不可修改提示 | 已通过 | 批次67 | 0 | 0 | 0 | 真机「公开 创建后不可更改」+readOnly/enabled 代码确认 |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 保存失败错误提示与按钮恢复 | 已通过 | 批次67 | 2 | 2 | 0 |  |
| 无待办 | - | `page/channel/channel_edit_page.dart` | 底部订阅者数量统计展示 | 已通过 | 批次67 | 0 | 0 | 0 | 真机底部显示 0 |
