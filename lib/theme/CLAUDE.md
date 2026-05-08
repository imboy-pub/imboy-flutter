# 主题系统 (Theme Layer)

[根目录](../../CLAUDE.md) > [lib](../) > **theme**

## 文件清单

| 文件 | 职责 |
|------|------|
| `theme_manager.dart` | 主题管理器（GetxController 单例） |
| `default/theme.dart` | ThemeData 配置入口 |
| `default/app_colors.dart` | 颜色定义（品牌色 + 语义色 + iOS系统色） |
| `default/app_spacing.dart` | 间距 Token（4px基数，0–48px） |
| `default/app_radius.dart` | 圆角 Token（4–50px） |
| `default/app_shadows.dart` | 阴影 Token（elevation 0–16） |
| `default/app_duration.dart` | 动画时长 Token（0–1000ms） |
| `default/app_curves.dart` | 动画曲线（11种） |
| `default/app_sizes.dart` | 组件尺寸（按钮/输入框/头像等） |
| `default/font_types.dart` | FontSizeType 枚举、FontSizeOption |
| `default/config/text_theme.dart` | TextTheme 配置 |
| `default/config/component_theme_manager.dart` | 组件主题配置 |
| `default/config/chat_theme_config.dart` | 聊天气泡主题 |
| `dynamic_color_manager.dart` | Material 3 动态颜色（Android 12+） |

## ThemeManager API

```dart
// 单例访问
ThemeManager.instance

// 状态读取
bool isDarkMode
FontSizeOption fontSizeOption
bool followSystemTheme / useDynamicColor
ThemeData lightTheme / darkTheme / currentTheme

// 操作
await ThemeManager.instance.toggleTheme({bool? isDark});
await ThemeManager.instance.updateFontSize('large'); // 'small'|'normal'|'large'|'extra_large'
await ThemeManager.instance.updateUseDynamicColor(bool);
await ThemeManager.instance.loadThemePreference();

// 颜色 & 文字
Color getThemeColor(String colorKey)
Color getChatColor(String colorKey)
double getFontSize(FontSizeType type, {BuildContext? context})
TextStyle getTextStyle(FontSizeType type, {BuildContext? context})
```

## 应用初始化配置
```dart
// lib/run.dart
GetMaterialApp(
  theme: ThemeManager.instance.lightTheme,
  darkTheme: ThemeManager.instance.darkTheme,
  themeMode: getLocalProfileAboutThemeModel(),
)
```

## 颜色系统（AppColors）

### 双蓝策略
| 常量 | 值 | 用途 |
|------|-----|------|
| `AppColors.primary` | `#2474E5` | 品牌识别位置（保留） |
| `AppColors.iosBlue` | `#007AFF` | 系统语义位置（链接/Nav按钮/取消） |
| `AppColors.primaryLight` | `#E3F2FD` | - |
| `AppColors.primaryDark` | `#1565C0` | - |

> ⚠️ `primaryGreen` / `primaryGreenLight` / `primaryGreenDark` 已彻底删除，使用触发编译错误，迁移到 `AppColors.primary*`

### 亮色主题关键色
| 常量 | 值 |
|------|-----|
| lightSurface | `#FFFFFF` |
| lightSurfaceContainer | `#EDEDED` |
| lightSurfaceGrouped | `#F2F2F7` |
| lightTextPrimary | `#1D1B20` |
| lightTextSecondary | `#49454F` |
| lightTextDisabled | `#999999` |
| lightBorder / lightDivider | `#E5E5E5` |
| lightError | `#BA1A1A` |
| lightSentMessageBackground | `#2474E5` |
| lightReceivedMessageBackground | `#FFFFFF` |

### 暗色主题关键色
| 常量 | 值 |
|------|-----|
| darkSurface | `#121212` |
| darkSurfaceContainer | `#1E1E1E` |
| darkSurfaceGrouped | `#1C1C1E` |
| darkSurfaceGroupedOled | `#000000` |
| darkTextPrimary | `#F0F0F0` |
| darkTextSecondary | `#D0D0D0` |
| darkBorder | `#606060` |
| darkError | `#FF6B6B` |
| darkSentMessageBackground | `#4CD964` |
| darkReceivedMessageBackground | `#2A2A2A` |

### iOS 语义色（2026-04-10 新增，零破坏）
`iosRed / iosGreen / iosOrange / iosYellow` + 暗色变体；
`iosGray / iosGray2–6 / iosSeparator / iosSeparatorDark`

工具方法：`getIosBlue() / getIosRed() / getIosGreen() / getIosSeparator() / getSurfaceGrouped()`

## 字体系统

### FontSizeType（枚举）
| 值 | 基础字号 |
|----|---------|
| tiny | 10sp |
| small | 12sp |
| normal | 14sp |
| medium | 16sp |
| large | 18sp |
| xLarge | 20sp |
| xxLarge | 24sp |

字体族：`PingFang SC`

### FontSizeOption
```dart
// value: 'small'|'normal'|'large'|'extra_large'，scale: 缩放比例
FontSizeOption.allOptions  // 全部选项列表
```

## 主题持久化存储键
| 键 | 含义 |
|----|------|
| `theme_is_dark_mode` | 是否暗色模式 |
| `theme_font_size` | 字体大小 value |
| `theme_follow_system` | 跟随系统主题 |
| `theme_use_dynamic_color` | 使用动态颜色 |

## Design Token 使用示例
```dart
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_shadows.dart';

Container(
  color: AppColors.primary,
  padding: AppSpacing.cardPadding,
  decoration: BoxDecoration(
    borderRadius: AppRadius.borderRadiusMedium,
    boxShadow: AppShadows.card,
  ),
)
```

## 外部依赖
`dynamic_color ^1.7.0` · `flutter/material.dart` · `shared_preferences`（持久化）

**设计规范**：[README#uiux-minimal-rules](../../README.md#uiux-minimal-rules) · [DESIGN_TOKEN_MIGRATION_GUIDE.md](../../DESIGN_TOKEN_MIGRATION_GUIDE.md)

**相关文档**：[根目录](../../CLAUDE.md) · [组件层](../component/CLAUDE.md) · [页面层](../page/CLAUDE.md) · [配置](../config/CLAUDE.md)
