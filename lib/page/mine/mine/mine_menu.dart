import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class MineSection extends StatelessWidget {
  const MineSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xLarge),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: context.textStyle(
            FontSizeType.small,
            color: AppColors.getTextColor(
              Theme.of(context).brightness,
              isSecondary: true,
            ),
          ),
        ),
        AppSpacing.verticalSmall,
        child,
      ],
    ),
  );
}

class MineMenuTile extends StatelessWidget {
  const MineMenuTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.detail,
    this.showDivider = true,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? detail;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.getTextColor(brightness, isSecondary: true);
    return Column(
      children: [
        CupertinoButton(
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
          minimumSize: const Size(0, AppSizes.touchTarget),
          onPressed: onTap,
          child: _row(context, secondary),
        ),
        if (showDivider) _divider(brightness),
      ],
    );
  }

  Widget _row(BuildContext context, Color secondary) => Row(
    children: [
      SizedBox.square(
        dimension: AppSpacing.xxLarge,
        child: Icon(icon, size: AppSizes.iconSizeMedium, color: secondary),
      ),
      AppSpacing.horizontalSmall,
      Expanded(child: _label(context, Theme.of(context).brightness)),
      AppSpacing.horizontalSmall,
      Icon(
        CupertinoIcons.chevron_right,
        size: AppSizes.iconSizeXSmall,
        color: secondary,
      ),
    ],
  );

  Widget _divider(Brightness brightness) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: AppSpacing.xxLarge + AppSpacing.small,
    ),
    child: Divider(
      height: AppSizes.dividerThickness,
      color: AppColors.getDividerColor(brightness).withValues(alpha: 0.4),
    ),
  );

  Widget _label(BuildContext context, Brightness brightness) {
    final titleStyle = context.textStyle(
      FontSizeType.medium,
      color: AppColors.getTextColor(brightness),
    );
    final detailStyle = context.textStyle(
      FontSizeType.small,
      color: AppColors.getTextColor(brightness, isSecondary: true),
    );
    final titleText = Text(title, style: titleStyle);
    if (detail == null) return titleText;
    final detailText = Text(detail!, style: detailStyle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            _textWidth(context, title, titleStyle) +
            _textWidth(context, detail!, detailStyle) +
            AppSpacing.medium;
        if (contentWidth <= constraints.maxWidth) {
          return Row(
            children: [
              Expanded(child: titleText),
              AppSpacing.horizontalMedium,
              detailText,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [titleText, detailText],
        );
      },
    );
  }

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
