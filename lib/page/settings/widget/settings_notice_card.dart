import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Backup and recovery guidance keeps its accent without tinting body text.
class SettingsNoticeCard extends StatelessWidget {
  const SettingsNoticeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.paragraphs,
    this.margin,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<String> paragraphs;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final foreground = AppColors.getTextColor(Theme.of(context).brightness);
    return Card(
      margin: margin,
      color: accent.withValues(alpha: 0.1),
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    title,
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSmall,
            for (var index = 0; index < paragraphs.length; index++) ...[
              if (index > 0) AppSpacing.verticalTiny,
              Text(
                paragraphs[index],
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: foreground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
