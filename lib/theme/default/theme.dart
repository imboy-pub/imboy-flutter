import 'package:flutter/material.dart';

import './config/app_bar_theme.dart';
import './config/app_theme_extension.dart';
import './config/button_theme.dart';
import './config/card_theme.dart';
// ComponentThemeManager 现在在 ThemeManager 中使用
import './config/input_theme.dart';
import './config/text_theme.dart';
import './font_types.dart';

import 'app_colors.dart';
import 'icon_theme.dart' show IMBoyIconTheme;
import '../dynamic_color_manager.dart';

/// 应用主题配置类
/// 统一组装各个组件的主题配置，提供完整的亮色/暗色主题
class AppTheme {
  AppTheme._(); // 私有构造函数，防止实例化

  // ==================== Material 3 形状系统配置 ====================
  /// Material 3 形状系统配置
  /// 
  /// 定义统一的圆角半径规范
  static const ShapeBorder _smallShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
  );
  
  static const ShapeBorder _mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12.0)),
  );
  
  static const ShapeBorder _largeShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16.0)),
  );
  
  static const ShapeBorder _extraLargeShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(28.0)),
  );

  // ==================== 私有辅助方法 ====================
  
  /// 创建底部导航栏主题
  static BottomNavigationBarThemeData _createBottomNavTheme({
    required Color backgroundColor,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    return BottomNavigationBarThemeData(
      backgroundColor: backgroundColor,
      selectedItemColor: selectedColor,
      unselectedItemColor: unselectedColor,
      selectedLabelStyle: TextStyle(
        color: selectedColor,
        fontFamily: 'PingFang SC',
      ),
      unselectedLabelStyle: TextStyle(
        color: unselectedColor,
        fontFamily: 'PingFang SC',
      ),
    );
  }

  /// 创建Chip主题
  static ChipThemeData _createChipTheme({
    required Color backgroundColor,
    required Color selectedColor,
    required Color labelColor,
  }) {
    return ChipThemeData(
      backgroundColor: backgroundColor,
      selectedColor: selectedColor,
      labelStyle: TextStyle(
        color: labelColor,
        fontFamily: 'PingFang SC',
      ),
    );
  }

  /// 创建进度指示器主题
  static ProgressIndicatorThemeData _createProgressTheme(Color color) {
    return ProgressIndicatorThemeData(color: color);
  }

  // ==================== 动态主题方法 ====================

  /// 获取亮色主题（支持动态字体缩放）
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  static ThemeData getLightTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTheme(isDark: false, fontScale: fontScale, context: context);
  }

  /// 获取暗色主题（支持动态字体缩放）
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  static ThemeData getDarkTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTheme(isDark: true, fontScale: fontScale, context: context);
  }

  /// 获取带动态颜色的亮色主题
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  /// [useDynamicColor] 是否使用动态颜色，默认为 true
  static Future<ThemeData> getLightThemeWithDynamicColor({
    double fontScale = 1.0,
    BuildContext? context,
    bool useDynamicColor = true,
  }) async {
    return await _buildThemeWithDynamicColor(
      isDark: false,
      fontScale: fontScale,
      context: context,
      useDynamicColor: useDynamicColor,
    );
  }

  /// 获取带动态颜色的暗色主题
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  /// [useDynamicColor] 是否使用动态颜色，默认为 true
  static Future<ThemeData> getDarkThemeWithDynamicColor({
    double fontScale = 1.0,
    BuildContext? context,
    bool useDynamicColor = true,
  }) async {
    return await _buildThemeWithDynamicColor(
      isDark: true,
      fontScale: fontScale,
      context: context,
      useDynamicColor: useDynamicColor,
    );
  }

  /// 根据 FontSizeOption 获取亮色主题
  static ThemeData getLightThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getLightTheme(fontScale: option.scale, context: context);
  }

  /// 根据 FontSizeOption 获取暗色主题
  static ThemeData getDarkThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getDarkTheme(fontScale: option.scale, context: context);
  }

  // ==================== 静态主题（向后兼容） ====================
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,

    // 1. Material 3 完整颜色方案
    colorScheme: ColorScheme.light(
      // Primary colors - 主色系
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: AppColors.greenContainer,
      onPrimaryContainer: AppColors.onGreenContainer,
      
      // Secondary colors - 次要色系
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      
      // Tertiary colors - 第三色系
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      
      // Error colors - 错误色系
      error: AppColors.lightError,
      onError: Colors.white,
      errorContainer: AppColors.lightErrorContainer,
      onErrorContainer: AppColors.lightOnErrorContainer,
      
      // Surface colors - 表面色系
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
      
      // Outline colors - 轮廓色系
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightDivider,
    ),

    // 2. 文字主题 - 引用组件配置
    textTheme: TextThemeConfig.lightTheme,

    // 3. 图标主题
    iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    primaryIconTheme: IconThemeData(color: Colors.white),

    // 4. 应用栏主题 - 引用组件配置
    appBarTheme: AppBarThemeConfig.lightTheme,

    // 5. 底部导航栏
    bottomNavigationBarTheme: _createBottomNavTheme(
      backgroundColor: AppColors.lightAppBarBackground,
      selectedColor: AppColors.primaryGreen,
      unselectedColor: AppColors.lightTextDisabled,
    ),

    // 6. 按钮主题 - 引用组件配置
    elevatedButtonTheme: ButtonThemeConfig.lightElevatedButtonTheme,
    textButtonTheme: ButtonThemeConfig.lightTextButtonTheme,
    outlinedButtonTheme: ButtonThemeConfig.lightOutlinedButtonTheme,
    floatingActionButtonTheme: ButtonThemeConfig.lightFloatingActionButtonTheme,

    // 6. 卡片主题 - Material 3 形状系统
    cardTheme: CardThemeConfig.lightTheme.copyWith(
      shape: _mediumShape,
    ),

    // 8. 输入框主题 - 引用组件配置
    inputDecorationTheme: InputThemeConfig.lightTheme,

    // 9. 其他组件主题
    dividerTheme: DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
      space: 16,
    ),
    chipTheme: _createChipTheme(
      backgroundColor: AppColors.lightCardBackground,
      selectedColor: AppColors.primaryGreen,
      labelColor: AppColors.lightTextPrimary,
    ),
    progressIndicatorTheme: _createProgressTheme(AppColors.primaryGreen),

    // 10. 自定义主题扩展
    extensions: <ThemeExtension<dynamic>>[
      IMBoyIconTheme(
        primaryIcon: IconThemeData(color: AppColors.primaryGreen, size: 24),
        surfaceIcon: IconThemeData(color: AppColors.lightTextPrimary, size: 24),
        secondaryIcon: IconThemeData(color: AppColors.info, size: 24),
        errorIcon: IconThemeData(color: AppColors.lightError, size: 24),
      ),
      AppThemeExtension.light(),
    ],
  );

  // ==================== 暗色主题 ====================
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,

    // 1. Material 3 完整颜色方案 - 暗色模式
    colorScheme: ColorScheme.dark(
      // Primary colors - 主色系
      primary: AppColors.primaryGreenLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryGreenDark,
      onPrimaryContainer: AppColors.onGreenContainer,
      
      // Secondary colors - 次要色系
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      
      // Tertiary colors - 第三色系
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      
      // Error colors - 错误色系
      error: AppColors.darkError,
      onError: Colors.black,
      errorContainer: AppColors.darkErrorContainer,
      onErrorContainer: AppColors.darkOnErrorContainer,
      
      // Surface colors - 表面色系
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
      
      // Outline colors - 轮廓色系
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkDivider,
    ),

    // 2. 文字主题 - 引用组件配置
    textTheme: TextThemeConfig.darkTheme,

    // 3. 图标主题
    iconTheme: IconThemeData(color: AppColors.primaryGreenLight),
    primaryIconTheme: IconThemeData(color: Colors.white),

    // 4. 应用栏主题 - 引用组件配置
    appBarTheme: AppBarThemeConfig.darkTheme,

    // 5. 底部导航栏
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkAppBarBackground,
      selectedItemColor: AppColors.primaryGreenLight,
      unselectedItemColor: AppColors.darkTextDisabled,
      selectedLabelStyle: TextStyle(
        color: AppColors.primaryGreenLight,
        fontFamily: 'PingFang SC',
      ),
      unselectedLabelStyle: TextStyle(
        color: AppColors.darkTextDisabled,
        fontFamily: 'PingFang SC',
      ),
    ),

    // 6. 按钮主题 - 引用组件配置
    elevatedButtonTheme: ButtonThemeConfig.darkElevatedButtonTheme,
    textButtonTheme: ButtonThemeConfig.darkTextButtonTheme,
    outlinedButtonTheme: ButtonThemeConfig.darkOutlinedButtonTheme,
    floatingActionButtonTheme: ButtonThemeConfig.darkFloatingActionButtonTheme,

    // 6. 卡片主题 - Material 3 形状系统
     cardTheme: CardThemeConfig.darkTheme.copyWith(
       shape: _mediumShape,
     ),

    // 8. 输入框主题 - 引用组件配置
    inputDecorationTheme: InputThemeConfig.darkTheme,

    // 9. 其他组件主题
    dividerTheme: DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
      space: 16,
    ),
    chipTheme: _createChipTheme(
      backgroundColor: AppColors.darkCardBackground,
      selectedColor: AppColors.primaryGreenLight,
      labelColor: AppColors.darkTextPrimary,
    ),
    progressIndicatorTheme: _createProgressTheme(AppColors.primaryGreenLight),

    // 10. 自定义主题扩展
    extensions: <ThemeExtension<dynamic>>[
      IMBoyIconTheme(
        primaryIcon: IconThemeData(color: AppColors.primaryGreen, size: 24),
        surfaceIcon: IconThemeData(color: AppColors.darkTextPrimary, size: 24),
        secondaryIcon: IconThemeData(color: AppColors.info, size: 24),
        errorIcon: IconThemeData(color: AppColors.darkError, size: 24),
      ),
      AppThemeExtension.dark(),
    ],
  );

  // ==================== 聊天相关颜色（向后兼容） ====================
  // 注意：建议使用 ChatThemeConfig 类来获取聊天主题配置

  // 亮色主题聊天颜色
  static Color get chatSendMessageBg => AppColors.lightSentMessageBackground;
  static Color get chatSentMessageText => AppColors.sentMessageText;
  static Color get chatReceivedMessageText =>
      AppColors.lightReceivedMessageText;
  static Color get chatReceivedMessageBg =>
      AppColors.lightReceivedMessageBackground;
  static Color get chatInputBg => AppColors.lightSurface;
  static Color get chatInputBorder => AppColors.lightBorder;

  // 暗色主题聊天颜色
  static Color get darkChatSendMessageBg => AppColors.darkSentMessageBackground;
  static Color get darkChatSentMessageText => AppColors.sentMessageText;
  static Color get darkChatReceivedMessageText =>
      AppColors.darkReceivedMessageText;
  static Color get darkChatReceivedMessageBg =>
      AppColors.darkReceivedMessageBackground;
  static Color get darkChatInputBg => AppColors.darkSurface;
  static Color get darkChatInputBorder => AppColors.darkBorder;

  // 聊天颜色常量（向后兼容，建议使用 ChatThemeConfig）
  static Color get chatSendMessageBgColor => chatSendMessageBg;
  static Color get chatSentMessageBodyTextColor => chatSentMessageText;
  static Color get chatReceivedMessageBodyTextColor => chatReceivedMessageText;
  static Color get chatReceivedMessageBodyBgColor => chatReceivedMessageBg;
  static Color get chatInputFillColor => chatInputBg;
  static Color get darkChatInputFillColor => darkChatInputBg;

  // ==================== 核心主题构建方法 ====================

  /// 构建主题的核心方法
  ///
  /// [isDark] 是否为暗色主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  static ThemeData _buildTheme({
    required bool isDark,
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    // 获取动态文本主题
    final textTheme = isDark
        ? TextThemeConfig.getDarkTheme(fontScale: fontScale, context: context)
        : TextThemeConfig.getLightTheme(fontScale: fontScale, context: context);

    // 获取基础主题
    final baseTheme = isDark ? _baseDarkTheme : _baseLightTheme;

    // 返回带有动态文本主题的完整主题
    return baseTheme.copyWith(textTheme: textTheme);
  }

  /// 构建带动态颜色的主题
  ///
  /// [isDark] 是否为暗色主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  /// [useDynamicColor] 是否使用动态颜色
  static Future<ThemeData> _buildThemeWithDynamicColor({
    required bool isDark,
    double fontScale = 1.0,
    BuildContext? context,
    bool useDynamicColor = true,
  }) async {
    // 获取动态文本主题
    final textTheme = isDark
        ? TextThemeConfig.getDarkTheme(fontScale: fontScale, context: context)
        : TextThemeConfig.getLightTheme(fontScale: fontScale, context: context);

    // 获取动态颜色方案
    final dynamicColorScheme = await DynamicColorManager.instance.createColorScheme(
      isDark: isDark,
      useDynamicColor: useDynamicColor,
    );

    // 获取基础主题
    final baseTheme = isDark ? _baseDarkTheme : _baseLightTheme;

    // 返回带有动态颜色和文本主题的完整主题
    return baseTheme.copyWith(
      colorScheme: dynamicColorScheme,
      textTheme: textTheme,
    );
  }

  /// 基础亮色主题（不包含动态文本主题）
  static ThemeData get _baseLightTheme => ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,

    // 1. Material 3 完整颜色方案
    colorScheme: ColorScheme.light(
      // Primary colors - 主色系
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: AppColors.greenContainer,
      onPrimaryContainer: AppColors.onGreenContainer,
      
      // Secondary colors - 次要色系
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      
      // Tertiary colors - 第三色系
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      
      // Error colors - 错误色系
      error: AppColors.lightError,
      onError: Colors.white,
      errorContainer: AppColors.lightErrorContainer,
      onErrorContainer: AppColors.lightOnErrorContainer,
      
      // Surface colors - 表面色系
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
      
      // Outline colors - 轮廓色系
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightDivider,
    ),

    // 2. 图标主题
    iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    primaryIconTheme: IconThemeData(color: Colors.white),

    // 3. 应用栏主题
    appBarTheme: AppBarThemeConfig.lightTheme,

    // 4. 底部导航栏
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightAppBarBackground,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: AppColors.lightTextDisabled,
      selectedLabelStyle: TextStyle(
        color: AppColors.primaryGreen,
        fontFamily: 'PingFang SC',
      ),
      unselectedLabelStyle: TextStyle(
        color: AppColors.lightTextDisabled,
        fontFamily: 'PingFang SC',
      ),
    ),

    // 5. 按钮主题
    elevatedButtonTheme: ButtonThemeConfig.lightElevatedButtonTheme,
    textButtonTheme: ButtonThemeConfig.lightTextButtonTheme,
    outlinedButtonTheme: ButtonThemeConfig.lightOutlinedButtonTheme,
    floatingActionButtonTheme: ButtonThemeConfig.lightFloatingActionButtonTheme,

    // 6. 卡片主题
    cardTheme: CardThemeConfig.lightTheme,

    // 7. 输入框主题
    inputDecorationTheme: InputThemeConfig.lightTheme,

    // 8. 其他组件主题
    dividerTheme: DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
      space: 16,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightCardBackground,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontFamily: 'PingFang SC',
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primaryGreen,
    ),

    // 9. 自定义主题扩展
    extensions: <ThemeExtension<dynamic>>[
      IMBoyIconTheme(
        primaryIcon: IconThemeData(color: AppColors.primaryGreen, size: 24),
        surfaceIcon: IconThemeData(color: AppColors.lightTextPrimary, size: 24),
        secondaryIcon: IconThemeData(color: AppColors.info, size: 24),
        errorIcon: IconThemeData(color: AppColors.lightError, size: 24),
      ),
      AppThemeExtension.light(),
    ],
  );

  /// 基础暗色主题（不包含动态文本主题）
  static ThemeData get _baseDarkTheme => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,

    // 1. Material 3 完整颜色方案 - 暗色模式
    colorScheme: ColorScheme.dark(
      // Primary colors - 主色系
      primary: AppColors.primaryGreenLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryGreenDark,
      onPrimaryContainer: AppColors.onGreenContainer,
      
      // Secondary colors - 次要色系
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      
      // Tertiary colors - 第三色系
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      
      // Error colors - 错误色系
      error: AppColors.darkError,
      onError: Colors.black,
      errorContainer: AppColors.darkErrorContainer,
      onErrorContainer: AppColors.darkOnErrorContainer,
      
      // Surface colors - 表面色系
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
      
      // Outline colors - 轮廓色系
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkDivider,
    ),

    // 2. 图标主题
    iconTheme: IconThemeData(color: AppColors.primaryGreenLight),
    primaryIconTheme: IconThemeData(color: Colors.white),

    // 3. 应用栏主题
    appBarTheme: AppBarThemeConfig.darkTheme,

    // 4. 底部导航栏
    bottomNavigationBarTheme: _createBottomNavTheme(
      backgroundColor: AppColors.darkAppBarBackground,
      selectedColor: AppColors.primaryGreenLight,
      unselectedColor: AppColors.darkTextDisabled,
    ),

    // 5. 按钮主题
    elevatedButtonTheme: ButtonThemeConfig.darkElevatedButtonTheme,
    textButtonTheme: ButtonThemeConfig.darkTextButtonTheme,
    outlinedButtonTheme: ButtonThemeConfig.darkOutlinedButtonTheme,
    floatingActionButtonTheme: ButtonThemeConfig.darkFloatingActionButtonTheme,

    // 6. 卡片主题
    cardTheme: CardThemeConfig.darkTheme,

    // 7. 输入框主题
    inputDecorationTheme: InputThemeConfig.darkTheme,

    // 8. 其他组件主题
    dividerTheme: DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
      space: 16,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkCardBackground,
      selectedColor: AppColors.primaryGreenLight,
      labelStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontFamily: 'PingFang SC',
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primaryGreenLight,
    ),

    // 9. 自定义主题扩展
    extensions: <ThemeExtension<dynamic>>[
      IMBoyIconTheme(
        primaryIcon: IconThemeData(color: AppColors.primaryGreen, size: 24),
        surfaceIcon: IconThemeData(color: AppColors.darkTextPrimary, size: 24),
        secondaryIcon: IconThemeData(color: AppColors.info, size: 24),
        errorIcon: IconThemeData(color: AppColors.darkError, size: 24),
      ),
      AppThemeExtension.dark(),
    ],
  );

  /// 使用 copyWith 方法动态调整现有主题的字体大小
  ///
  /// [baseTheme] 基础主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  static ThemeData scaleTheme(
    ThemeData baseTheme,
    double fontScale, {
    BuildContext? context,
  }) {
    final scaledTextTheme = TextThemeConfig.scaleTextTheme(
      baseTheme.textTheme,
      fontScale,
      context: context,
    );

    return baseTheme.copyWith(textTheme: scaledTextTheme);
  }

  /// 验证主题的可访问性
  ///
  /// [theme] 要验证的主题
  /// 返回不符合可访问性标准的样式名称列表
  static List<String> validateThemeAccessibility(ThemeData theme) {
    return TextThemeConfig.validateAccessibility(theme.textTheme);
  }
}
