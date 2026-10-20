import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/flat_list_tile.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Shared geometry for resource entries, including asynchronously gated entries.
class ResourceEntryTile extends StatelessWidget {
  const ResourceEntryTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
    this.foregroundColor,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AppSpacing.xxxLarge),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlatListTile(
          leadingGap: AppSpacing.medium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          leading: SizedBox.square(
            dimension: AppSpacing.xxLarge,
            child: Icon(
              icon,
              size: AppSpacing.xLarge,
              color:
                  foregroundColor ??
                  AppColors.getIosBlue(Theme.of(context).brightness),
            ),
          ),
          title: Text(
            title,
            style: foregroundColor == null
                ? null
                : TextStyle(color: foregroundColor),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing:
              trailing ??
              const SizedBox(
                width: AppSpacing.large,
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: AppSpacing.regular,
                ),
              ),
          onTap: onTap,
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start:
                  AppSpacing.regular + AppSpacing.xxLarge + AppSpacing.medium,
              end: AppSpacing.regular,
            ),
            child: Divider(
              height: 1,
              color: AppColors.getIosSeparator(Theme.of(context).brightness)
                  .withValues(alpha: 0.3),
            ),
          ),
      ],
    ),
  );
}
