import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 毛玻璃效果的导航栏
/// 参考 GlassBottomNavigationBar 的设计风格
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
  });

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
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final height = toolbarHeight ?? kToolbarHeight + 16;

    // Background color with opacity for glass effect
    final glassBackgroundColor = backgroundColor ??
        (isDark

        ? const Color(0xFF1E1E1E).withValues(alpha: 0.75)
        : const Color(0xFFF7F7F7).withValues(alpha: 0.85) // WeChat style grey
            );

    // Border color to "catch the light"
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.5);

    // Text color
    final textColor = isDark ? Colors.white.withValues(alpha: 0.95) : Colors.black87;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          decoration: BoxDecoration(
            color: glassBackgroundColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Leading widget
                  if (leading != null)
                    leading!
                  else if (automaticallyImplyLeading && Navigator.canPop(context))
                    _buildDefaultLeading(context),
                  // Title
                  Expanded(
                    child: titleWidget ??
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
    return GestureDetector(
      onTap: () {
        NavigatorState nav = Navigator.of(context);
        for (int i = 0; i < popTime; i++) {
          nav.pop();
        }
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.primaryGreen,
          size: 16,
        ),
      ),
    );
  }
}
