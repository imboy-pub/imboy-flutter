# `page/channel/channel_create_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 头像弹层拍照、相册与取消三项 | 已通过 | 批次40 | 0 | 0 | 0 | 真机：弹层三项(拍照/相册/取消)+纱罩；取消关闭正常；相册拉系统选择器选图回传成功 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 头像上传中遮罩与失败提示 | 已通过 | 批次40 | 0 | 0 | 0 | 代码确认 _isUploadingAvatar 遮罩 CircularProgressIndicator(双处渲染)+失败 SnackBar uploadFailed；真机选图回传无崩溃无错误条 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 频道名称必填与 50 字上限校验 | 已通过 | 批次40 | 0 | 0 | 0 | 真机：空提交「频道名称不能为空」；51 字符截断为 50 计数器 0 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 频道描述多行输入与 500 字上限 | 已通过 | 批次40 | 0 | 0 | 0 | 真机输入计数 500→478 正确；maxLines:3 代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 自定义 ID 字符集与 4-30 长度校验 | 已通过 | 批次40 | 0 | 0 | 0 | 真机：bad id! 提交报「只能包含字母、数字和下划线」；ab 报「长度需要在4-30个字符之间」 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 标签添加、去重与上限八个提示 | 已通过 | 批次40 | 0 | 0 | 0 | 真机：test-tag 芯片出现+输入框清空；重复添加静默去重无第二芯片；上限 8 SnackBar 代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 标签芯片删除移除已选标签 | 已通过 | 批次40 | 0 | 0 | 0 | 真机：删除按钮移除芯片 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 公开/私有类型切换与说明文案联动 | 已通过 | 批次40 | 0 | 0 | 0 | 真机：切私有文案变「只有通过邀请链接才能订阅你的频道」；setState 图标联动代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 提交创建时确认按钮置灰与转圈 | 已通过 | 批次40 | 0 | 0 | 0 | 代码确认 isCreating||上传中 onPressed=null 置灰 + CircularProgressIndicator 转圈 |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 创建失败错误条展示并滚动到底 | 已通过 | 批次40 | 0 | 0 | 0 | 代码确认 error 变化→SnackBar(iosRed 4s)+animateTo maxScrollExtent |
| 回归复测 | 2026-08-07 | `page/channel/channel_create_page.dart` | 创建成功刷新列表并跳转详情页 | 已通过 | 批次40 | 0 | 0 | 0 | 真机：qa-test-batch40 创建成功跳详情页(描述/管理按钮渲染)；loadSubscribedChannels 刷新代码确认 |
