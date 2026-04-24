# 主题系统文档

[根目录](../../CLAUDE.md) > [lib](../) > **theme**

> 最后更新：2026-02-18 07:35:00 CST

---

## 变更记录 (Changelog)

### 2026-04-10
- **新增 iOS 系统语义色（双蓝策略）**：
  - 在 `app_colors.dart` 新增 `iosBlue / iosRed / iosGreen / iosOrange / iosYellow` 及其暗色版
  - 新增 iOS 中性灰阶 `iosGray / iosGray2-6 / iosSeparator / iosSeparatorDark`
  - 新增 `lightSurfaceGrouped (#F2F2F7)` / `darkSurfaceGrouped (#1C1C1E)` / `darkSurfaceGroupedOled (#000000)`
  - 新增工具方法 `getIosBlue / getIosRed / getIosGreen / getIosSeparator / getSurfaceGrouped`
- **策略说明**：品牌蓝 `#2474E5` 保留为品牌识别位置，iOS 系统蓝 `#007AFF` 用于系统语义位置（链接、Nav 按钮、取消按钮）
- **零破坏**：所有现有 Token 原样保留；新代码可选用 iOS 语义色
- **完整规范**：参见 [`../../DESIGN.md`](../../DESIGN.md)

### 2026-02-18
- **死代码清理**：删除已废弃的 `app_text_size.dart`（已完全迁移到 `FontSizeType`）
- 移除文档中对废弃文件的引用

### 2026-01-14
- 新增 Design Token 系统（app_spacing, app_radius, app_shadows 等）
- 更新颜色命名规范（primary 代替 primaryGreen）
- 字体系统统一（使用 FontSizeType 代替 AppTextSize）
- 添加 UI/UX 设计规范文档引用

### 2026-01-05
- 初始化主题系统文档
- 完成模块结构分析

---

## 模块职责

主题系统（`lib/theme/`）负责应用的外观和样式管理，支持亮色/暗色模式切换、动态字体缩放、动态颜色等功能。

### 核心职责
- Design Token 系统定义和管理
- 主题配置和管理
- 颜色系统定义
- 字体和文本样式
- 组件主题配置
- 主题切换和持久化

---

## Design Token 系统

项目已实现完整的 Design Token 系统，位于 `lib/theme/default/` 目录：

| 文件 | 描述 | 状态 |
|------|------|------|
| `app_colors.dart` | 颜色定义（主色、语义色、中性色等） | ✅ 已更新 |
| `app_spacing.dart` | 间距系统（4px 基数：0-48px） | ✅ 新增 |
| `app_radius.dart` | 圆角系统（4-50px） | ✅ 新增 |
| `app_shadows.dart` | 阴影系统（elevation 0-16） | ✅ 新增 |
| `app_duration.dart` | 动画时长（0-1000ms） | ✅ 新增 |
| `app_curves.dart` | 动画曲线（11种标准曲线） | ✅ 新增 |
| `app_sizes.dart` | 组件尺寸（按钮、输入框、头像等） | ✅ 新增 |
| `font_types.dart` | 字体类型（FontSizeType、FontWeight） | ✅ 已更新 |

### 使用示例

```dart
// 导入 Design Token 文件
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';

// 使用常量
Container(
  color: AppColors.primary,              // 颜色
  padding: AppSpacing.cardPadding,        // 间距
  decoration: BoxDecoration(
    borderRadius: AppRadius.borderRadiusMedium,  // 圆角
    boxShadow: AppShadows.card,           // 阴影
  ),
)
```

### 设计规范文档
- UI/UX 最小规范（统一维护）：[README.md#uiux-minimal-rules](../../README.md#uiux-minimal-rules)
- Design Token 迁移指南：[DESIGN_TOKEN_MIGRATION_GUIDE.md](../../DESIGN_TOKEN_MIGRATION_GUIDE.md)

---

## 模块结构

### 主要文件

| 文件 | 职责描述 | 状态 |
|-----|---------|------|
| `theme_manager.dart` | 主题管理器（核心） | - |
| `default/theme.dart` | 主题配置 | - |
| `default/app_colors.dart` | 颜色定义（已更新命名） | ✅ 已更新 |
| `default/app_spacing.dart` | Design Token - 间距系统 | ✅ 新增 |
| `default/app_radius.dart` | Design Token - 圆角系统 | ✅ 新增 |
| `default/app_shadows.dart` | Design Token - 阴影系统 | ✅ 新增 |
| `default/app_duration.dart` | Design Token - 动画时长 | ✅ 新增 |
| `default/app_curves.dart` | Design Token - 动画曲线 | ✅ 新增 |
| `default/app_sizes.dart` | Design Token - 组件尺寸 | ✅ 新增 |
| `default/font_types.dart` | 字体类型（已统一） | ✅ 已更新 |
| `default/config/text_theme.dart` | 文本主题 | - |
| `default/config/component_theme_manager.dart` | 组件主题管理 | - |
| `default/config/chat_theme_config.dart` | 聊天主题 | - |
| `dynamic_color_manager.dart` | 动态颜色管理 | - |

---

## 入口与启动

### ThemeManager 初始化
```dart
// lib/config/init.dart
ThemeManager.instance  // 获取单例实例

// 监听主题变化
ThemeManager.instance.addListener(() {
  // 主题变化时的处理
});
```

### 应用配置
```dart
// lib/run.dart
GetMaterialApp(
  theme: ThemeManager.instance.lightTheme,
  darkTheme: ThemeManager.instance.darkTheme,
  themeMode: getLocalProfileAboutThemeModel(),
)
```

---

## 对外接口

### ThemeManager 核心接口

```dart
class ThemeManager extends GetxController {
  // 单例
  static ThemeManager get instance;

  // 当前主题状态
  bool get isDarkMode;
  FontSizeOption get fontSizeOption;
  bool get followSystemTheme;
  bool get useDynamicColor;

  // 主题对象
  ThemeData get lightTheme;
  ThemeData get darkTheme;
  ThemeData get currentTheme;

  // 主题切换
  Future<void> toggleTheme({bool? isDark});

  // 字体管理
  double getFontSize(FontSizeType type, {BuildContext? context});
  TextStyle getTextStyle(FontSizeType type, {BuildContext? context});
  Future<void> updateFontSize(String fontSizeValue);

  // 颜色获取
  Color getThemeColor(String colorKey);
  Color getChatColor(String colorKey);

  // 动态颜色
  Future<void> detectDynamicColorSupport();
  Future<void> updateUseDynamicColor(bool useDynamic);

  // 持久化
  Future<void> loadThemePreference();
}
```

### 使用示例

#### 获取主题颜色
```dart
import 'package:imboy/theme/theme_manager.dart';

Color primaryColor = ThemeManager.instance.getThemeColor('primary');
Color bgColor = ThemeManager.instance.getThemeColor('background');
```

#### 获取文本样式
```dart
TextStyle style = ThemeManager.instance.getTextStyle(
  FontSizeType.large,
  fontWeight: FontWeight.bold,
  color: Colors.blue,
);
```

#### 切换主题
```dart
// 切换到暗色模式
await ThemeManager.instance.toggleTheme(isDark: true);

// 切换主题
await ThemeManager.instance.toggleTheme();
```

#### 更新字体大小
```dart
await ThemeManager.instance.updateFontSize('large');
```

---

## 关键依赖与配置

### 外部依赖
- `dynamic_color: ^1.7.0` - Material 3 动态颜色
- `flutter/material.dart` - Material Design

### 内部依赖
- `lib/service/storage.dart` - 存储服务
- `shared_preferences` - 持久化存储

---

## 数据模型

### FontSizeOption（字体大小选项）
```dart
class FontSizeOption {
  final String value;   // 'small', 'normal', 'large', 'extra_large'
  final String label;   // 显示标签
  final double scale;   // 缩放比例

  static const allOptions = [
    FontSizeOption.small,
    FontSizeOption.normal,
    FontSizeOption.large,
    FontSizeOption.extraLarge,
  ];
}
```

### FontSizeType（字体类型）
```dart
enum FontSizeType {
  tiny,       // 10sp
  small,      // 12sp
  normal,     // 14sp
  medium,     // 16sp
  large,      // 18sp
  xLarge,     // 20sp
  xxLarge,    // 24sp
}
```

---

## 测试与质量

### 主题测试
- 测试主题切换是否正常
- 测试字体缩放是否生效
- 测试动态颜色支持

### 质量标准
- 支持所有平台的主题切换
- 主题切换流畅无卡顿
- 字体缩放不影响布局

---

## 颜色系统

### AppColors 颜色定义

**注意**：颜色命名已更新（2026-01-14），旧命名标记为 `@Deprecated`。

#### 主色调
```dart
class AppColors {
  static const Color primary = Color(0xFF2474E5);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryContainer = Color(0xFFBBDEFB);
  static const Color onPrimaryContainer = Color(0xFF0D47A1);
}
```
> 旧命名 `primaryGreen` / `primaryGreenLight` / `primaryGreenDark` 已于早期迁移后从 `app_colors.dart` 完全移除（不再作为 `@Deprecated` 别名保留）；现用命名即上述 `primary*`。

#### 亮色主题颜色
```dart
class AppColors {
  // 表面色
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFEDEDED);
  static const Color lightSurfaceVariant = Color(0xFFE7E0EC);

  // 文本色
  static const Color lightTextPrimary = Color(0xFF1D1B20);
  static const Color lightTextSecondary = Color(0xFF49454F);
  static const Color lightTextDisabled = Color(0xFF999999);

  // 边框色
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightDivider = Color(0xFFE5E5E5);

  // 错误色
  static const Color lightError = Color(0xFFBA1A1A);

  // 聊天消息色
  static const Color lightSentMessageBackground = Color(0xFF2474E5);
  static const Color lightReceivedMessageBackground = Color(0xFFFFFFFF);
  static const Color sentMessageText = Color(0xFFFFFFFF);
  static const Color lightReceivedMessageText = Color(0xFF1D1B20);
}
```

#### 暗色主题颜色
```dart
class AppColors {
  // 表面色
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceContainer = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);

  // 文本色
  static const Color darkTextPrimary = Color(0xFFF0F0F0);
  static const Color darkTextSecondary = Color(0xFFD0D0D0);
  static const Color darkTextDisabled = Color(0xFF808080);

  // 边框色
  static const Color darkBorder = Color(0xFF606060);
  static const Color darkDivider = Color(0xFF404040);

  // 错误色
  static const Color darkError = Color(0xFFFF6B6B);

  // 聊天消息色
  static const Color darkSentMessageBackground = Color(0xFF4CD964);
  static const Color darkReceivedMessageBackground = Color(0xFF2A2A2A);
  static const Color darkReceivedMessageText = Color(0xFFF0F0F0);
}
```

---

## 字体系统

### 字体定义
```dart
class FontTypes {
  // 字体族
  static const String fontFamily = 'PingFang SC';

  // 基础字号
  static const double fontSizeTiny = 10.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeNormal = 14.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 18.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeXXLarge = 24.0;
}
```

### 字体缩放计算
```dart
class FontScaleCalculator {
  // 计算最终字体大小
  static double calculateFinalSize(
    FontSizeType type,
    FontSizeOption option, {
    BuildContext? context,
  }) {
    double baseSize = type.value;
    double scale = option.scale;
    return baseSize * scale;
  }

  // 判断是否符合可访问性标准
  static bool isAccessibleSize(double size) {
    return size >= 12.0;
  }

  // 生成预览信息
  static Map<String, dynamic> generatePreviewInfo(
    FontSizeType type,
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return {
      'base': type.value,
      'scale': option.scale,
      'final': calculateFinalSize(type, option, context: context),
    };
  }
}
```

---

## 文本主题

### TextThemeConfig
```dart
class TextThemeConfig {
  // 获取亮色主题
  static TextTheme getLightThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: option.scale * 57),
      displayMedium: TextStyle(fontSize: option.scale * 45),
      bodyLarge: TextStyle(fontSize: option.scale * 16),
      bodyMedium: TextStyle(fontSize: option.scale * 14),
      bodySmall: TextStyle(fontSize: option.scale * 12),
      // ...
    );
  }

  // 获取暗色主题
  static TextTheme getDarkThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    // 类似亮色主题
  }
}
```

---

## 聊天主题

### ChatThemeConfig
```dart
class ChatThemeConfig {
  // 获取聊天主题
  static ChatTheme getChatTheme(bool isDarkMode) {
    return ChatTheme(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      primaryColor: AppColors.primary,  // 使用新命名
      secondaryColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
      // ...
    );
  }
}
```

---

## 动态颜色

### DynamicColorManager
```dart
class DynamicColorManager {
  // 检测是否支持动态颜色
  Future<bool> isDynamicColorSupported() async {
    // Android 12+ 支持
    // 其他平台返回 false
  }

  // 获取动态颜色主题
  Future<ThemeData> getDynamicLightTheme() async {
    // 从系统壁纸提取颜色
  }

  Future<ThemeData> getDynamicDarkTheme() async {
    // 从系统壁纸提取颜色
  }

  // 获取动态颜色信息
  Future<Map<String, dynamic>> getDynamicColorInfo() async {
    return {
      'supported': await isDynamicColorSupported(),
      'primaryColor': primaryColor.value,
      // ...
    };
  }
}
```

---

## 组件主题

### ComponentThemeManager
```dart
class ComponentThemeManager {
  // 获取组件主题
  static Map<String, dynamic> getComponentTheme(bool isDarkMode) {
    return {
      'button': _getButtonTheme(isDarkMode),
      'card': _getCardTheme(isDarkMode),
      'input': _getInputTheme(isDarkMode),
      'search': _getSearchTheme(isDarkMode),
      // ...
    };
  }
}
```

---

## 主题持久化

### 存储键
```dart
class ThemeStorageKeys {
  static const String isDarkMode = 'theme_is_dark_mode';
  static const String fontSize = 'theme_font_size';
  static const String followSystem = 'theme_follow_system';
  static const String useDynamicColor = 'theme_use_dynamic_color';
}
```

### 加载和保存
```dart
// 加载主题设置
Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('theme_is_dark_mode') ?? false;
  final fontSize = prefs.getString('theme_font_size') ?? 'normal';
  // ...
}

// 保存主题设置
Future<void> _saveThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('theme_is_dark_mode', isDarkMode);
  await prefs.setString('theme_font_size', fontSizeOption.value);
  // ...
}
```

---

## 常见问题 (FAQ)

### Design Token 相关

#### Q: 如何使用 Design Token？
A:
```dart
// 导入 Design Token 文件
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

// 使用常量
Container(
  color: AppColors.primary,
  padding: AppSpacing.cardPadding,
)
```

#### Q: 如何迁移现有代码到 Design Token？
A: 参考 [DESIGN_TOKEN_MIGRATION_GUIDE.md](../../DESIGN_TOKEN_MIGRATION_GUIDE.md) 文档，其中包含详细的迁移步骤和批量替换脚本。

#### Q: 旧的颜色命名（如 primaryGreen）还能用吗？
A: **不能**。`primaryGreen` / `primaryGreenLight` / `primaryGreenDark` 已从 `app_colors.dart` 彻底删除（不再作为 `@Deprecated` 别名保留）。任何残留引用会直接触发编译错误，请迁移到 `AppColors.primary` / `primaryLight` / `primaryDark`：
```dart
// ❌ 已移除（编译错误）
AppColors.primaryGreen

// ✅ 现用命名
AppColors.primary
```

#### Q: Design Token 支持哪些类型？
A: 目前支持以下类型：
- 颜色（app_colors.dart）
- 间距（app_spacing.dart）
- 圆角（app_radius.dart）
- 阴影（app_shadows.dart）
- 动画时长（app_duration.dart）
- 动画曲线（app_curves.dart）
- 组件尺寸（app_sizes.dart）

#### Q: 如何使用 ThemeData 配置全局样式？
A: 在 `MaterialApp` 中配置 `theme` 参数：
```dart
MaterialApp(
  theme: ThemeData(
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusMedium,
      ),
    ),
  ),
)
```

---

### 主题系统相关

### Q: 如何自定义主题颜色？
A: 修改 `lib/theme/default/app_colors.dart` 中的颜色定义。

### Q: 如何添加新的字体大小选项？
A: 在 `lib/theme/default/font_types.dart` 中添加新的 `FontSizeOption`。

### Q: 如何让自定义组件支持主题？
A: 使用 `Theme.of(context)` 或 `ThemeManager.instance` 获取主题配置。

### Q: 动态颜色在哪些平台支持？
A: 目前仅 Android 12+ 支持，iOS 和其他平台会回退到静态主题。

### Q: 如何在代码中监听主题变化？
A: 使用 `ThemeManager.instance.addListener()` 监听主题变化。

---

## 相关文件清单

### Design Token 文件（新增）
- `lib/theme/default/app_colors.dart` - 颜色定义（已更新命名）
- `lib/theme/default/app_spacing.dart` - 间距系统（新增）
- `lib/theme/default/app_radius.dart` - 圆角系统（新增）
- `lib/theme/default/app_shadows.dart` - 阴影系统（新增）
- `lib/theme/default/app_duration.dart` - 动画时长（新增）
- `lib/theme/default/app_curves.dart` - 动画曲线（新增）
- `lib/theme/default/app_sizes.dart` - 组件尺寸（新增）
- `lib/theme/default/font_types.dart` - 字体类型（已更新）

### 核心文件
- `lib/theme/theme_manager.dart` - 主题管理器
- `lib/theme/default/theme.dart` - 主题配置
- `lib/theme/default/config/text_theme.dart` - 文本主题
- `lib/theme/default/config/component_theme_manager.dart` - 组件主题
- `lib/theme/default/config/chat_theme_config.dart` - 聊天主题
- `lib/theme/dynamic_color_manager.dart` - 动态颜色管理

### 资源文件
- `assets/fonts/iconfont.ttf` - 图标字体
- `assets/images/` - 主题相关图片

### 设计文档
- [README.md#uiux-minimal-rules](../../README.md#uiux-minimal-rules) - UI/UX 最小规范
- [DESIGN_TOKEN_MIGRATION_GUIDE.md](../../DESIGN_TOKEN_MIGRATION_GUIDE.md) - Design Token 迁移指南

---

**相关文档**
- [根目录文档](../../CLAUDE.md) - 项目架构文档
- [组件层文档](../component/CLAUDE.md)
- [页面层文档](../page/CLAUDE.md)
- [配置文档](../config/CLAUDE.md)
