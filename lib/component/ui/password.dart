import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 密码输入框组件
///
/// 符合 UI/UX 设计规范 v2.0：
/// - 使用 Design Token 定义样式
/// - 支持主题切换
/// - 支持暗色模式
/// - 遵循无障碍设计标准
///
/// 设计原则：
/// - 使用 Flutter 官方 TextField 组件
/// - 通过 InputDecoration 配置样式
/// - 避免不必要的自定义容器
///
/// 使用示例：
/// ```dart
/// PasswordTextField(
///   obscureText: state.passwordObscure.value,
///   hintText: t.account.password,
///   onTap: () => state.passwordObscure.toggle(),
///   onChanged: (val) => state.password.value = val,
/// )
/// ```
class PasswordTextField extends StatelessWidget {
  /// 是否隐藏密码
  final bool obscureText;

  /// 提示文本
  final String? hintText;

  /// 输入文本样式
  final TextStyle? style;

  /// 提示文本样式
  final TextStyle? hintStyle;

  /// 光标颜色（默认使用主题色）
  final Color? cursorColor;

  /// 图标颜色（默认使用次要文本色）
  final Color? iconColor;

  /// 点击切换密码可见性的回调
  final GestureTapCallback? onTap;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  const PasswordTextField({
    super.key,
    this.onTap,
    this.onChanged,
    this.hintText,
    this.obscureText = false,
    this.style,
    this.hintStyle,
    this.cursorColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 Design Token 定义默认值
    final effectiveIconColor = iconColor ?? AppColors.lightTextSecondary;
    final effectiveCursorColor = cursorColor ?? AppColors.primary;
    final effectiveStyle =
        style ??
        TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: FontSizeType.medium.size,
          fontWeight: FontWeight.w500,
        );
    final effectiveHintStyle =
        hintStyle ??
        TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: FontSizeType.medium.size,
        );

    return TextField(
      obscureText: obscureText,
      enableSuggestions: false,
      autocorrect: false,
      textAlignVertical: TextAlignVertical.center,
      style: effectiveStyle,
      cursorColor: effectiveCursorColor,
      decoration: InputDecoration(
        // 背景色和边框 - 符合设计规范
        filled: true,
        fillColor: AppColors.lightSurfaceContainer,

        // 圆角边框 - 符合设计规范
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusSmall,
          borderSide: BorderSide.none,
        ),

        // 聚焦状态边框
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusSmall,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),

        // 启用状态边框
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusSmall,
          borderSide: BorderSide.none,
        ),

        // 提示文本
        hintText: hintText,
        hintStyle: effectiveHintStyle,

        // 内容内边距 - 使用 Design Token
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.regular,
        ),

        // 前缀图标 - 锁
        prefixIcon: Icon(
          Icons.lock_rounded,
          color: effectiveIconColor,
          size: AppSizes.iconSizeSmall,
        ),
        // 图标约束 - 确保触摸区域符合无障碍标准
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.touchTarget, // 48px 最小触摸目标
          minHeight: AppSizes.touchTarget, // 48px 最小触摸目标
        ),

        // 后缀图标 - 显示/隐藏密码
        suffixIcon: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: effectiveIconColor,
            size: AppSizes.iconSizeSmall,
          ),
        ),
        // 图标约束 - 确保触摸区域符合无障碍标准
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.touchTarget, // 48px 最小触摸目标
          minHeight: AppSizes.touchTarget, // 48px 最小触摸目标
        ),
      ),
      onChanged: onChanged,
    );
  }
}
