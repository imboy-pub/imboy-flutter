# imboyapp 降依赖架构深研报告

> 生成时间：2026-06-13 | 对应计划：`dependency-reduction.plan.md`
> 本文档覆盖 A+B 方向的四个深研子方向，供排期决策使用。

---

## 目录

1. [B 层 — 能力契约接口设计](#1-b-层--能力契约接口设计)
2. [A 层 — 组件库清单与收口规范](#2-a-层--组件库清单与收口规范)
3. [边界门禁实现方案](#3-边界门禁实现方案)
4. [分期路线与工量细化](#4-分期路线与工量细化)
5. [小团队 ROI 分析与结论](#5-小团队-roi-分析与结论)

---

## 1. B 层 — 能力契约接口设计

### 1.1 设计原则（YAGNI 优先）

**只有满足以下任一条件的能力域，才需要套契约层：**
- 重型原生依赖（依赖体积 > 500KB 或需要原生插件）
- 可替换 / 高危（未来可能换库，或存在供应链风险）
- 多处调用同一能力（≥ 3 处，值得统一入口）

**纯 UI 展示组件不套契约**——直接进 `component/ui/` 即可。

契约层只允许在 `lib/capabilities/adapters/` 里 import 第三方包，其余层完全通过接口调用。

### 1.2 复用现有插件架构

项目已有 `lib/plugins/contracts/AppPlugin` 接口和 `PluginRegistry<T>` 泛型注册表，能力契约层沿用同一思路，但**不混入插件注册表**——能力是基础设施（启动时单例），插件是功能扩展（按需注册），两者分层。

```
lib/
├── capabilities/
│   ├── contracts/          ← 抽象接口（只依赖 dart:core + flutter）
│   │   ├── http_capability.dart
│   │   ├── image_loader_capability.dart
│   │   ├── storage_capability.dart
│   │   ├── media_picker_capability.dart
│   │   ├── location_capability.dart
│   │   └── notification_capability.dart
│   ├── adapters/           ← 具体实现（此处可 import 第三方）
│   │   ├── dio_http_adapter.dart
│   │   ├── octo_image_adapter.dart
│   │   ├── secure_storage_adapter.dart
│   │   ├── wechat_assets_picker_adapter.dart
│   │   ├── amap_location_adapter.dart
│   │   └── firebase_notification_adapter.dart
│   └── capability_locator.dart   ← 简单服务定位器（替代 DI 框架）
└── plugins/                ← 保持现有插件体系不变
```

### 1.3 六个能力域接口草案

#### HttpCapability
```dart
// lib/capabilities/contracts/http_capability.dart
abstract interface class HttpCapability {
  Future<HttpResponse> get(String path, {Map<String, String>? headers});
  Future<HttpResponse> post(String path, {Object? body, Map<String, String>? headers});
  Future<HttpResponse> put(String path, {Object? body});
  Future<HttpResponse> delete(String path);
  Future<HttpResponse> upload(String path, String filePath, {String field = 'file'});
}

final class HttpResponse {
  const HttpResponse({required this.statusCode, required this.data, this.headers = const {}});
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
```

> **注**：当前 `dio` 已深度集成（interceptors/retry/token refresh），短期不换，HttpCapability 作为**未来换库的安全网**，先不强制所有调用走契约——仅新增代码走接口。

#### ImageLoaderCapability
```dart
// lib/capabilities/contracts/image_loader_capability.dart
abstract interface class ImageLoaderCapability {
  ImageProvider loadNetwork(String url, {int? width, int? height});
  ImageProvider loadAsset(String assetPath);
  Future<void> preload(BuildContext context, String url);
  Future<void> clearCache();
}
```

> 当前 `octo_image` + `cached_network_image` 实现，`AssetsService.viewUrl` 授权逻辑必须保留在 adapter 里。

#### StorageCapability
```dart
// lib/capabilities/contracts/storage_capability.dart
abstract interface class StorageCapability {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
  Future<Map<String, String>> readAll();
}
```

> 当前 `flutter_secure_storage` 实现；接口层只有 4 个方法，自研替代成本低（Keychain/Keystore），但现库稳定，不急换。

#### MediaPickerCapability
```dart
// lib/capabilities/contracts/media_picker_capability.dart
enum MediaType { image, video, audio, any }

final class PickedMedia {
  const PickedMedia({required this.path, required this.type, this.thumbnail});
  final String path;
  final MediaType type;
  final String? thumbnail;
}

abstract interface class MediaPickerCapability {
  Future<List<PickedMedia>> pickImages({int maxCount = 9, bool allowCamera = true});
  Future<PickedMedia?> pickVideo({Duration? maxDuration});
  Future<PickedMedia?> pickSingle(MediaType type);
}
```

> **直接受益**：阶段 3 的"媒体三合一"（image_picker + wechat_camera_picker → wechat_assets_picker）只需换 adapter，上层代码零改动。

#### LocationCapability
```dart
// lib/capabilities/contracts/location_capability.dart
final class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude, this.accuracy});
  final double latitude;
  final double longitude;
  final double? accuracy;
}

abstract interface class LocationCapability {
  Future<bool> requestPermission();
  Future<GeoPoint?> getCurrentLocation();
  Stream<GeoPoint> watchLocation({int intervalMs = 5000});
}
```

> 当前同时依赖 `amap_map_fluttify` + `geolocator`，两者功能重叠，契约层统一后可择机删一个。

#### NotificationCapability
```dart
// lib/capabilities/contracts/notification_capability.dart
abstract interface class NotificationCapability {
  Future<bool> requestPermission();
  Future<void> show({required String title, required String body, String? payload});
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Stream<String> get onTap; // payload stream
}
```

> 当前 `firebase_messaging` + `jverify`（极光），Adapter 封装两者差异。

### 1.4 CapabilityLocator（服务定位器）

不引入额外 DI 框架——用最简单的静态单例注册：

```dart
// lib/capabilities/capability_locator.dart
final class CapabilityLocator {
  CapabilityLocator._();
  static final _instance = CapabilityLocator._();
  static CapabilityLocator get I => _instance;

  final _registry = <Type, Object>{};

  void register<T extends Object>(T impl) => _registry[T] = impl;

  T get<T extends Object>() {
    final impl = _registry[T];
    if (impl == null) throw StateError('Capability $T not registered');
    return impl as T;
  }
}
```

在 `run.dart` 启动时注册（紧接 `ProviderContainer` 注入之后）：

```dart
// run.dart（仅示意，不影响现有结构）
CapabilityLocator.I
  ..register<HttpCapability>(DioHttpAdapter(dio))
  ..register<MediaPickerCapability>(WechatAssetsPickerAdapter())
  ..register<LocationCapability>(AmapLocationAdapter());
```

业务层调用：
```dart
// 在 lib/modules/ 或 lib/page/ 中（不直接 import dio / wechat_assets_picker）
final picker = CapabilityLocator.I.get<MediaPickerCapability>();
final images = await picker.pickImages(maxCount: 9);
```

---

## 2. A 层 — 组件库清单与收口规范

### 2.1 现状盘点

`lib/component/ui/` 当前 28 个文件已覆盖主体 UI，配合 `lib/theme/` 13 个 token 文件，家底约建七成。问题在于：部分轻量 UI 功能散落于第三方库（而非 `component/ui/`），需要"收口"而非"新建"。

### 2.2 第三方 UI 库 → 自研映射表

| 依赖包 | 当前使用点 | 替代方案 | 代码量估计 | 迁移难度 |
|---|---|---|---|---|
| `dotted_border` | `avatar_list.dart` (1 处) | `CustomPainter` 画虚线边框 | ~60 行 | 低 |
| `popup_menu` | `chat_provider.dart` (1 处) | Flutter 内置 `showMenu` | ~30 行改写 | 低 |
| `popover` | `right_button.dart` (1 处) | `showMenu` + `RelativeRect` | ~40 行改写 | 低 |
| `sliding_up_panel` | `location/widget.dart` (1 处) | `DraggableScrollableSheet` | ~80 行改写 | 中 |
| `flutter_animate` | `splash_page.dart` (1 处) | `AnimationController` + `FadeTransition` | ~50 行改写 | 低 |
| `shimmer` | 多处列表骨架屏 | `AnimatedBuilder` + `LinearGradient` + `ShaderMask` | ~120 行（抽成 `ShimmerBox` 组件） | 中 |
| `badges` | 消息角标等 | `Stack` + `Positioned` + `Container`（已有 token） | ~40 行（抽成 `BadgeWidget`） | 低 |
| `flutter_rating_bar` | 评分组件 | `GestureDetector` + `Row` + SVG 星星 | ~80 行 | 低 |

> **shimmer 说明**：频次较高，但实现本身简单（LinearGradient 动画），单独封装成 `ShimmerBox(child:)` 组件后，替换成本是统一替换 import，值得做。

### 2.3 自研组件命名与归位规范

新增自研组件统一放 `lib/component/ui/`，命名规则：

```
lib/component/ui/
├── avatar_list.dart         (已有，移除 dotted_border)
├── shimmer_box.dart         (新建，替代 shimmer)
├── badge_widget.dart        (新建，替代 badges)
├── rating_bar.dart          (新建，替代 flutter_rating_bar)
├── bubble_panel.dart        (新建，替代 sliding_up_panel → DraggableScrollableSheet)
└── ...（现有 28 个文件保持不动）
```

### 2.4 Barrel 结构

所有 `component/ui/` 对外通过一个 barrel 导出，其他层只 import barrel：

```dart
// lib/component/ui/ui.dart  (barrel)
export 'avatar_list.dart';
export 'shimmer_box.dart';
export 'badge_widget.dart';
export 'rating_bar.dart';
export 'bubble_panel.dart';
// ... 现有所有 ui 组件
```

业务层只写：
```dart
import 'package:imboy/component/ui/ui.dart';
```

不允许 `import 'package:imboy/component/ui/avatar_list.dart'`（具体文件 import），由边界门禁强制（见第 3 章）。

### 2.5 现有 component/ui/ 文件清单（28 个）对照 DESIGN.md §8

对照 DESIGN.md 第 8 章组件规范，确认覆盖情况：

| DESIGN.md §8 组件 | 现有文件 | 状态 |
|---|---|---|
| NavBar / AppBar | — | 使用系统 CupertinoNavigationBar，无需自研 |
| TabBar | — | 使用系统 CupertinoTabBar |
| Cell / ListTile | `list_item.dart`（待确认） | 基本覆盖 |
| Button（主/次/危险） | `button_widget.dart`（待确认） | 基本覆盖 |
| Input / TextField | — | 使用系统 CupertinoTextField，加 token 样式 |
| Modal / Bottom Sheet | — | 迁入 `bubble_panel.dart`（DraggableScrollableSheet） |
| Alert / Dialog | — | 使用系统 `showCupertinoDialog` |
| ChatBubble（发/收） | `chat/chat_bubble_*.dart` | 已有，在 chat/ 子目录 |
| Avatar | `avatar.dart` / `avatar_list.dart` | 已有 |
| Badge | — | **待新建** `badge_widget.dart` |
| Shimmer 骨架屏 | — | **待新建** `shimmer_box.dart` |
| 评分 | — | **待新建** `rating_bar.dart`（若有使用） |

---

## 3. 边界门禁实现方案

### 3.1 目标

CI 强制检查：`lib/modules/**` 和 `lib/page/**` 中的 `.dart` 文件，**不得直接 import 第三方包**（只允许 flutter 内置 + 本项目自己的包）。

违反示例（应被阻断）：
```dart
// lib/page/chat/chat_page.dart
import 'package:dio/dio.dart';             // ❌ 第三方
import 'package:shimmer/shimmer.dart';     // ❌ 第三方
import 'package:wechat_assets_picker/...'; // ❌ 第三方
```

允许示例：
```dart
// lib/page/chat/chat_page.dart
import 'package:flutter/material.dart';    // ✅ flutter 内置
import 'package:imboy/component/ui/ui.dart'; // ✅ 本项目
import 'package:imboy/capabilities/contracts/media_picker_capability.dart'; // ✅ 本项目契约
```

### 3.2 白名单定义

```
# 允许在任意层出现的 import 前缀（正则）
whitelist:
  - ^dart:
  - ^flutter/
  - ^flutter_localizations/
  - ^imboy/           # 本包自身
  # 以下仅允许出现在 lib/capabilities/adapters/ 和 lib/plugins/builtin/
  # 其余层禁止
```

### 3.3 实现方案 A：自定义 Dart 脚本（推荐，零依赖）

参考 `imboy` 后端已有 `check_module_boundaries` 脚本思路，用 Dart 写同等工具：

```dart
// scripts/check_boundaries.dart
import 'dart:io';

const _restrictedDirs = ['lib/modules', 'lib/page'];
const _allowedPrefixes = ['dart:', 'flutter/', 'flutter_localizations/', 'package:imboy/'];

void main() {
  var violations = 0;
  for (final dir in _restrictedDirs) {
    final files = Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ')) continue;
        // 提取包名
        final match = RegExp(r"import '(package:[^/']+)").firstMatch(line);
        if (match == null) continue;
        final pkg = match.group(1)!;
        final isAllowed = _allowedPrefixes.any((p) => pkg.startsWith('package:${p.replaceAll('/', '')}') || line.contains(p));
        if (!isAllowed) {
          stderr.writeln('VIOLATION ${file.path}:${i + 1}: $line');
          violations++;
        }
      }
    }
  }
  if (violations > 0) {
    stderr.writeln('\n$violations boundary violation(s) found.');
    exit(1);
  }
  stdout.writeln('Boundary check passed.');
}
```

运行命令：
```bash
dart scripts/check_boundaries.dart
```

### 3.4 实现方案 B：import_lint（可选，配置式）

`package:import_lint` 支持通过 `analysis_options.yaml` 声明式配置导入规则：

```yaml
# analysis_options.yaml 追加
import_lint:
  rules:
    no_third_party_in_page:
      target_file_path: 'lib/page/**'
      not_allow_imports:
        - 'package:(?!imboy|flutter|dart:).*'
    no_third_party_in_modules:
      target_file_path: 'lib/modules/**'
      not_allow_imports:
        - 'package:(?!imboy|flutter|dart:).*'
```

优点：`dart analyze` 直接报告，IDE 实时提示。
缺点：`import_lint` 是 dev_dependency，本身也是个第三方依赖（轻量，可接受）。

**推荐用方案 A（自定义脚本）**：零依赖，逻辑透明，CI 直接 `dart run`。

### 3.5 CI 集成

在 `.github/workflows/flutter-ci.yml`（或现有 CI 配置）新增一个 step：

```yaml
- name: Check module boundaries
  run: dart scripts/check_boundaries.dart
```

放在 `dart analyze` 之后、`flutter test` 之前。

**渐进式引入**：先在 CI 以 `continue-on-error: true` 收集基线（当前有多少违反），一个月内逐步修复，达到 0 后去掉 `continue-on-error` 收紧为门禁。

---

## 4. 分期路线与工量细化

### 4.1 总体排期原则

- 阶段 0~2：互相独立、低风险，可并行或连续在 1~2 周内完成（不需真机回归）
- 阶段 3：媒体重构，必须单独排期 + 真机回归，建议放在 0~2 完成后
- 阶段 4：长期监测，挂 CI，无需人工介入
- 能力契约层（B 层）：可在阶段 0~2 期间并行推进，不阻塞主线

### 4.2 分阶段工量表

| 阶段 | 任务 | 工量（人·天） | 前置依赖 | 风险闸门 | 验收命令 |
|---|---|---|---|---|---|
| **P0 纯删** | | | | | |
| P0.1 | 确认 `flyer_chat_custom_message` barrel 引用 | 0.1 | — | grep 无输出 | `grep -rn flyer_chat_custom_message lib/ plugin/` |
| P0.2 | 删 textfield_tags / filter_list / (确认后)flyer_chat_custom_message | 0.3 | P0.1 | — | `flutter pub get && dart analyze lib` 零新增 error |
| **P1 换更优库** | | | | | |
| P1.1 | flutter_markdown → flutter_markdown_plus | 0.5 | P0 完成 | API diff 核查 | `dart analyze lib` + 含 markdown 页面渲染目视检查 |
| P1.2 | 删 package:http，2 处直播信令改 dio | 0.5 | P0 完成 | — | `dart analyze lib` + 直播信令 debug 日志确认 |
| **P2 自研替代** | | | | | |
| P2.1 | dotted_border → CustomPainter 虚线边框 | 0.5 | P1 完成 | 样式目视 | `dart analyze lib` + avatar_list 页面截图 |
| P2.2 | popup_menu → showMenu（消息长按菜单） | 0.5 | P1 完成 | 交互目视 | `dart analyze lib` + 聊天页长按菜单真机 |
| P2.3 | popover → showMenu + RelativeRect | 0.5 | P1 完成 | 定位目视 | `dart analyze lib` + conversation 右按钮弹出 |
| P2.4 | sliding_up_panel → DraggableScrollableSheet | 1.0 | P1 完成 | 滑动手感 | `dart analyze lib` + 位置选择页面真机 |
| P2.5 | flutter_animate → AnimationController（启动页） | 0.5 | P1 完成 | 动画目视 | `dart analyze lib` + 冷启动动画真机 |
| P2.6 | shimmer → ShimmerBox 自研组件 | 1.0 | P1 完成 | 骨架屏目视 | `dart analyze lib` + 列表加载骨架屏真机 |
| P2.7 | badges → BadgeWidget 自研（可选） | 0.5 | P1 完成 | 角标目视 | `dart analyze lib` + 消息角标真机 |
| **P2-B 能力契约层（可并行）** | | | | | |
| P2-B1 | 建 capabilities/ 目录 + 6 个接口文件 | 0.5 | — | — | `dart analyze lib` |
| P2-B2 | MediaPickerCapability adapter（wechat_assets_picker） | 1.0 | P2-B1 | — | `dart analyze lib` |
| P2-B3 | 边界门禁脚本 `scripts/check_boundaries.dart` | 0.5 | — | — | `dart scripts/check_boundaries.dart`（基线模式） |
| P2-B4 | CI 集成门禁（continue-on-error 基线期） | 0.5 | P2-B3 | — | CI green |
| **P3 媒体重构（独立排期）** | | | | | |
| P3.1 | image_crop → crop_your_image | 1.5 | P2 完成 | 裁剪 UI 差异 | 真机头像裁剪 + 正方形输出确认 |
| P3.2 | 媒体三合一（image_picker + wechat_camera_picker → wechat_assets_picker） | 2.5 | P3.1 完成 | 8 处使用点回归 | 真机：头像/朋友圈/频道封面/聊天拍照/选图/扫码 |
| **P4 监测（长期）** | | | | | |
| P4.1 | 建 override 监测 checklist，定期 `flutter pub outdated` | 0.2 | — | — | 三闸门出现时另起计划 |

**合计估算**：
- P0~P2（含 B 层）：约 **7~9 人·天**，1 名工程师 2 周可完成
- P3：约 **4 人·天**，需单独排期 + 真机专场
- P4：长期维护，无额外人力

### 4.3 完成后收益预估

| 指标 | 当前 | P0~P2 后 | P3 后 |
|---|---|---|---|
| 直接依赖数 | 115 | ~108（-7） | ~106（-9） |
| git/path fork 依赖 | 6 | 5（-1 filter_list） | 4（-image_crop） |
| 官方废弃库 | 1（flutter_markdown） | 0 | 0 |
| 媒体选择器数量 | 3 | 3（未动） | 1（统一） |
| 边界违反数 | 未统计 | 开始统计 | 趋势收敛 |
| override 冲突链 | 3 | 3（盯上游） | 3（闸门未到） |

---

## 5. 小团队 ROI 分析与结论

### 5.1 各层难度与 ROI 对比

| 层级 | 对标 | 难度 | ROI |
|---|---|---|---|
| L1 自渲染引擎（Lynx/Flutter） | 字节 Lynx、Google Flutter | 极高（数十工程师×年） | **负**（Flutter 已提供，重复建设） |
| L2 Widget 框架（Material/Cupertino） | Flutter 官方组件 | 高 | **负**（Flutter 已提供） |
| **L3 设计系统 / 组件库（A 层）** | **本项目已建七成** | **中**（收口 ≠ 新建） | **正**（降依赖 + 统一视觉） |
| **L4 能力契约层（B 层）** | **Ports/Adapters 模式** | **低**（接口 + 适配器，无算法） | **正**（解耦，换库成本下降 80%） |

### 5.2 ROI 临界点规则

> **只有当"库的供应链/维护风险" > "自研/换库成本"时，才动手。**

| 依赖类型 | 动作 | 理由 |
|---|---|---|
| 官方废弃（flutter_markdown） | **必换** | 维护风险已是现实 |
| git fork 上游 3 年无活动（image_crop） | **必换** | 供应链风险高 |
| 1 处使用 < 100 行可替代（dotted_border 等） | **自研** | 成本低于长期维护第三方 |
| 复杂交互 / 加密 / 原生通道 | **保留** | 自研成本远超维护成本 |
| 核心框架（riverpod/go_router/dio） | **绝不动** | 替换成本 = 重写整个 app |

### 5.3 结论

**正确规模**：1 名工程师，兼职（30% 时间），3~4 个月，完成 P0~P3。

**不要做的事**：
- 不要把降依赖变成全面重写——只处理有明确 ROI 的包
- 不要在没有边界门禁的情况下开始迁移——迁完立刻腐化
- 不要同时推进 A 层（UI 自研）和 B 层（契约接口）和 P3（媒体重构）——三线并行容易失控

**推荐启动顺序**：
```
P0 纯删（0.5天）
  → P1 换库（1天）
    → P2 自研（4~5天）+ P2-B3门禁脚本（并行，0.5天）
      → P2-B4 CI集成（0.5天）
        → [观察1~2周] → P3 媒体重构（4天，独立排期）
```

---

## 附录：参考命令速查

```bash
# 进入 imboyapp 仓库
cd /Users/leeyi/project/imboy.pub/imboyapp

# 静态分析基线
dart analyze lib 2>&1 | tail -20

# 查看某包的所有使用点
grep -rn "package:shimmer" lib/

# 查看依赖树
flutter pub deps --style=compact | grep -A2 shimmer

# 当前直接依赖数
grep -c "^  [a-z]" pubspec.yaml

# 运行边界门禁脚本（开发完后）
dart scripts/check_boundaries.dart

# 包体积对比（阶段前后各跑一次）
flutter build apk --analyze-size 2>&1 | grep "app-release.apk"
```
