# ImBoy App — Design System

> 本文档是 ImBoy Flutter 客户端（`imboyapp`）的视觉与交互设计规范。
> **AI Coding Agent 阅读此文档后，生成的 UI 应自动符合下述规范。**
>
> 最后更新：2026-04-10
> 风格方向：**iOS 原生感（Material 3 + iOS Human Interface Guidelines 美学）**
> 基础参考：[Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)

---

## 0. 目录

1. 设计哲学（Principles）
2. 色彩系统（Colors）
3. 字体系统（Typography）
4. 间距与栅格（Spacing & Grid）
5. 圆角与阴影（Radius & Elevation）
6. 动效系统（Motion）
7. 图标系统（Iconography）
8. 组件规范（Components）
9. 聊天气泡规范（Chat Bubbles）
10. 暗色模式（Dark Mode）
11. 可访问性（Accessibility）
12. 与现有 Token 的兼容映射（Compatibility）
13. AI Agent 使用指引（For Coding Agents）

---

## 1. 设计哲学 | Principles

ImBoy 是一款跨平台即时通讯应用。设计目标是**让 iOS 用户感到"这就是一个 iOS App"，同时让 Android 用户感到"这是一个精致、克制、优先内容的 App"**。

### 核心原则

1. **Clarity（清晰）** — 排版、图标、色彩共同服务于可读性；禁用任何装饰性噪音。
2. **Deference（让位）** — UI 让位于内容。聊天气泡、头像、文字永远是主角，chrome（壳）要克制。
3. **Depth（层次）** — 通过半透明、层叠（sheet）、圆角卡片建立层次，而不是通过重投影或色块。
4. **Consistency（一致）** — 同一种交互在全局表现一致（如 push/pop 动效、返回手势、Cell 点击反馈）。
5. **Feedback（反馈）** — 每一次点击必须在 100ms 内有可见反馈；异步操作必须有 loading 状态。

### 禁用项（Banned）

- 渐变色块背景（登录页、Banner 除外，且需克制）
- 毛玻璃滥用（仅用于 Navigation Bar、Tab Bar、Modal Sheet）
- 深色投影（iOS 不使用硬阴影，用分隔线或 surfaceContainer 替代）
- 非系统字体（除非项目有正式授权）
- 过度 Material Ripple（改用 iOS 风格的 opacity 反馈）

---

## 2. 色彩系统 | Colors

### 2.1 品牌色与系统色策略（Dual-Color Strategy）

ImBoy 采用**双蓝策略**：

| 角色 | Token | 值 | 用途 |
|------|-------|-----|------|
| **品牌蓝** `brand` | `AppColors.primary` | `#2474E5` | Logo、启动页、Tab 选中态、主按钮（Primary Button）、发送消息气泡背景、FAB |
| **iOS 系统蓝** `systemBlue` | `AppColors.iosBlue` | `#007AFF` | 链接文本、Cell 右侧箭头/时间标签、顶部栏「取消/完成」文字按钮、Date/Time Picker、Switch 开启态 |

> **为什么分两个蓝？** `#2474E5` 是产品已定的品牌色（2026-01-15 决策，替代原 `#059669` 绿），承载识别；`#007AFF` 是 iOS 原生系统蓝，承载「系统语义」。两者色相接近，视觉上和谐共存。
>
> **决策规则**：**凡是 iOS 原生 App 里用 `#007AFF` 的位置，ImBoy 也用 `#007AFF`；凡是承载「ImBoy 品牌身份」的位置，用 `#2474E5`。**

### 2.2 浅色模式调色板（Light Palette）

```
Brand / Primary
  brand               #2474E5   品牌蓝（logo、主按钮、发送气泡、Tab 选中）
  brandLight          #E3F2FD   品牌蓝 10% 背景（Chip、Tag 底色）
  brandDark           #1565C0   品牌蓝按下态
  brandContainer      #BBDEFB   Primary Container

iOS System Semantic
  iosBlue             #007AFF   系统蓝（链接、Nav 文本按钮）
  iosRed              #FF3B30   破坏性操作（删除、退出登录）
  iosGreen            #34C759   成功、在线状态
  iosOrange           #FF9500   警告
  iosYellow           #FFCC00   高亮、未读提示
  iosGray             #8E8E93   次级文字
  iosGray2            #AEAEB2
  iosGray3            #C7C7CC   分隔线默认
  iosGray4            #D1D1D6
  iosGray5            #E5E5EA   InsetGrouped 列表内分隔线
  iosGray6            #F2F2F7   分组列表页背景（关键！）

Surface
  surface             #FFFFFF   卡片、Cell、气泡（接收）
  surfaceGrouped      #F2F2F7   分组列表页背景（= iosGray6）
  surfaceElevated     #FFFFFF   Sheet、Dialog 表面
  separator           #C6C6C8   Cell 分隔线（opacity 0.36 over surface）
  separatorOpaque     #E5E5EA   纯色分隔线

Text
  label               #000000   主文本（opacity 0.85 建议用于长文）
  labelSecondary      #3C3C43   次文本（opacity 0.60）
  labelTertiary       #3C3C43   三级文本（opacity 0.30）
  labelPlaceholder    #3C3C43   占位文本（opacity 0.30）
```

### 2.3 暗色模式调色板（Dark Palette）

```
Brand / Primary
  brand               #3D8BF0   品牌蓝（暗色版，+12% 明度）
  brandContainer      #1A3A6B

iOS System Semantic (Dark)
  iosBlue             #0A84FF   系统蓝（暗色增亮）
  iosRed              #FF453A
  iosGreen            #30D158
  iosOrange           #FF9F0A
  iosYellow           #FFD60A
  iosGray             #8E8E93
  iosGray2            #636366
  iosGray3            #48484A
  iosGray4            #3A3A3C
  iosGray5            #2C2C2E   暗色列表内分隔
  iosGray6            #1C1C1E   暗色分组列表页背景

Surface
  surface             #1C1C1E   卡片、接收气泡
  surfaceGrouped      #000000   暗色分组列表页背景（纯黑，OLED 友好）
  surfaceElevated     #2C2C2E   Sheet、Dialog 表面
  separator           #545458   (opacity 0.65)
  separatorOpaque     #38383A

Text
  label               #FFFFFF   主文本
  labelSecondary      #EBEBF5   (opacity 0.60)
  labelTertiary       #EBEBF5   (opacity 0.30)
  labelPlaceholder    #EBEBF5   (opacity 0.30)
```

### 2.4 颜色使用规则（Do / Don't）

- ✅ 主按钮文字 on `brand` 永远用 `#FFFFFF`
- ✅ Cell 里可点击的次级动作（如「查看全部 >」）用 `iosBlue`，不用 `brand`
- ✅ 破坏性动作（Delete、Logout）必须用 `iosRed`，不能用自定义红
- ❌ 不要在同一屏幕同时出现 `brand` 的背景 + `iosBlue` 的大面积色块，会打架
- ❌ 不要用透明度 < 0.30 的文字作为正文（违反可访问性）
- ❌ 不要在暗色模式下直接用浅色模式的颜色，必须查 Dark Palette 对应值

---

## 3. 字体系统 | Typography

### 3.1 字体栈（Font Stack）

```yaml
iOS:
  primary:   "SF Pro Text" / "SF Pro Display"   # 系统默认，无需声明
  cjk:       "PingFang SC"                       # iOS 内置中文字体

Android:
  primary:   "Roboto"                            # 系统默认
  cjk:       "HarmonyOS Sans SC"                 # 优先
  fallback:  "Source Han Sans SC" / "Noto Sans SC"

macOS:
  primary:   "SF Pro Text"
  cjk:       "PingFang SC"
```

> **Flutter 实现**：不在 `pubspec.yaml` 中捆绑 SF Pro（授权不允许分发）。直接不声明 `fontFamily`，Flutter 会用 iOS 系统默认；Android 端在 `theme.dart` 中设置 `fontFamily: 'HarmonyOS Sans'`（需要将 HarmonyOS Sans 或 Source Han Sans 打入 `assets/fonts/`）。
>
> **当前项目现状**：`FontTypes.fontFamily = 'PingFang SC'` — 这在 iOS 上工作完美，在 Android 上会 fallback。建议改为平台分支：iOS 不设 fontFamily、Android 设 `HarmonyOS Sans`。

### 3.2 Type Scale（对齐 iOS HIG + 现有 FontSizeType）

| 语义 | iOS HIG | 现有 `FontSizeType` | 字重 | 行高 | 字距 | 用途 |
|------|---------|---------------------|------|------|------|------|
| Large Title | 34pt | — | 700 | 41 | 0.37 | 页面大标题（Nav Large） |
| Title 1 | 28pt | — | 700 | 34 | 0.36 | 一级标题 |
| Title 2 | 22pt | — | 700 | 28 | 0.35 | 二级标题 |
| Title 3 | 20pt | `xLarge` | 600 | 25 | 0.38 | 卡片标题、Modal 标题 |
| Headline | 17pt | — | 600 | 22 | -0.41 | Cell 主文字、按钮文字 |
| Body | 17pt | — | 400 | 22 | -0.41 | **聊天正文**、段落 |
| Callout | 16pt | `medium` | 400 | 21 | -0.32 | 副文本 |
| Subheadline | 15pt | — | 400 | 20 | -0.24 | Cell 副标题 |
| Footnote | 13pt | — | 400 | 18 | -0.08 | 时间戳、版权 |
| Caption 1 | 12pt | `small` | 400 | 16 | 0 | 辅助信息 |
| Caption 2 | 11pt | — | 400 | 13 | 0.07 | Tab Bar 文字 |

> **与现有 FontSizeType 的映射**：`tiny(10) / small(12) / normal(14) / medium(16) / large(18) / xLarge(20) / xxLarge(24)`
>
> 现有系统偏 Material 2dp 刻度，iOS HIG 偏 17pt 基准。**短期策略**：不修改现有 `FontSizeType` 枚举（避免大规模重构），但在新页面使用时，优先把「正文」从 `normal(14)` 升到 `medium(16)` 或 `large(18)`，更接近 iOS 17pt 的阅读观感。

### 3.3 字重规则

- **禁止使用 w300 / Thin**（小字号下可读性差）
- **Body 一律 w400**；强调用 w600；标题用 w600 或 w700
- **w500 仅用于 Callout/Subheadline 的次强调**，不与 w600 混用

### 3.4 排版细节

- 中文行高按字号 1.4–1.5 倍；英文 1.25–1.35 倍
- 多语言混排时，用 `TextStyle.height` 统一到 1.4
- 数字优先等宽：`fontFeatures: [FontFeature.tabularFigures()]` — 用于时间戳、未读数

---

## 4. 间距与栅格 | Spacing & Grid

### 4.1 基础单位

**基础单位 = 4pt**（对齐现有 `app_spacing.dart` 的 4px 基数）

```
space0    0    不可见
space1    4    图标与文字最小间距
space2    8    Cell 内元素基础间距
space3    12   Cell 上下 padding
space4    16   ⭐ 页面水平 padding（iOS 标准）
space5    20
space6    24   Section 间距
space7    32   大 Section 间距
space8    40
space9    48   空状态图 + 文字
space10   64   Hero 区域
```

### 4.2 iOS 标准约定（必须遵守）

| 位置 | 值 |
|------|---|
| 页面水平 padding | **16pt**（屏幕宽 ≥ 375） |
| 安全区顶部偏移 | 遵循 `SafeArea`，不写死 |
| Cell 左 padding | 16pt |
| Cell 图标后文字间距 | 12pt |
| Cell 内上下 padding | 最小 11pt，目标 44pt 高度 |
| List Section 间距 | 35pt（InsetGrouped 列表） |
| Button 内边距 | 水平 16pt，垂直 11pt（Medium） |
| Modal Sheet 顶部 Grabber 边距 | 5pt |

### 4.3 最小点击区域（Tap Targets）

**任何可点击元素最小可触区域 44×44pt**（iOS HIG 硬指标）。
- 图标按钮 24pt 图标 + 10pt padding = 44pt 总点击区
- IconButton 在 AppBar 中至少 44pt 宽

---

## 5. 圆角与阴影 | Radius & Elevation

### 5.1 圆角规范

| Token | 值 | 用途 |
|-------|----|------|
| `radiusSmall` | 6 | Tag、Chip、小 Badge |
| `radiusMedium` | 10 | ⭐ iOS Cell 单元圆角（InsetGrouped） |
| `radiusLarge` | 14 | 普通按钮、卡片 |
| `radiusXLarge` | 20 | ⭐ **聊天气泡**（iOS 17+ 视觉） |
| `radiusSheet` | 10 | Modal Sheet 顶部（仅左右上） |
| `radiusCircle` | 999 | 头像、FAB |

### 5.2 iOS 不用重阴影

**iOS 风格极少使用 `BoxShadow`**。取代方案：

- **分隔**：用 1pt `separator` 线 或 `surfaceGrouped` 背景对比
- **层级**：用不同的 `surface` / `surfaceElevated` / `surfaceGrouped` 背景色
- **浮起**：仅 FAB、Toast、Tooltip 使用极淡投影 `0 2 8 rgba(0,0,0,0.08)`

> **与现有 `app_shadows.dart` 的冲突**：现有 elevation 0-16 基于 Material。新规范下，**只保留 elevation 0/1/2**（0=无影；1=Cell 微分隔；2=FAB/Toast）。elevation 3+ 的卡片应改为 `surfaceElevated` 背景 + 分隔线。

---

## 6. 动效系统 | Motion

### 6.1 Duration（对齐 `app_duration.dart`）

| Token | 值 | 用途 |
|-------|----|------|
| `durationInstant` | 100ms | 按下反馈（opacity） |
| `durationFast` | 200ms | Cell 展开、Tooltip |
| `durationNormal` | 300ms | ⭐ Push/Pop 页面切换 |
| `durationSlow` | 400ms | Modal Sheet 升起 |
| `durationXSlow` | 600ms | 引导动画、空态过渡 |

### 6.2 Curves（对齐 `app_curves.dart`，选用 iOS 风格曲线）

```dart
// 推荐使用现有 11 条曲线中的这 4 条
iosDefault       = Cubic(0.25, 0.1, 0.25, 1.0)     // 类似 easeInOutCubic
iosSpring        = Cubic(0.32, 0.72, 0.0, 1.0)     // iOS 系统 spring 的近似
iosDecelerate    = Cubic(0.0, 0.0, 0.2, 1.0)       // 进入动画
iosAccelerate    = Cubic(0.4, 0.0, 1.0, 1.0)       // 离开动画
```

### 6.3 转场（Page Transitions）

- **iOS**：`CupertinoPageTransitionsBuilder`（右推入、左滑返回）
- **Android**：可保留 Material Zoom，但推荐用 `CupertinoPageTransitionsBuilder` 统一体验
- **Modal**：`showCupertinoModalPopup` / 自定义 `showModalBottomSheet` + `borderRadius: top 10pt`

### 6.4 点击反馈规则

- **禁用 Material Ripple** 在 Cell / ListTile 中
- 用 `opacity 0.4` 的短暂闪烁（100ms）替代
- 参考 `CupertinoButton` 的 pressed 状态

---

## 7. 图标系统 | Iconography

### 7.1 图标源

- **iOS**：SF Symbols（系统内置，通过 `CupertinoIcons`）
- **Android**：Material Symbols（通过 `Icons`）
- **自定义**：`assets/fonts/iconfont.ttf`（现有）

### 7.2 图标规范

| 场景 | 尺寸 |
|------|------|
| Tab Bar | 28×28pt |
| Nav Bar 按钮 | 24×24pt |
| Cell Leading | 24×24pt 或 28×28pt（圆形背景时） |
| Cell Trailing Chevron | 13×22pt（用 `CupertinoIcons.chevron_right`） |
| 空状态 Hero | 64×64pt |

### 7.3 图标色

- 默认：`labelSecondary`（次文字灰）
- 选中 / 激活：`brand`
- 导航栏文字按钮图标：`iosBlue`
- 破坏性：`iosRed`

---

## 8. 组件规范 | Components

### 8.1 Navigation Bar（导航栏）

```
Layout:
  - 高度 44pt（标准）/ 96pt（Large Title 模式）
  - 背景 surface + BackdropFilter blur 20
  - 底部 0.33pt separator
  - 左：返回箭头（CupertinoIcons.back）+ 可选上页标题文字
  - 中：标题 Headline 17pt w600
  - 右：文字按钮（iosBlue）或图标按钮

规则:
  - 标题左对齐（iOS 17 Large Title）或居中（Compact）
  - 滚动时 Large Title 自动收缩到 Compact
  - 文字按钮用 Body 17pt w400 iosBlue
  - 破坏性按钮用 iosRed
```

### 8.2 Tab Bar（底部导航）

```
Layout:
  - 高度 49pt + 安全区
  - 背景 surface + BackdropFilter blur
  - 顶部 0.33pt separator
  - 4-5 个 Tab，等宽分布
  - 图标 28pt + Caption 2 11pt 文字

状态:
  - 未选中：labelSecondary
  - 选中：brand （品牌蓝，不是 iosBlue）
  - Badge：iosRed 圆点或数字
```

### 8.3 List Cell（列表单元格）

**两种样式**：

**A. Plain List**（聊天会话列表、联系人列表）
```
- 无外圆角，满宽
- surface 背景
- 左 16pt padding，右 16pt padding
- 行高 ≥ 64pt（带头像）/ ≥ 44pt（纯文字）
- 左图标/头像后 12pt 间距
- 底部 0.33pt separator，从左 16+56（头像宽度）+12 = 84pt 起始
```

**B. Inset Grouped List**（设置页、个人信息页）
```
- 容器：surfaceGrouped 背景
- 内 Cell：surface 背景，radiusMedium 10pt
- Cell 左右 16pt margin
- Section Header：footnote 13pt labelSecondary，上下 padding 20/6
- 组内 Cell 无独立圆角，仅第一个/最后一个圆角
```

### 8.4 Button

**Primary Button**
```
- 背景 brand (#2474E5)
- 文字 #FFFFFF, Headline 17pt w600
- 高度 50pt, 圆角 14pt
- 宽度：页面级按钮满宽减 16pt 两侧 padding
```

**Secondary Button**
```
- 背景 brandLight (#E3F2FD)
- 文字 brand, Headline 17pt w600
- 高度 50pt, 圆角 14pt
```

**Text Button**（用于 Nav Bar、Modal）
```
- 无背景
- 文字 iosBlue, Body 17pt w400（确认态 w600）
- 点击区域 44×44pt
```

**Destructive Button**
```
- 背景 iosRed 或白底 + iosRed 文字
- 文字 #FFFFFF, Headline 17pt w600
```

### 8.5 Input / TextField

```
- 高度 44pt
- 背景 surfaceGrouped（iosGray6）
- 圆角 10pt
- 内边距 12pt
- 占位文字 labelPlaceholder
- 聚焦态：无边框，不用 Material underline
- 清除按钮 CupertinoIcons.clear_circle_solid, iosGray
```

### 8.6 Modal Sheet

```
- 从底部升起
- 顶部 10pt 圆角
- 顶部 5pt grabber（36×5pt iosGray3 圆角条）
- 背景 surfaceElevated
- 上方遮罩 black opacity 0.35
- 动画 400ms iosSpring
```

### 8.7 Alert Dialog

- 优先使用 `CupertinoAlertDialog`
- 标题 Headline 17pt w600 居中
- 内容 Footnote 13pt 居中
- 按钮文字 Body 17pt，默认 iosBlue；破坏性 iosRed；默认态 w600
- 宽度 270pt，毛玻璃背景

---

## 9. 聊天气泡规范 | Chat Bubbles

**这是 IM App 的核心组件，必须像素级对齐 iMessage 观感。**

### 9.1 气泡几何

```
发送气泡 (Sent):
  - 背景 brand (#2474E5)   ← 用品牌蓝，不用 iosBlue
  - 文字 #FFFFFF
  - 圆角 20pt 四角（iOS 17 风格）
  - 最大宽度 屏幕宽 × 0.72
  - 右对齐，距右边 8pt
  - 同人连续消息：中间气泡不带「尾巴」，末尾气泡可带 tail

接收气泡 (Received):
  - 背景 surface 浅色 / surface 暗色 (#1C1C1E)
  - 亮色边框 0.5pt iosGray5（仅浅色模式下，暗色不要）
  - 文字 label
  - 圆角 20pt 四角
  - 最大宽度 屏幕宽 × 0.72
  - 左对齐，头像后 8pt
```

### 9.2 气泡内 padding

```
水平 12pt, 垂直 8pt
```

### 9.3 气泡间距

```
同人连续消息：间距 3pt
不同人消息：间距 12pt
时间分隔线：间距 24pt
```

### 9.4 时间分隔

```
- 样式：Caption 1 12pt labelTertiary 居中
- 格式："今天 14:23" / "昨天 09:00" / "周三 16:45" / "3月 12 日 08:00"
- 规则：相邻两条消息间隔 > 5 分钟时显示；每日首条必显示
```

### 9.5 消息状态

```
发送中：iosGray 小菊花 12×12pt，气泡右下角
已送达：double-check 图标 iosGray
已读：double-check 图标 brand
失败：红色感叹号 iosRed，点击重发
```

### 9.6 富媒体消息

- **图片**：不加气泡背景，直接圆角 14pt 卡片；多图用九宫格
- **语音**：气泡内 + 波形图 + 时长 Footnote
- **文件**：气泡内 + 文件图标 + 文件名 Subheadline + 大小 Caption 1
- **位置**：气泡内嵌地图预览卡片，radius 14pt

### 9.7 输入框（Composer）

```
- 底部固定，SafeArea 适配
- 高度最小 44pt，最大 120pt（多行展开）
- 背景 surfaceGrouped
- 输入框内圈 surface + 18pt 圆角
- 左：+ 按钮（24pt）
- 右：发送按钮 brand 圆形 32pt，未输入时变为语音按钮
- 上方 0.33pt separator
```

---

## 10. 暗色模式 | Dark Mode

### 10.1 触发与切换

- 跟随系统：`ThemeMode.system`（默认）
- 手动覆盖：设置页提供「跟随系统 / 浅色 / 深色 / OLED 纯黑」四选项
- 切换动画：200ms ease-in-out cross-fade

### 10.2 暗色映射表（关键）

| 浅色 | 暗色 |
|------|------|
| `surface` `#FFFFFF` | `surface` `#1C1C1E` |
| `surfaceGrouped` `#F2F2F7` | `surfaceGrouped` `#000000`（OLED）或 `#1C1C1E` |
| `surfaceElevated` `#FFFFFF` | `surfaceElevated` `#2C2C2E` |
| `label` `#000000` | `label` `#FFFFFF` |
| `brand` `#2474E5` | `brand` `#3D8BF0`（+12% 明度） |
| `iosBlue` `#007AFF` | `iosBlue` `#0A84FF` |
| `separator` `#C6C6C8` | `separator` `#545458` |

### 10.3 暗色专有规则

- 避免纯白文字 `#FFFFFF` 在纯黑背景 `#000000` 上的高对比度刺眼 → 用 `#EBEBF5` (opacity 0.95) 作为正文
- 气泡接收背景不要用 `#000000`，最低 `#1C1C1E`，否则气泡与背景融合
- 分隔线在暗色下必须提亮到 `#38383A` 或 `#545458`
- OLED 模式仅页面背景为纯黑，Cell/气泡仍用 `#1C1C1E`

> 现有 `AppColors.oledBackground = #000000` / `oledReceivedMessageBackground = #1A1A1A` 基本对齐此规范，轻微调优即可。

---

## 11. 可访问性 | Accessibility

### 11.1 对比度（WCAG AA）

- 正文文字与背景对比 ≥ 4.5:1
- 大字号（≥ 18pt 或 14pt w600）≥ 3:1
- 图标 ≥ 3:1
- 使用现有 `AppColors.checkContrastRatio()` 在关键组件里校验

### 11.2 动态字号

- 尊重系统字号设置（`MediaQuery.textScaleFactor`）
- 布局不能因字号放大而截断或溢出
- 使用现有 `FontScaleCalculator`

### 11.3 Reduce Motion

- 监听 `MediaQuery.disableAnimations`
- 开启时，所有 > 200ms 动画缩短为 0ms 或 100ms cross-fade
- Page Transition 改为 cross-fade

### 11.4 VoiceOver / TalkBack

- 所有 IconButton 必须有 `semanticLabel`
- 聊天气泡 `Semantics(label: "来自张三的消息: xxx，14点23分")`
- 未读红点 `semanticLabel: "5 条未读"`

### 11.5 触达区域

- 最小 44×44pt（iOS）/ 48×48dp（Android）
- 使用 `InkWell` / `GestureDetector` 的 `behavior: HitTestBehavior.opaque`

---

## 12. 与现有 Token 的兼容映射 | Compatibility

> **重要**：本 DESIGN.md **不推倒现有 `lib/theme/default/` 下的任何文件**。下表是「语义 → 现有 Token」的映射，用于新代码参考，以及未来增量优化的方向。

### 12.1 颜色映射

| 本文档语义 | 现有 Token | 需要的动作 |
|------------|-----------|-----------|
| `brand` / `primary` | `AppColors.primary` (`#2474E5`) | ✅ 已对齐 |
| `brandLight` | `AppColors.primaryLight` (`#E3F2FD`) | ✅ 已对齐 |
| `brandDark` | `AppColors.primaryDark` (`#1565C0`) | ✅ 已对齐 |
| `iosBlue` | `AppColors.iosBlue` (`#007AFF`) | ✅ 已落地（2026-04-17） |
| `iosRed` | `AppColors.iosRed` (`#FF3B30`) | ✅ 已落地 |
| `iosGreen` | `AppColors.iosGreen` (`#34C759`) | ✅ 已落地 |
| `iosGray6` / `surfaceGrouped` | `AppColors.lightSurfaceGrouped` (`#F2F2F7`) | ✅ 已落地 |
| `separator` | `AppColors.lightDivider` (`#E5E5E5`) | ⚠️ 建议调整为 `#C6C6C8` 更贴 iOS |
| 暗色 `surface` | `AppColors.darkSurface` (`#121212`) | ⚠️ 建议调整为 `#1C1C1E` |
| 暗色 `surfaceGrouped` | `AppColors.darkBackground` (`#121212`) | ⚠️ 建议新增 `#000000` (OLED) / `#1C1C1E` 两档 |
| Sent Bubble | `AppColors.lightSentMessageBackground` (= `primary`) | ✅ 已对齐 |
| Received Bubble 暗 | `AppColors.darkReceivedMessageBackground` (`#2A2A2A`) | ⚠️ 建议调为 `#1C1C1E` 更 iOS |
| Sent Bubble 暗 | `AppColors.darkSentMessageBackground` (`#42A5F5`) | ⚠️ 建议调为 `#3D8BF0` |

### 12.2 间距映射

| 本文档 Token | 现有 `AppSpacing` | 状态 |
|-------------|-------------------|------|
| `space4` (16pt) | `AppSpacing.md` 或同值 | ✅ 应已对齐 |
| Page padding 16pt | `AppSpacing.pagePadding` | ✅ |
| Cell padding 16/12pt | `AppSpacing.cardPadding` | 确认值 |

> **动作**：阅读 `lib/theme/default/app_spacing.dart`，若存在 `md=16`、`sm=12`、`lg=20`、`xl=24` 的 4pt 基数体系即视为对齐；否则仅新页面使用本文档值，不触碰旧代码。

### 12.3 圆角映射

| 本文档 | 现有 `AppRadius` | 状态 |
|-------|-----------------|------|
| `radiusMedium` (10) | `AppRadius.md` | 确认 |
| `radiusLarge` (14) | `AppRadius.lg` | 确认 |
| `radiusXLarge` (20) | `AppRadius.xl` | ⚠️ 若无需新增，**聊天气泡使用此值** |

### 12.4 字体映射

| 本文档 | 现有 `FontSizeType` | 建议 |
|-------|---------------------|------|
| Body 17pt | 无直接对应，最接近 `medium(16)` | 新页面正文用 `medium`，不新增枚举 |
| Headline 17pt w600 | `medium(16)` + `FontWeight.w600` | 可接受 |
| Footnote 13pt | `small(12)` | 可接受 |
| Caption 1 12pt | `small(12)` | ✅ |

> **结论**：**现有 Token 体系 85% 已经对齐本 DESIGN.md**。只需增量添加 `iosBlue/iosRed/iosGreen/surfaceGrouped` 和微调几个暗色值，不需要破坏性重构。

---

## 13. AI Coding Agent 使用指引 | For Coding Agents

**当你（AI Agent）被要求实现 ImBoy 客户端的任何 UI 时，按以下顺序决策：**

### 13.1 决策树

```
1. 需要「品牌识别」? (Logo, Tab 选中, 主按钮, 发送气泡)
   → 使用 AppColors.primary (#2474E5)

2. 需要「iOS 系统语义」? (链接, 取消按钮, Nav 文字按钮, Switch, Picker)
   → 使用 iosBlue (#007AFF)

3. 是破坏性操作? (删除, 退出登录, 解散群)
   → 使用 iosRed (#FF3B30)

4. 是列表页? 
   → 设置/个人中心 → Inset Grouped List (surfaceGrouped 背景 + surface 卡片 + radius 10)
   → 会话/联系人 → Plain List (surface 背景 + 分隔线)

5. 是聊天页? 
   → 参考第 9 章，气泡圆角 20pt，发送用 brand，接收用 surface

6. 是导航栏? 
   → 文字按钮 iosBlue，标题 17pt w600，底部 0.33pt separator
```

### 13.2 必须遵守的硬规则

- ❌ **禁止** 在代码中硬编码颜色值（`Color(0xFF007AFF)`）；必须通过 `AppColors.xxx`
- ❌ **禁止** 在 Cell / ListTile 中使用 Material Ripple；用 `CupertinoListTile` 或 opacity 反馈
- ❌ **禁止** 聊天气泡使用除 `brand` / `surface` 之外的背景色
- ❌ **禁止** 文字按钮使用 `primary`（用 `iosBlue`）
- ❌ **禁止** 硬编码 spacing；使用 `AppSpacing.*`
- ❌ **禁止** 任何附件 URL 直接使用；必须 `AssetsService.viewUrl()` —— 详见 `imboyapp/CLAUDE.md`
- ✅ **必须** 新按钮最小高度 50pt（Primary）或 44pt（Text Button）
- ✅ **必须** 可点击区域最小 44×44pt
- ✅ **必须** 暗色模式对应颜色从第 10.2 节查表
- ✅ **必须** 页面水平 padding = 16pt

### 13.3 生成新页面的模板

```dart
// 一个合规的 ImBoy 页面骨架
Scaffold(
  backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
  appBar: AppBar(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(color: Colors.transparent),
      ),
    ),
    title: Text(
      '标题',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    ),
    leading: CupertinoButton(
      padding: EdgeInsets.zero,
      child: Icon(CupertinoIcons.back, color: AppColors.primary), // 或 iosBlue 按语义
      onPressed: () => Navigator.pop(context),
    ),
  ),
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: /* content */,
    ),
  ),
)
```

### 13.4 修改已有页面的优先级

1. **不改颜色语义**：不要把已用 `primary` 的地方改成 `iosBlue`，除非语义明确错误
2. **不批量改字号**：现有 `FontSizeType` 保持原样，新组件才按 iOS scale
3. **分隔线优先统一**：`lightDivider` 全局改 `#C6C6C8` 风险最低、收益最大
4. **气泡圆角升级**：把现有聊天气泡圆角从 X → 20pt，是单点可控改动

### 13.5 自查清单（每个 PR 必过）

- [ ] 没有硬编码 Color / padding / fontSize
- [ ] 没有违反 44×44pt 最小触达
- [ ] 破坏性操作用 `iosRed`，而非自定义红
- [ ] 暗色模式查表并验证对比度
- [ ] VoiceOver 标签完整
- [ ] 动画 duration ≤ 400ms（除引导）
- [ ] 测试过 Android 真机（项目规则要求）

---

## 附录 A：与 getdesign.md 的关系

本 DESIGN.md 结构参考了 [getdesign.md](https://getdesign.md/) 的社区模板，但内容完全基于 **Apple Human Interface Guidelines**（公开免费）、项目现有的 `lib/theme/default/` Token 体系、以及 IMBoy 的产品历史决策（2026-01-15 品牌蓝决议）原创撰写。

未来若有余力，可将此文件贡献回 getdesign.md 作为「iOS-native IM」类别的参考实现。

## 附录 B：参考链接

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- Apple Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Apple Color: https://developer.apple.com/design/human-interface-guidelines/color
- SF Symbols: https://developer.apple.com/sf-symbols/
- iOS Semantic Colors 完整清单: https://developer.apple.com/documentation/uikit/uicolor/standard_colors
- Flutter Cupertino Widgets: https://docs.flutter.dev/ui/widgets/cupertino

## 附录 C：版本与演进

| 版本 | 日期 | 变更 |
|------|------|------|
| 0.1 | 2026-04-10 | 初版，确立 iOS 原生感方向 + 双蓝策略 |
| 0.2 | 2026-04-24 | Slice-10~18 排版 / 色彩 / 数字等宽批量落地（详见下表） |

### 0.2 批次明细（Slice-10 ~ Slice-18，2026-04-24）

| Slice | 范围 | 变更要点 |
|-------|------|---------|
| 10~13 | 色彩批量（§2） | `primary` / `iosBlue` / `iosGreen` / `iosOrange` / `iosRed` 语义分层在登录、联系人、会话、Tab Bar、AppBar 落地 |
| 14-C | GlassAppBar 返回按钮 | `common_bar.dart` 返回按钮改 `AppColors.getIosBlue(brightness)`（§2.1 双蓝策略：导航系统蓝） |
| 14-D | contact/ 硬编码色彩 | `contact_page` 在线状态改 `getIosGreen`/`iosOrange`/`getIosBlue`；`contact_provider` `bgColor` 改 `iosOrange`/`iosGreen`/`iosBlue`；`add_friend_page` 扫码图标改 `iosBlue`（§2.4 语义色） |
| 15 | 数字键盘字重 + enum 弃用 | `numeric_keypad` Thin → w400 Body（§3.3 禁 w300）；`FontSizeType` 给 `thin/extraLight/light` 加 `@Deprecated` 注释 |
| 16 | w500/w600 混用整改 | `feedback_page.dart` 反馈内容 16pt 改 w400（§3.2 Body），保留合理的标题 w600 + caption w500 并列 |
| 17 | `FontFeature.tabularFigures()` | 会话列表时间戳 / web 版未读徽章 / 朋友圈通知时间戳（§3.4 数字优先等宽） |
| 18 | 行高补齐 | `messageMsgWidget` 引用/搜索预览 Body 加 `height: 1.4`（§3.4 CJK 1.4-1.5）；其他多行 body 经审计已均有 height |

**未来演进约束**：
- 颜色/字号/间距等「tokens」变更必须在此文档先落地，再改代码
- 破坏性变更（如替换品牌色）必须先在 `lib/theme/default/CLAUDE.md` 的 Changelog 中记录决策与原因
- 本文档是**产品级契约**，不是草稿

---

**End of DESIGN.md**
