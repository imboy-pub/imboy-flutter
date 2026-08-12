# `page/moment/moment_create_page.dart`

> 功能点 14 个 | bug 发现 4 / 解决 4 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/moment/moment_create_page.dart` | 空内容时「确认」按钮置灰 | 已通过 | §九 | 1 | 1 | 0 | |
| 无待办 | - | `page/moment/moment_create_page.dart` | 工具栏随内容滚动不挤出「+」 | 已通过 | §九 | 1 | 1 | 0 | |
| 无待办 | - | `page/moment/moment_create_page.dart` | 列表下拉即收起键盘 | 已通过 | §九 | 1 | 1 | 0 | |
| 无待办 | - | `page/moment/moment_create_page.dart` | 相机拍照与录像后上传媒体 | 已通过 | 批次66 | 1 | 1 | 0 | 修复已在 APK 内（15495d4f wechat_camera_picker 07-08、21b05ebb 批量上传逐项 07-12、325-328 录像 pickCamera enableRecording）；真机进发布页媒体网格区+截图确认入口存在；_MediaAddButton→_showMediaPicker→「从相册选择/拍照/录像」sheet 链路代码核验通过；完整拍照上传因 wechat_camera_picker 需硬件相机+写生产存储未触发 |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 输入正文并限制 5000 字上限 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 相册多选图片视频批量上传 | 待重验 | - | 0 | 0 | 0 | 需真机相册素材 |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 上传失败项单独重试与删除 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 可见性五选一并标记当前值 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 部分可见/不给谁看跳选人并回填 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 选择所在位置与清除位置 | 待重验 | - | 0 | 0 | 0 | 需定位权限与高德 Key 生效 |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 提醒谁看选人并展示摘要 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 切换是否允许评论开关 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 发布成功清草稿失败存草稿恢复 | 待重验 | - | 0 | 0 | 0 | 写生产动态数据 |
| 回归复测 | 2026-08-07 | `page/moment/moment_create_page.dart` | 有未保存内容退出弹确认框 | 待重验 | - | 0 | 0 | 0 | |
