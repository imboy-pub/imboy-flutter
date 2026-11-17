# Flutter 3.50 UI 依赖迁移 / UI dependency migration

仓库 CI 固定 Flutter 3.50.0。应用使用独立的 `material_ui` 与 `cupertino_ui`，
包括主题、路由组件及本地化委托。Flutter SDK 的基础 Widget、foundation、动画和
渲染 API 保持原来源。新旧库中名称相同的 `ThemeData`、`InputDecoration`、
`MaterialLocalizations` 等是不同类型，不能只迁移应用根而保留这些依赖边界。

This repository uses the standalone design libraries with its pinned Flutter SDK.
Matching class names across the legacy and standalone libraries do not establish
type or inherited-context compatibility.

## 固定来源与维护范围 / Pinned sources

`plugin/flutter_ui_vendor/` 保存当前锁定版本的最小本地适配。每个包均包含
`UPSTREAM.json`、原许可证、生产源码及其声明的运行资源。`pubspec.lock` 明确记录
path 来源；原版本不是“上游已完成迁移”的声明。本地副本禁止发布。

| 包 | 需要统一的边界 |
|---|---|
| `flutter_markdown_plus` | 主题参数、Markdown 控件及平台文本选择 |
| `flutter_easyloading` | 全局加载与提示层的主题、本地化 |
| `feedback` | 主题参数、编辑器及其内部 Localizations |
| `intl_phone_number_input` | 输入装饰、手机号输入、国家选择与国旗资源 |
| `wechat_assets_picker` | 选择器主题、返回按钮及预览本地化 |
| `wechat_camera_picker` | 拍摄界面主题、返回按钮及预览本地化 |
| `wechat_picker_library` | 两个选择器共同使用的主题、扩展及进度控件 |
| `extended_image` | 预览、滑动退出及图片编辑的主题 |
| `emoji_picker_flutter` | 表情分类 TabBar、搜索输入及插件注册 |
| `flutter_slidable` | 操作按钮及其继承主题 |
| `highlight_text` | 可点击高亮的 InkWell 与 Material 祖先 |
| `flutter_rating_bar` | 评分控件使用的主题颜色 |
| `flyer_chat_audio_message` | 聊天音频组件及错误提示的 ScaffoldMessenger |
| `flyer_chat_video_message` | 聊天视频组件的 UI 类型 |

Hosted 包的归档 SHA-256、原文件哈希和精确修改清单记录在各包的来源文件中。
两个 Flyer 包来自 `flutter_chat_ui` 的锁定 Git 提交；其它聊天包仍使用原 submodule。
移动这两个 workspace 包时显式声明了原本实际使用的依赖，包括它们已有的应用层耦合。
emoji 插件的原生注册源码完整保留；应用根 `ios/`、`macos/` 和 `plugin/r_upgrade`
不属于这次迁移的修改范围。

The copies retain runtime assets and native registration sources where applicable.
Their provenance identifies both unchanged upstream files and the local patch.
Public UI imports and localization delegates are migrated together; compatibility
facades and private Flutter SDK imports are not used to conceal diagnostics.

现有变更文件门禁也直接检查这些依赖源码。适配包含显式泛型和回调类型、
替换弃用 API、必要的异步 mounted 检查，以及本地 fork 内不规范标识符的命名修正。
公开枚举改名时同步更新应用调用；枚举顺序和已有序列化格式保持原样。
具体差异以每包 `UPSTREAM.json` 为准，不能将整项适配描述为仅替换 import。

## 修改规则 / Maintenance

- 从已记录的发布归档或 Git 提交复现来源，保留所有版权和许可证声明。
- 原文件哈希只描述上游来源，不能在本地修改后重写为当前哈希。
- 修改本地副本时更新其改动清单，说明行为变化；纯发布截图可以省略，运行资源不可省略。
- 同步根 `pubspec.yaml` 与真实解析生成的 lockfile，执行锁定依赖检查。
- 保持原质量门禁、分析设置和基线；分析结果中的类型错误即使被配置为 INFO 也必须修复。

Preserve upstream hashes when recording local changes. Dependency resolution and
runtime validation must use these actual path dependencies, rather than modified
copies in a developer's global package cache.

## 验证 / Validation

使用固定 SDK 解析依赖，然后通过仓库统一执行入口验证。主题回归分别覆盖明暗模式；
本地化回归使用新 Material/Cupertino 委托，直接渲染依赖的真实控件。测试入口包括
手机号国家选择、反馈编辑器、Markdown、加载提示、表情搜索、高亮点击、滑动操作、
评分、选择器返回按钮、预览背景和平台进度控件。还直接验证聊天音视频组件的
错误提示、播放器路由和控制，以及 PhotoView 从加载指示器到真实图片的切换。
反馈编辑器在同一实例内连续切换暗、亮、暗主题，确保保留的 Overlay 不缓存旧配色。

媒体选择器的 host 测试不初始化实际相机或扫描用户相册；这不能替代真机权限、拍摄、
视频和保留安装验收。既有设备、产品和截图执行合同继续生效，未运行的任务不计通过。

Host tests establish type and inherited-context compatibility for the exercised
widgets. Hardware access, permissions, retained installations and platform pixel
acceptance remain separate obligations under the existing execution contracts.

## 恢复上游依赖 / Returning to upstream

上游发布完成相同 UI 迁移的版本后，先对比本地改动与公开 API，再逐个移除 path override、
重新解析 lockfile 并运行对应组件及完整 PR 检查。只有不再被任何声明或源码引用时才删除
本地副本及其来源记录；不要用未经固定的上游分支替代可复现版本。

Remove a local copy only after the replacement release preserves the required API,
passes its component regressions and is no longer referenced by the dependency graph.
