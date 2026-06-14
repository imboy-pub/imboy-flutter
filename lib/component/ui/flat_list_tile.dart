import 'package:flutter/material.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 极简列表项 (Minimalist & Flat List Tile)
///
/// 核心理念：
/// 1. 去除背景包裹，直接平铺在背景上。
/// 2. 使用大面积留白替代边框和阴影。
/// 3. 图标大而清晰，文字层级分明。
class FlatListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color? iconColor;

  const FlatListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.height,
    this.padding,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return CellPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: height,
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.regular,
            ),
        child: Row(
          children: [
            // 前置图标/头像
            if (leading != null) ...[leading!, const SizedBox(width: 16)],

            // 中间标题和副标题
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextColor(brightness),
                      letterSpacing: -0.4,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextColor(
                          brightness,
                          isSecondary: true,
                        ),
                        letterSpacing: -0.2,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),

            // 后置组件
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
