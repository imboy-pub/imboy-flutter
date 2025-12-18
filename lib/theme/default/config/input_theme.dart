import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 输入框主题配置 - Material 3适配
class InputThemeConfig {
  InputThemeConfig._();

  /// 亮色主题 - 输入框装饰配置（Material 3适配）
  static InputDecorationTheme get lightTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurface,
    // Material 3 内容填充
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16, // Material 3 标准垂直填充
    ),
    
    // Material 3 默认边框 - 圆角4px
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4), // Material 3 小圆角
      borderSide: BorderSide(
        color: AppColors.lightBorder,
        width: 1,
      ),
    ),
    
    // Material 3 启用状态边框
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.lightBorder,
        width: 1,
      ),
    ),
    
    // Material 3 聚焦状态边框
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.primaryGreen,
        width: 2, // Material 3 聚焦边框宽度
      ),
    ),
    
    // Material 3 错误状态边框
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.lightError,
        width: 1,
      ),
    ),
    
    // Material 3 聚焦错误状态边框
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.lightError,
        width: 2,
      ),
    ),
    
    // Material 3 禁用状态边框
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.lightTextDisabled,
        width: 1,
      ),
    ),
    
    // Material 3 文本样式
    hintStyle: TextStyle(
      color: AppColors.lightTextDisabled,
      fontSize: 16, // Material 3 Body Large
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.5, // Material 3 字母间距
    ),
    labelStyle: TextStyle(
      color: AppColors.lightTextSecondary,
      fontSize: 16, // Material 3 Body Large
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.5, // Material 3 字母间距
    ),
    floatingLabelStyle: TextStyle(
      color: AppColors.primaryGreen,
      fontSize: 12, // Material 3 Body Small
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.4, // Material 3 字母间距
    ),
    errorStyle: TextStyle(
      color: AppColors.lightError,
      fontSize: 12, // Material 3 Body Small
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.4, // Material 3 字母间距
    ),
    helperStyle: TextStyle(
      color: AppColors.lightTextSecondary,
      fontSize: 12, // Material 3 Body Small
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.4, // Material 3 字母间距
    ),
  );

  /// 暗色主题 - 输入框装饰配置（Material 3适配）
  static InputDecorationTheme get darkTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurface,
    // Material 3 内容填充
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16, // Material 3 标准垂直填充
    ),
    
    // Material 3 默认边框 - 圆角4px
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4), // Material 3 小圆角
      borderSide: BorderSide(
        color: AppColors.darkBorder,
        width: 1,
      ),
    ),
    
    // Material 3 启用状态边框
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.darkBorder,
        width: 1,
      ),
    ),
    
    // Material 3 聚焦状态边框
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.primaryGreenLight,
        width: 2, // Material 3 聚焦边框宽度
      ),
    ),
    
    // Material 3 错误状态边框
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.darkError,
        width: 1,
      ),
    ),
    
    // Material 3 聚焦错误状态边框
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.darkError,
        width: 2,
      ),
    ),
    
    // Material 3 禁用状态边框
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(
        color: AppColors.darkTextDisabled,
        width: 1,
      ),
    ),
    
    // Material 3 文本样式
    hintStyle: TextStyle(
      color: AppColors.darkTextDisabled,
      fontSize: 16, // Material 3 Body Large
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.5, // Material 3 字母间距
    ),
    labelStyle: TextStyle(
      color: AppColors.darkTextSecondary,
      fontSize: 16, // Material 3 Body Large
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.5, // Material 3 字母间距
    ),
    floatingLabelStyle: TextStyle(
      color: AppColors.primaryGreenLight,
      fontSize: 12, // Material 3 Body Small
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.4, // Material 3 字母间距
    ),
    errorStyle: TextStyle(
      color: AppColors.darkError,
      fontSize: 12, // Material 3 Body Small
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.4, // Material 3 字母间距
    ),
    helperStyle: TextStyle(
      color: AppColors.darkTextSecondary,
      fontSize: 12, // Material 3 Body Small
      fontWeight: FontWeight.w400, // Material 3 Regular
      fontFamily: 'PingFang SC',
      letterSpacing: 0.4, // Material 3 字母间距
    ),
  );

  /// 获取聊天输入框装饰（专用于聊天界面）- Material 3适配
  static InputDecoration getChatInputDecoration({
    bool isDark = false,
    String hintText = '输入消息...',
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
        fontSize: 16, // Material 3 Body Large
        fontWeight: FontWeight.w400, // Material 3 Regular
        fontFamily: 'PingFang SC',
        letterSpacing: 0.5, // Material 3 字母间距
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      // Material 3 聊天输入框使用大圆角（28px）
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28), // Material 3 Extra Large Shape
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
          width: 2, // Material 3 聚焦边框宽度
        ),
      ),
      // Material 3 内容填充
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16, // Material 3 标准垂直填充
      ),
    );
  }
}