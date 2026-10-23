import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// The Me page uses cards without changing shortcut grids on other pages.
class MineShortcut extends StatelessWidget {
  const MineShortcut({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return CupertinoButton(
      color: brightness == Brightness.dark
          ? AppColors.darkSurfaceGroupedTertiary
          : AppColors.getSurfaceColor(brightness),
      borderRadius: AppRadius.borderRadiusCell,
      padding: const EdgeInsets.all(AppSpacing.medium),
      minimumSize: const Size.square(AppSizes.touchTarget),
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.xxxLarge * 1.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppSizes.iconSizeMedium, color: AppColors.primary),
            AppSpacing.verticalMedium,
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.normal,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextColor(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MineShortcutGrid extends StatelessWidget {
  const MineShortcutGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (children.isEmpty) return const SizedBox.shrink();
      final style = context.textStyle(FontSizeType.normal);
      final textSize = MediaQuery.textScalerOf(context).scale(style.fontSize!);
      final minWidth = AppSizes.buttonMinWidth + textSize * 2;
      final columns = math.max(
        1,
        math.min(
          3,
          math.min(
            children.length,
            (constraints.maxWidth + AppSpacing.small) ~/
                (minWidth + AppSpacing.small),
          ),
        ),
      );
      final width =
          (constraints.maxWidth - AppSpacing.small * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.small,
        runSpacing: AppSpacing.small,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
