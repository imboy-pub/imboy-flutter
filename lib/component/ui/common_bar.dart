import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 毛玻璃效果的导航栏
///
/// 提供类似 iOS 的毛玻璃效果，支持自动显示/隐藏返回按钮。
///
/// ## 使用示例
///
/// ```dart
/// Scaffold(
///   appBar: GlassAppBar(
///     title: '我的页面',
///     automaticallyImplyLeading: true,
///   ),
/// )
/// ```
///
/// ## 参数说明
///
/// - [automaticallyImplyLeading]: 当为 true 且可以返回时自动显示返回按钮
/// - [popTime]: 点击返回按钮时返回的层数，默认为 1，范围 1-10
/// - [blur]: 毛玻璃模糊度，默认 20.0，范围 0-50
/// - [opacity]: 背景透明度，默认 0.75，范围 0-1
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.leading,
    this.leadingWidth,
    this.title = '',
    this.titleWidget,
    this.rightDMActions,
    this.backgroundColor,
    this.automaticallyImplyLeading = false,
    this.popTime = 1,
    this.toolbarHeight,
    this.blur = 20.0,
    this.opacity = 0.75,
  }) : assert(popTime >= 1, 'popTime must be at least 1'),
       assert(popTime <= 10, 'popTime cannot exceed 10 for safety'),
       assert(blur >= 0 && blur <= 50, 'blur must be between 0 and 50'),
       assert(opacity >= 0 && opacity <= 1, 'opacity must be between 0 and 1');

  final Widget? leading;
  final double? leadingWidth;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? rightDMActions;

  final Color? backgroundColor;
  final bool automaticallyImplyLeading;
  final int popTime;
  final double? toolbarHeight;
  final double blur;
  final double opacity;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight ?? kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final height = toolbarHeight ?? kToolbarHeight + 16;

    // Background color with opacity for glass effect
    // DESIGN.md 第 9/10 章：AppBar 背景走 AppColors（暗色 darkSurface / 亮色 lightSurfaceGrouped）
    final glassBackgroundColor =
        backgroundColor ??
        (isDark
            ? AppColors.darkSurface.withValues(alpha: 0.75)
            : AppColors.lightSurfaceGrouped.withValues(alpha: 0.85));

    // Border color to "catch the light"
    final borderColor = isDark
        ? AppColors.iosSeparatorDark.withValues(alpha: 0.65)
        : AppColors.overlayWhite50; // glass light-mode highlight

    // Text color
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          decoration: BoxDecoration(
            color: glassBackgroundColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 0.33)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
                vertical: AppSpacing.small,
              ),
              child: NavigationToolbar(
                centerMiddle: true,
                middleSpacing: AppSpacing.medium,
                leading: leading != null
                    ? SizedBox(width: leadingWidth, child: leading)
                    : automaticallyImplyLeading && Navigator.canPop(context)
                    ? _buildDefaultLeading(context)
                    : null,
                middle: Semantics(
                  header: true,
                  child:
                      titleWidget ??
                      Text(
                        title ?? '',
                        style: context.textStyle(
                          FontSizeType.body,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
                trailing: rightDMActions == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: rightDMActions!,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLeading(BuildContext context) =>
      GlassBackButton(popTime: popTime);
}

/// 统一的"样式A"返回键：36×36 圆角方块蓝底 + 深蓝箭头，44×44 命中区。
///
/// 从 [GlassAppBar] 默认 leading 抽出，供 GlassAppBar 与 iOS 设置风格页面
/// （IosPageTemplate）共用，消除返回键跨页样式不一致（部分页此前为 Cupertino
/// 默认纯箭头无背景）。
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.popTime = 1, this.onPressed})
    : assert(popTime >= 1 && popTime <= 10, 'popTime must be 1-10');

  /// 点击返回的层数，默认 1。
  final int popTime;

  /// 自定义返回行为。未提供时保持默认的多层 Navigator.pop 行为。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // DESIGN.md §1 双蓝策略：Nav 文字/图标按钮用 iOS 系统蓝 #007AFF，
    // 品牌蓝 #2474E5 保留给 Tab 选中 / 主按钮 / 发送气泡等识别位置。
    final navBlue = AppColors.getIosBlue(Theme.of(context).brightness);
    return CellPressable(
      onTap: () {
        if (onPressed != null) {
          onPressed!();
          return;
        }
        // Keep the existing synchronous, bounded pop behavior for pointer and
        // keyboard activation, including repeated activation at the root.
        final nav = Navigator.of(context);
        for (int i = 0; i < popTime && nav.canPop(); i++) {
          nav.pop();
        }
      },
      child: Semantics(
        label: MaterialLocalizations.of(context).backButtonTooltip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: navBlue.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusCell,
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                color: navBlue,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
