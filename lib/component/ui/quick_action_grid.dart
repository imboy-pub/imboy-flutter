import 'package:flutter/material.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 极简高效宫格项
class QuickActionItem {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// 高效直达宫格区 (Quick Action Grid)
class QuickActionGrid extends StatelessWidget {
  final List<QuickActionItem> items;
  final int crossAxisCount;

  const QuickActionGrid({
    super.key,
    required this.items,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items
            .map((item) => _buildItem(context, item, brightness))
            .toList(),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    QuickActionItem item,
    Brightness brightness,
  ) {
    return Expanded(
      child: CellPressable(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              DefaultTextStyle(
                style: TextStyle(color: item.color ?? AppColors.primary),
                child: IconTheme(
                  data: IconThemeData(
                    size: 28,
                    color: item.color ?? AppColors.primary,
                  ),
                  child: item.icon,
                ),
              ),
              const SizedBox(height: 8),
              // 文字
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextColor(brightness),
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
