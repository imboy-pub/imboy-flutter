# macOS 桌面端适配审计报告
# macOS Desktop Adaptation Audit Report

> 审计日期 / Audit Date: 2026-05-27
> 项目路径 / Project: `imboyapp/`
> 审计范围 / Scope: `macos/Runner/`, `lib/` 中 `Platform.isMacOS` 相关代码, `pubspec.yaml`

---

## 1. 窗口尺寸 / Window Size

**状态 / Status**: ❌ 缺失

**现状 / Current State**:
`macos/Runner/MainFlutterWindow.swift` 仅使用 `self.frame`（由 MainMenu.xib 决定），未设置最小窗口尺寸。`pubspec.yaml` 中未引入 `window_manager` 或 `bitsdojo_window`。

```swift
// 当前代码 / Current code — MainFlutterWindow.swift
let windowFrame = self.frame
self.contentViewController = flutterViewController
self.setFrame(windowFrame, display: true)
// ❌ 没有 setMinSize / setContentMinSize 调用
```

**修复建议 / Fix**:

方案一（推荐）：在 `MainFlutterWindow.swift` 的 `awakeFromNib` 中直接设置：

```swift
override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // 设置最小窗口尺寸（适合 IM 应用）
    self.minSize = NSSize(width: 800, height: 600)
    self.setContentMinSize(NSSize(width: 800, height: 600))
    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
}
```

方案二：引入 `window_manager` 包，在 `lib/main.dart` 中统一管理：

```dart
import 'package:window_manager/window_manager.dart';

if (Platform.isMacOS) {
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(800, 600));
  await windowManager.setSize(const Size(1200, 800));
}
```

---

## 2. 菜单栏 / Menu Bar

**状态 / Status**: ⚠️ 部分适配

**现状 / Current State**:
`macos/Runner/Base.lproj/MainMenu.xib` 存在，提供了 macOS 原生菜单栏的基本结构（由 Interface Builder 生成）。但 Flutter 代码层面未配置 `PlatformMenuBar` widget，无法自定义菜单项（如"文件"→新建会话、"编辑"→格式化快捷键等）。`web_shell_keyboard_intent.dart` 定义了 `Cmd+K/N/,` 快捷键意图，但这些意图只绑定在 Widget 层，未与原生菜单栏联动。

**修复建议 / Fix**:

在应用根 Widget 中接入 `PlatformMenuBar`：

```dart
// lib/page/bottom_navigation/bottom_navigation_page.dart 或根 widget
import 'package:flutter/material.dart';

class AppMenuBar extends StatelessWidget {
  final Widget child;
  const AppMenuBar({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(label: 'IMBoy', menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: '关于 IMBoy',
              onSelected: () { /* 打开关于页面 */ },
            ),
          ]),
          PlatformMenuItem(
            label: '偏好设置...',
            shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
            onSelected: () { context.push(AppRoutes.settings); },
          ),
        ]),
        PlatformMenu(label: '会话', menus: [
          PlatformMenuItem(
            label: '新建会话',
            shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
            onSelected: () { /* 新建会话 */ },
          ),
        ]),
      ],
      child: child,
    );
  }
}
```

---

## 3. 通知权限 / Notification Permissions

**状态 / Status**: ✅ 已适配

**现状 / Current State**:
`Runner.entitlements`（Release/Debug）均包含：

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

`lib/service/notification.dart` 存在本地通知服务，依赖 `flutter_local_notifications`，其 macOS 实现会自动请求用户通知权限（`UNUserNotificationCenter`）。`lib/component/helper/permission_web_stub.dart` 中有 `Platform.isMacOS` 分支处理权限适配。

**注意 / Note**: `Info.plist` 中 `NSUserNotificationsUsageDescription` 未显式配置（macOS 通知走系统级权限弹窗，无需 plist 描述字段），当前行为正常。

---

## 4. 网络权限 / Network Transport Security

**状态 / Status**: ⚠️ 部分适配（存在安全隐患）

**现状 / Current State**:
`macos/Runner/Info.plist` 中配置了：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```

`NSAllowsArbitraryLoads: true` 完全禁用 ATS，允许明文 HTTP 请求，存在安全隐患。根据 `lib/config/env_pro.dart` 等配置，生产环境 API 应全部走 HTTPS。

**修复建议 / Fix**:

生产构建中收紧 ATS 配置，仅对必要域名例外：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <!-- 如需支持本地开发 HTTP -->
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

或在 `Release.xcconfig` 中通过预处理宏区分 Debug/Release 的 ATS 策略。

---

## 5. 键盘快捷键 / Keyboard Shortcuts

**状态 / Status**: ✅ 已适配（基础实现完整）

**现状 / Current State**:
`lib/page/web_shell/web_shell_keyboard_intent.dart` 实现了平台感知的快捷键解析器，已针对 macOS 使用 `meta`（Cmd）键：

| 快捷键 | 语义 |
|--------|------|
| `Cmd+K` | 全局搜索 |
| `Cmd+N` | 新建会话 |
| `Cmd+,` | 打开设置 |
| `Esc` | 关闭右侧面板 |

设计为纯函数（`resolveShellShortcut`），可独立单测，符合 sealed 变体穷尽模式。

**待完善 / TODO**: 上述快捷键意图尚未与 macOS 原生 `PlatformMenuBar` 菜单项联动（见第 2 项）。

---

## 6. 窗口标题栏 / Window Title Bar Style

**状态 / Status**: ❌ 缺失

**现状 / Current State**:
`MainFlutterWindow.swift` 使用默认的 macOS 标题栏（`NSWindow` 默认）。未配置 `titlebarAppearsTransparent`、`toolbarStyle`、`titleVisibility` 等 macOS 特有样式。Flutter 层面未使用 `window_manager` 的 `TitleBarStyle` 定制。对于 IM 应用，业界通常采用无缝标题栏（透明标题栏 + 交通灯按钮浮层）以提升视觉质量。

**修复建议 / Fix**:

方式一：在 `MainFlutterWindow.swift` 中设置原生样式：

```swift
override func awakeFromNib() {
    // ...existing code...
    // 透明标题栏风格（类似 Slack/Discord macOS 客户端）
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    super.awakeFromNib()
}
```

方式二：引入 `window_manager` 后在 Flutter 层统一控制：

```dart
if (Platform.isMacOS) {
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setSize(const Size(1200, 800));
}
```

注意：采用透明标题栏后，Flutter 内容需在顶部留出约 28pt 的安全区，避免被交通灯按钮遮挡。可通过 `MediaQuery.of(context).padding.top` 或 `window_manager` 提供的安全区 API 处理。

---

## 综合评分 / Summary

| 适配项 | 状态 | 优先级 |
|--------|------|--------|
| 窗口最小尺寸 | ❌ 缺失 | P1 — 影响可用性 |
| macOS 菜单栏 | ⚠️ 部分适配 | P2 — 影响原生体验 |
| 通知权限 | ✅ 已适配 | — |
| 网络权限（ATS） | ⚠️ 部分适配 | P1 — 安全隐患 |
| 键盘快捷键 | ✅ 已适配 | — |
| 窗口标题栏样式 | ❌ 缺失 | P3 — 视觉质量 |

**建议行动计划 / Recommended Action Plan**:

1. **P1（本迭代）**: 在 `MainFlutterWindow.swift` 添加 `minSize`；收紧生产 ATS 配置。
2. **P2（下迭代）**: 引入 `window_manager` 包统一管理窗口状态；接入 `PlatformMenuBar` 联动快捷键意图。
3. **P3（后续优化）**: 配置透明标题栏样式，与品牌视觉统一。
