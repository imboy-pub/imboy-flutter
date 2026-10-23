import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/flat_list_tile.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Settings and profile details keep full values readable at large text sizes.
class DetailSettingsTile extends StatelessWidget {
  const DetailSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.destructive = false,
  });
  final Widget title;
  final Widget? subtitle, leading, trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final brightness = Theme.of(context).brightness;
      final style = context.textStyle(FontSizeType.body);
      final stacked = _stackValue(context, constraints.maxWidth, style);
      final detail = value == null
          ? null
          : Text(
              value!,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.getTextColor(brightness, isSecondary: true),
              ),
              textAlign: stacked ? TextAlign.start : TextAlign.end,
            );
      final accessory =
          trailing ?? (onTap == null ? null : const CupertinoListTileChevron());
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: FlatListTile(
          leading: leading,
          leadingGap: AppSpacing.medium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          title: _title(context, style, stacked, detail),
          subtitle: subtitle,
          trailing: _accessory(
            constraints.maxWidth,
            stacked,
            detail,
            accessory,
          ),
          onTap: onTap,
        ),
      );
    },
  );
  Widget _title(
    BuildContext context,
    TextStyle style,
    bool stacked,
    Widget? detail,
  ) {
    final brightness = Theme.of(context).brightness;
    return DefaultTextStyle.merge(
      style: style.copyWith(
        fontWeight: FontWeight.w400,
        color: destructive
            ? AppColors.getIosRed(brightness)
            : AppColors.getTextColor(brightness),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          if (stacked && detail != null) ...[AppSpacing.verticalTiny, detail],
        ],
      ),
    );
  }

  Widget _accessory(
    double width,
    bool stacked,
    Widget? detail,
    Widget? accessory,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!stacked && detail != null)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * .42),
          child: detail,
        ),
      if (!stacked && detail != null && accessory != null)
        AppSpacing.horizontalSmall,
      ?accessory,
    ],
  );

  bool _stackValue(BuildContext context, double width, TextStyle style) {
    if (value == null) return false;
    final scaler = MediaQuery.textScalerOf(context);
    if (scaler.scale(1) > FontSizeOption.extraLarge.scale) return true;
    final text = title is Text ? (title as Text).data ?? '' : '';
    double measure(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final reserved =
        AppSpacing.regular * 2 +
        (leading == null ? 0 : AppSizes.iconSizeLarge + AppSpacing.medium) +
        (onTap == null && trailing == null ? 0 : AppSizes.touchTarget);
    return measure(text, style) +
            measure(value!, context.textStyle(FontSizeType.normal)) +
            reserved >
        width;
  }
}
