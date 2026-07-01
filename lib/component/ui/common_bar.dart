import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
        ? AppColors.overlayWhite10
        : AppColors.overlayWhite50; // glass light-mode highlight

    // Text color
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.black87;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          decoration: BoxDecoration(
            color: glassBackgroundColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
                vertical: AppSpacing.small,
              ),
              child: Row(
                children: [
                  // Leading widget
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.medium),
                  ] else if (automaticallyImplyLeading &&
                      Navigator.canPop(context)) ...[
                    _buildDefaultLeading(context),
                    const SizedBox(width: AppSpacing.medium),
                  ],
                  // Title
                  Expanded(
                    child:
                        titleWidget ??
                        Text(
                          title ?? '',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                  ),
                  // Actions
                  if (rightDMActions != null)
                    ...rightDMActions!
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLeading(BuildContext context) {
    // DESIGN.md §1 双蓝策略：Nav 文字/图标按钮用 iOS 系统蓝 #007AFF，
    // 品牌蓝 #2474E5 保留给 Tab 选中 / 主按钮 / 发送气泡等识别位置。
    final navBlue = AppColors.getIosBlue(Theme.of(context).brightness);
    return GestureDetector(
      // HitTestBehavior.opaque + 44×44 SizedBox：命中区域撑到 iOS HIG/WCAG
      // 2.5.5 要求的最小 44×44pt，视觉上仍保持 36×36 的圆角背景不变。
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final nav = Navigator.of(context);
        // 帧末执行 pop：避开导航同步重入窗口（_flushHistoryUpdates 期间
        // _debugLocked=true）。canPop() 不检测该锁，若在重入窗口里同步 pop
        // 会触发 '!_debugLocked' 断言，且该断言一旦抛出会中断 history flush，
        // 让导航栈短暂卡死、后续 pop 连锁失败。postFrame 把 pop 推到当前
        // 同步栈之外，绕开重入锁（_debugLocked 是同步锁，不跨帧）。
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!nav.mounted) return;
          for (int i = 0; i < popTime && nav.canPop(); i++) {
            nav.pop();
          }
        });
      },
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
            child: Icon(Icons.arrow_back_ios_new, color: navBlue, size: 16),
          ),
        ),
      ),
    );
  }
}
