# Plan: imboyapp 第三方依赖瘦身（去依赖优先）

## Summary
imboyapp 当前有 115 个直接依赖，偏重。本计划按"能自研的简单功能就去依赖、复杂能力换更优库、死依赖直接删"三种动作分阶段瘦身，降低供应链/维护风险、缩减包体积、解耦并精简数量。核心约束：自研只针对真正简单的功能，不重造原生/加密/协议轮子。

## User Story
作为 imboyapp 维护者，我希望砍掉冗余与高危第三方依赖、把简单功能收回自研，
以便降低供应链风险、减小安装包体积、减少维护负担，同时不引入新的稳定性问题。

## Problem → Solution
115 个直接依赖（66% 为 1~3 次极低频，含 6 个 git/path fork、1 个官方废弃库、3 条 override 冲突链）
→ 分阶段瘦身：净删死依赖、自研简单组件、替换废弃/高危库、监测解锁 override。

## Metadata
- **Complexity**: Large（跨多页面 + 真机回归 + 上游监测）
- **Source PRD**: N/A（由依赖审计报告衍生）
- **PRD Phase**: N/A
- **Estimated Files**: 阶段0~2 约 15 个文件；阶段3 约 10 个文件

---

## 自研判定标准（本计划的核心决策闸门）

一个依赖**满足全部 4 条**才走"自研替代"，否则走"换库"或"保留"：
1. 纯 Dart / Flutter 内置能力可覆盖（不碰原生平台通道、不碰加密算法）
2. 代码量可控（< 200~300 行，1~2 个文件）
3. 边界少、无跨平台差异（不需处理四端坑）
4. 当前使用点少（1~3 处）

**绝不自研**：加密（pointycastle/jose/crypto/asn1lib）、原生能力（相机/录音/定位/WebRTC/推送/扫码）、协议栈（dio/sqflite/markdown 解析）、复杂交互（图片裁剪）。

---

## 依赖分类结果（动作矩阵）

### A. 纯删（零使用死依赖）— 零成本
| 包 | 频次 | 备注 |
|---|---|---|
| textfield_tags | 0 | 无 import |
| filter_list (gitee fork) | 0 | 无 import，同时消 1 个 git fork |
| flyer_chat_custom_message | 0 | 需先确认 barrel 不导出 |

### B. 自研替代（符合 4 条标准）— 你理念的核心区
| 包 | 频次 | 使用点 | 自研方案 | 工作量 |
|---|---|---|---|---|
| dotted_border | 1 | `lib/component/ui/avatar_list.dart` | `CustomPainter` 画虚线边框（~60 行） | 小 |
| popup_menu | 1 | `lib/page/chat/chat/chat_provider.dart` | Flutter 内置 `showMenu` / `PopupMenuButton` | 小 |
| popover | 1 | `lib/page/conversation/widget/right_button.dart` | `showMenu` + `RelativeRect` 或 `Overlay` 自研气泡 | 小 |
| sliding_up_panel | 1 | `lib/component/location/widget.dart` | Flutter 内置 `DraggableScrollableSheet` | 中 |
| flutter_animate | 1 | `lib/page/splash/splash_page.dart` | `AnimationController` + `FadeTransition`（启动页一次性动画） | 小 |

> 备选（ROI 偏低，列出供你定夺，默认**不做**）：`ic_storage_space`（自研需写 MethodChannel，已稳定，收益低）。

### C. 换更优依赖（功能复杂，不自研）
| 包 | 问题 | 换成 | 工作量 |
|---|---|---|---|
| flutter_markdown | Google 官方 DISCONTINUED | `flutter_markdown_plus`（drop-in） | 极小 |
| image_crop (gitee fork) | 上游废弃 3 年 | `crop_your_image` v2 | 中（裁剪 UI 重写，**真机回归**） |
| package:http | 与 dio 重复（仅 2 处直播信令） | `dio`（`HttpClient.client`） | 小 |
| image_picker + image_picker_platform_interface + wechat_camera_picker | 与 wechat_assets_picker 功能重叠 | 统一到 `wechat_assets_picker` | 中（~9 处，**真机回归**相册/拍照） |

### D. 保留（合理依赖，不动）
- 核心框架：flutter_riverpod / riverpod_annotation / go_router
- 原生能力：wechat_assets_picker / flutter_sound / just_audio / audio_session / audio_waveforms / flutter_webrtc / amap_* / geolocator / mobile_scanner / permission_handler / flutter_secure_storage / firebase_* / jverify / r_upgrade
- 协议/数据：dio / dio_http2_adapter / web_socket_channel / sqflite_sqlcipher / protobuf / fixnum
- 加密：pointycastle / jose / crypto / asn1lib
- 展示：octo_image / flutter_svg / photo_view / image / shimmer / flutter_easyloading
- 国内化合理 fork：azlistview（14 处，底层 scrollable_positioned_list 仍活跃）

### E. 监测触发式（当前无法主动解，盯上游）
| override 链 | 解锁闸门 | 优先级 |
|---|---|---|
| analyzer ^9 + dart_style 3.1.3 | riverpod_generator 支持 analyzer ^10 | 高（dev-only，闸门到位即解） |
| path_provider_foundation <2.6.0 | Flutter 升级到稳定 code_assets 1.0.0 | 中 |
| win32 5.x 全栈（5 个包） | file_picker 迁移 win32 6.x（追 Issue #1980 / 12.0.0） | 中（须一次性批量解 + 回归 macOS 测试） |

---

## NOT Building（明确不做）
- 不自研任何原生平台能力、加密、协议解析、图片裁剪交互
- 不动核心框架（riverpod/go_router）与本地聊天 UI fork（flutter_chat_ui 11 包）
- 不主动改 win32/analyzer/path_provider override（等上游闸门，仅监测）
- 不动 `plugin/r_upgrade`、`ios/*`、`macos/*`（项目保留区）

---

## 分阶段任务

### 阶段 0 — 纯删死依赖（速赢，纯静态验证）
- **Task 0.1**：确认 `flyer_chat_custom_message` 是否被任何 barrel/export 引用
  - VALIDATE: `grep -rn "flyer_chat_custom_message" lib/ plugin/`
- **Task 0.2**：从 pubspec.yaml 删除 `textfield_tags`、`filter_list`、（确认后）`flyer_chat_custom_message`
  - VALIDATE: `flutter pub get && dart analyze lib`（零新增 error）

### 阶段 1 — 换更优依赖（低风险，多数静态验证）
- **Task 1.1**：`flutter_markdown` → `flutter_markdown_plus`
  - ACTION: 改 pubspec + 全局替换 import；核对 API 差异（基本 drop-in）
  - VALIDATE: `grep -rn "flutter_markdown" lib/`、`dart analyze lib`、渲染含 markdown 的消息/页面
- **Task 1.2**：删 `package:http`，2 处直播信令改 `HttpClient.client.post`
  - 使用点: `lib/page/live_room/publisher/publisher_provider.dart`、`lib/page/live_room/subscriber/subscriber_provider.dart`
  - VALIDATE: `dart analyze lib`；直播推/拉流信令真机验证

### 阶段 2 — 自研替代（你理念核心，逐项门禁）
- **Task 2.1**：自研虚线边框替换 `dotted_border`（`lib/component/ui/avatar_list.dart`）
- **Task 2.2**：`popup_menu` → Flutter `showMenu`（`chat_provider.dart` 消息长按菜单）
- **Task 2.3**：`popover` → 自研/`showMenu`（`right_button.dart`）
- **Task 2.4**：`sliding_up_panel` → `DraggableScrollableSheet`（`location/widget.dart`）
- **Task 2.5**：`flutter_animate` → `AnimationController`（`splash_page.dart`）
- 每项 VALIDATE: `dart analyze lib` + 对应页面真机交互回归；逐项独立提交便于回滚

### 阶段 3 — 媒体重构 + 高危 fork 换库（必须真机回归）
- **Task 3.1**：`image_crop` → `crop_your_image`（`lib/component/helper/crop_image.dart`）
- **Task 3.2**：媒体选择器三合一——删 `image_picker` / `image_picker_platform_interface` / `wechat_camera_picker`，8+1 处统一到 `wechat_assets_picker`
  - 使用点（image_picker 8 处）: chat_background_manager / moment_create_page / channel_edit_page / channel_create_page / profile_provider / profile_page / scanner_page；wechat_camera_picker: attachment_handler.dart
  - VALIDATE: 真机回归头像上传、朋友圈发图、频道封面、聊天拍照/选图、扫码

### 阶段 4 — override 监测（持续，非一次性）
- **Task 4.1**：建立监测——定期 `flutter pub outdated`，盯 riverpod_generator(analyzer ^10) / file_picker(win32 6.x) / Flutter(code_assets) 三闸门
- 闸门到位后另起计划批量解锁对应 override

---

## Validation Commands

```bash
cd /Users/leeyi/project/imboy.pub/imboyapp

# 静态分析（每阶段必跑，以实跑为准，勿宣称"零警告"）
dart analyze lib

# 依赖树核对（确认目标包及其传递依赖已移除）
flutter pub deps --style=compact

# 单元/契约测试
flutter test

# 真机构建验证（阶段3 媒体重构后；禁用模拟器）
flutter run            # 真机
flutter build apk      # 对比瘦身前后包体积
```
EXPECT: 每阶段 `dart analyze lib` 零新增 error；`flutter test` 无回归；阶段3 真机相册/拍照/裁剪功能正常。

---

## Risks
| 风险 | 可能性 | 影响 | 缓解 |
|---|---|---|---|
| 自研组件遗漏边界（暗色/不同屏幕） | 中 | 中 | 逐项独立提交；对照 DESIGN.md token；真机看 |
| 媒体三合一破坏拍照/选图链路 | 中 | 高 | 单独排期；真机逐使用点回归；可单独回滚 |
| crop_your_image 裁剪交互与旧不一致 | 中 | 中 | 阶段3 单独提交；真机验证后再合 |
| flyer_chat_custom_message 实为间接依赖 | 低 | 中 | 删前 grep plugin/ 确认 barrel |
| 误删传递依赖被引入项 | 低 | 中 | 以 `flutter pub deps` 核对，非凭直觉 |

## Notes
- 执行铁律：Flutter 调试用**真机**（项目禁模拟器）；颜色/间距/字号走 `AppColors`/`AppSpacing`/`FontSizeType`，禁硬编码；附件 URL 必经 `AssetsService.viewUrl`。
- 阶段 0~2 互相独立、低风险，可先一气做完提速赢 PR；阶段 3 单独排期；阶段 4 长期挂着。
- 不在本工作区根级写代码文件——所有改动在 imboyapp 独立仓内。
