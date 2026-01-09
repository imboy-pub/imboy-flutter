# 主题系统文档

[根目录](../../CLAUDE.md) > [lib](../) > **theme**

> 最后更新：2026-01-05 14:12:27 CST

---

## 变更记录 (Changelog)

### 2026-01-05
- 初始化主题系统文档
- 完成模块结构分析

---

## 模块职责

主题系统（`lib/theme/`）负责应用的外观和样式管理，支持亮色/暗色模式切换、动态字体缩放、动态颜色等功能。

### 核心职责
- 主题配置和管理
- 颜色系统定义
- 字体和文本样式
- 组件主题配置
- 主题切换和持久化

---

## 模块结构

### 主要文件

| 文件 | 职责描述 |
|-----|---------|
| `theme_manager.dart` | 主题管理器（核心） |
| `default/theme.dart` | 主题配置 |
| `default/app_colors.dart` | 颜色定义 |
| `default/font_types.dart` | 字体类型 |
| `default/config/text_theme.dart` | 文本主题 |
| `default/config/component_theme_manager.dart` | 组件主题管理 |
| `default/config/chat_theme_config.dart` | 聊天主题 |
| `dynamic_color_manager.dart` | 动态颜色管理 |

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

#### 亮色主题颜色
```dart
class AppColors {
  // 主色调
  static const primaryGreen = Color(0xFF07C160);
  static const primaryGreenLight = Color(0xFF06AE56);

  // 背景色
  static const lightBackground = Color(0xFFEDEDED);
  static const lightSurface = Color(0xFFFFFFFF);

  // 文本色
  static const lightTextPrimary = Color(0xFF000000);
  static const lightTextSecondary = Color(0xFF999999);

  // 边框色
  static const lightBorder = Color(0xFFE5E5E5);

  // 错误色
  static const lightError = Color(0xFFFF4D4F);

  // 聊天消息色
  static const lightSentMessageBackground = Color(0xFF07C160);
  static const lightReceivedMessageBackground = Color(0xFFFFFFFF);
  static const sentMessageText = Color(0xFFFFFFFF);
  static const lightReceivedMessageText = Color(0xFF000000);
}
```

#### 暗色主题颜色
```dart
class AppColors {
  // 背景色
  static Color getDarkBackground(bool useOLED, Brightness brightness) {
    return useOLED ? Color(0xFF000000) : Color(0xFF1C1C1E);
  }

  static Color getDarkSurface(bool useOLED, Brightness brightness) {
    return useOLED ? Color(0xFF000000) : Color(0xFF2C2C2E);
  }

  // 文本色
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF999999);

  // 边框色
  static const darkBorder = Color(0xFF38383A);

  // 错误色
  static const darkError = Color(0xFFFF6B6B);

  // 聊天消息色
  static const darkSentMessageBackground = Color(0xFF06AE56);
  static const darkReceivedMessageBackground = Color(0xFF2C2C2E);
  static const darkReceivedMessageText = Color(0xFFFFFFFF);
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
      primaryColor: AppColors.primaryGreen,
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

### 核心文件
- `lib/theme/theme_manager.dart` - 主题管理器
- `lib/theme/default/theme.dart` - 主题配置
- `lib/theme/default/app_colors.dart` - 颜色定义
- `lib/theme/default/font_types.dart` - 字体类型
- `lib/theme/default/config/text_theme.dart` - 文本主题
- `lib/theme/default/config/component_theme_manager.dart` - 组件主题
- `lib/theme/default/config/chat_theme_config.dart` - 聊天主题
- `lib/theme/dynamic_color_manager.dart` - 动态颜色管理

### 资源文件
- `assets/fonts/iconfont.ttf` - 图标字体
- `assets/images/` - 主题相关图片

---

**相关文档**
- [组件层文档](../component/CLAUDE.md)
- [页面层文档](../page/CLAUDE.md)
- [配置文档](../config/CLAUDE.md)
