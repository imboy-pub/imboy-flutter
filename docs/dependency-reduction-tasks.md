# imboyapp 降依赖实施任务清单

> 供 `/loop` 命令逐任务执行。每个任务独立可回滚，完成后打 ✅。
> 工作目录：`/Users/leeyi/project/imboy.pub/imboyapp`
> 执行前提：`flutter pub get` 已通过；真机已连接（P3 阶段才需要）。

---

## P0 — 纯删死依赖（约 0.5 人·天）

- [ ] **T01** 确认 `flyer_chat_custom_message` 是否被引用
  ```bash
  grep -rn "flyer_chat_custom_message" lib/ plugin/
  ```
  预期：无输出 → 可删；有输出 → 跳过 T02 中该包

- [ ] **T02** 删除零使用死依赖
  - 从 `pubspec.yaml` 删除：`textfield_tags`、`filter_list`（gitee fork）、`flyer_chat_custom_message`（若 T01 无输出）
  ```bash
  flutter pub get && dart analyze lib
  ```
  预期：零新增 error

---

## P1 — 换更优依赖（约 1 人·天）

- [ ] **T03** `flutter_markdown` → `flutter_markdown_plus`
  - `pubspec.yaml` 中将 `flutter_markdown` 替换为 `flutter_markdown_plus`
  - 全局替换 import：`import 'package:flutter_markdown/` → `import 'package:flutter_markdown_plus/`
  ```bash
  grep -rn "flutter_markdown" lib/ | grep -v flutter_markdown_plus
  dart analyze lib
  ```
  预期：grep 无输出；analyze 零新增 error

- [ ] **T04** 删除 `package:http`，直播信令改用 `dio`
  - 使用点：`lib/page/live_room/publisher/publisher_provider.dart`、`lib/page/live_room/subscriber/subscriber_provider.dart`
  - 将 `http.post(...)` 改为 `Dio().post(...)` 或通过现有 HttpClient 调用
  - `pubspec.yaml` 删除 `http`
  ```bash
  grep -rn "package:http" lib/
  dart analyze lib
  ```
  预期：grep 无输出；analyze 零新增 error

---

## P2 — 自研替代轻量 UI 库（约 5 人·天）

> 每项独立提交，互不阻塞，失败可单独回滚。

- [ ] **T05** `dotted_border` → `CustomPainter` 虚线边框
  - 修改 `lib/component/ui/avatar_list.dart`
  - 新增 `_DottedBorderPainter extends CustomPainter`（约 60 行）
  - `pubspec.yaml` 删除 `dotted_border`
  ```bash
  grep -rn "dotted_border" lib/
  dart analyze lib
  ```
  预期：grep 无输出

- [ ] **T06** `popup_menu` → Flutter 内置 `showMenu`
  - 修改 `lib/page/chat/chat/chat_provider.dart`（消息长按菜单）
  - `pubspec.yaml` 删除 `popup_menu`（确认无其他使用点后）
  ```bash
  grep -rn "popup_menu" lib/
  dart analyze lib
  ```
  预期：grep 无输出

- [ ] **T07** `popover` → `showMenu` + `RelativeRect`
  - 修改 `lib/page/conversation/widget/right_button.dart`
  - `pubspec.yaml` 删除 `popover`
  ```bash
  grep -rn "package:popover" lib/
  dart analyze lib
  ```
  预期：grep 无输出

- [ ] **T08** `sliding_up_panel` → `DraggableScrollableSheet`
  - 修改 `lib/component/location/widget.dart`
  - `pubspec.yaml` 删除 `sliding_up_panel`
  ```bash
  grep -rn "sliding_up_panel" lib/
  dart analyze lib
  ```
  预期：grep 无输出；位置选择页面真机滑动手感验证

- [ ] **T09** `flutter_animate` → `AnimationController` + `FadeTransition`
  - 修改 `lib/page/splash/splash_page.dart`（启动页一次性动画）
  - `pubspec.yaml` 删除 `flutter_animate`
  ```bash
  grep -rn "flutter_animate" lib/
  dart analyze lib
  ```
  预期：grep 无输出；冷启动动画目视正常

- [ ] **T10** `shimmer` → 自研 `ShimmerBox` 组件
  - 新建 `lib/component/ui/shimmer_box.dart`（`AnimatedBuilder` + `LinearGradient` + `ShaderMask`，约 120 行）
  - 全局替换所有 `Shimmer.fromColors(...)` 调用为 `ShimmerBox(child: ...)`
  - `pubspec.yaml` 删除 `shimmer`
  ```bash
  grep -rn "package:shimmer" lib/
  dart analyze lib
  ```
  预期：grep 无输出；列表骨架屏闪光动画目视正常

- [ ] **T11** `badges` → 自研 `BadgeWidget`（可选）
  - 新建 `lib/component/ui/badge_widget.dart`（`Stack` + `Positioned` + `Container`，约 40 行）
  - 替换所有 `badges` 使用点
  - `pubspec.yaml` 删除 `badges`
  ```bash
  grep -rn "package:badges" lib/
  dart analyze lib
  ```
  预期：grep 无输出

---

## P2-B — 能力契约层 + 边界门禁（约 2.5 人·天，可与 P2 并行）

- [ ] **T12** 建 `capabilities/` 目录骨架 + 6 个接口文件
  - 创建 `lib/capabilities/contracts/` 下 6 个接口文件（参考 `dependency-architecture-research.md §1.3`）
  - 创建 `lib/capabilities/adapters/`（空目录，放占位 `.gitkeep`）
  - 创建 `lib/capabilities/capability_locator.dart`
  ```bash
  dart analyze lib/capabilities/
  ```
  预期：零 error

- [ ] **T13** `MediaPickerCapability` adapter 实现
  - 新建 `lib/capabilities/adapters/wechat_assets_picker_adapter.dart`
  - 实现 `MediaPickerCapability` 接口，封装 `wechat_assets_picker` 调用
  - `run.dart` 注册：`CapabilityLocator.I.register<MediaPickerCapability>(WechatAssetsPickerAdapter())`
  ```bash
  dart analyze lib/capabilities/
  ```
  预期：零 error

- [ ] **T14** 新建边界门禁脚本 `scripts/check_boundaries.dart`
  - 参考 `dependency-architecture-research.md §3.3` 实现
  - 受检目录：`lib/modules/**`、`lib/page/**`
  - 白名单：`dart:`、`flutter/`、`package:imboy/`
  ```bash
  dart scripts/check_boundaries.dart
  ```
  预期：输出当前违反数（基线期允许非零，记录数字）

- [ ] **T15** CI 集成边界门禁（基线期 `continue-on-error: true`）
  - 在 CI yaml 中 `dart analyze` 之后新增 step：
    ```yaml
    - name: Check module boundaries
      run: dart scripts/check_boundaries.dart
      continue-on-error: true   # 基线期，收集数据；归零后删此行
    ```
  ```bash
  cat .github/workflows/*.yml | grep -A3 "check_boundaries" || echo "step not found"
  ```
  预期：step 存在

---

## P3 — 媒体重构（约 4 人·天，需真机，单独排期）

> ⚠️ 此阶段需真机全程陪同，不要在 P2 未完成前启动。

- [ ] **T16** `image_crop` → `crop_your_image` v2
  - 修改 `lib/component/helper/crop_image.dart`
  - 对齐新 API（裁剪回调/输出格式）
  - `pubspec.yaml` 替换依赖
  ```bash
  grep -rn "image_crop" lib/
  dart analyze lib
  ```
  预期：grep 无 image_crop；真机头像裁剪正方形输出正常

- [ ] **T17** 媒体选择器三合一（最高风险，最后执行）
  - 删 `image_picker`、`image_picker_platform_interface`、`wechat_camera_picker`
  - 8+1 处使用点统一改为 `wechat_assets_picker`（通过 `MediaPickerCapability` 接口调用）
  - 使用点：`chat_background_manager`、`moment_create_page`、`channel_edit_page`、`channel_create_page`、`profile_provider`、`profile_page`、`scanner_page`、`attachment_handler.dart`
  ```bash
  grep -rn "image_picker\|wechat_camera_picker" lib/
  dart analyze lib
  flutter build apk
  ```
  预期：grep 无输出；真机逐点验证：头像上传 / 朋友圈发图 / 频道封面 / 聊天拍照 / 聊天选图 / 扫码

---

## P4 — Override 监测（长期挂着，无需 loop 执行）

- [ ] **T18** 建 override 监测定期检查习惯
  ```bash
  flutter pub outdated
  ```
  三个闸门：
  - `riverpod_generator` 支持 `analyzer ^10` → 解锁 analyzer/dart_style override
  - `file_picker` 迁移 `win32 6.x`（追 Issue #1980） → 批量解锁 win32 5.x 全栈
  - Flutter 稳定 `code_assets 1.0.0` → 解锁 `path_provider_foundation`
  任一闸门到位，另起计划处理。

---

## 快速参考

```bash
# 切换到正确工作目录
cd /Users/leeyi/project/imboy.pub/imboyapp

# 每个任务完成后的标准验证
dart analyze lib                        # 零新增 error
flutter pub deps --style=compact        # 确认目标包已移除
flutter test                            # 无回归（有测试的部分）

# 包体积对比（P0~P2 完成后 vs 当前）
flutter build apk --analyze-size 2>&1 | grep "app-release.apk"
```

---

## 进度记录

| 任务 | 状态 | 完成日期 | 备注 |
|---|---|---|---|
| T01 | ✅ | 2026-06-14 | lib/ 无引用，flutter_chat_ui 不依赖 |
| T02 | ✅ | 2026-06-14 | 删 textfield_tags/filter_list/flyer_chat_custom_message，Changed 4 deps，analyze 0 error |
| T03 | ✅ | 2026-06-14 | flutter_markdown→flutter_markdown_plus@1.0.7，analyze 0 error |
| T04 | ✅ | 2026-06-14 | http→Dio，删 pubspec http 依赖，Changed 1 dep，analyze 0 error |
| T05 | ✅ | 2026-06-14 | CustomPainter 替代 dotted_border，Changed 1 dep，analyze 0 issue |
| T06 | ✅ | 2026-06-14 | popup_menu 上一轮已删除，确认 lib/ 无 import |
| T07 | ✅ | 2026-06-14 | showMenu+RelativeRect 替代 showPopover，StatefulWidget+GlobalKey，Changed 1 dep，analyze 0 issue |
| T08 | ✅ | 2026-06-14 | DraggableScrollableSheet+Controller 替代 SlidingUpPanel，Changed 1 dep，analyze 0 issue；真机验证待 P3 |
| T09 | ✅ | 2026-06-14 | AnimationController+FadeTransition+ScaleTransition+AnimatedBuilder替代flutter_animate，删pubspec，analyze 0 issue |
| T10 | ✅ | 2026-06-14 | 自研ShimmerBox(AnimationController+ShaderMask+LinearGradient)，替换5处Shimmer.fromColors，Changed 1 dep，analyze 0 issue |
| T11 | ✅ | 2026-06-14 | 自研BadgeWidget(Stack+Positioned)替换3处badges.Badge，Changed 1 dep，analyze 0 issue |
| T12 | ✅ | 2026-06-14 | capabilities/目录骨架+6个接口文件+CapabilityLocator，analyze 0 issue |
| T13 | ✅ | 2026-06-14 | WechatAssetsPickerAdapter实现MediaPickerCapability，run.dart注册，analyze 0 issue |
| T14 | ✅ | 2026-06-14 | scripts/check_boundaries.dart 创建；基线 231 条违反（lib/page+lib/modules 直接 import 三方包），基线期允许非零 |
| T15 | ✅ | 2026-06-14 | .github/workflows/ci.yml 在 dart analyze 后追加 check_boundaries step，continue-on-error:true 基线期 |
| T16 | ✅ | 2026-06-14 | image_crop git-dep→crop_your_image 2.0.0；CropController+Uint8List+sealed CropResult；删 pubspec git block；analyze 0 issue；真机头像裁剪待验证 |
| T17 | ✅ | 2026-06-14 | 删 image_picker/image_picker_platform_interface/wechat_camera_picker；barrel→wechat_assets_picker；attachment_handler CameraPicker→AssetPicker；9处调用点→MediaPickerCapability；Changed 20 deps；analyze 0 error；真机逐点待验证 |
| T18 | ⬜ | 长期 | |
