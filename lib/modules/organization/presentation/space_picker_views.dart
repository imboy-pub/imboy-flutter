import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Presentation only; switching, membership and recovery stay in the picker.
class SpacePickerSection extends StatelessWidget {
  const SpacePickerSection({super.key, this.header, required this.children});
  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = AppColors.getTextColor(
      theme.brightness,
      isSecondary: true,
    );
    return CupertinoListSection.insetGrouped(
      header: header == null
          ? null
          : DefaultTextStyle(
              style: context.textStyle(FontSizeType.footnote, color: secondary),
              child: header!,
            ),
      margin: EdgeInsets.fromLTRB(
        AppSpacing.regular,
        header == null ? AppSpacing.medium : AppSpacing.xLarge,
        AppSpacing.regular,
        AppSpacing.none,
      ),
      backgroundColor: AppColors.transparent,
      decoration: BoxDecoration(
        color: _surface(theme.brightness),
        borderRadius: AppRadius.borderRadiusCell,
      ),
      dividerMargin: AppSpacing.xxxLarge + AppSpacing.small,
      children: [
        for (final child in children)
          Theme(
            data: theme.copyWith(
              splashFactory: NoSplash.splashFactory,
              listTileTheme: theme.listTileTheme.copyWith(iconColor: secondary),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
      ],
    );
  }
}

class SpacePickerActions extends StatelessWidget {
  const SpacePickerActions({
    super.key,
    required this.onJoin,
    required this.onCreate,
  });
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.regular,
      vertical: AppSpacing.small,
    ),
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = context.textStyle(FontSizeType.normal).fontSize!;
          final minWidth =
              MediaQuery.textScalerOf(context).scale(fontSize) * 6 +
              AppSpacing.xxLarge;
          final columns =
              constraints.maxWidth >= minWidth * 2 + AppSpacing.medium ? 2 : 1;
          final width =
              (constraints.maxWidth - AppSpacing.medium * (columns - 1)) /
              columns;
          return Wrap(
            spacing: AppSpacing.medium,
            runSpacing: AppSpacing.small,
            children: [
              SizedBox(width: width, child: _action(context, join: true)),
              SizedBox(width: width, child: _action(context, join: false)),
            ],
          );
        },
      ),
    ),
  );

  Widget _action(BuildContext context, {required bool join}) {
    final brightness = Theme.of(context).brightness;
    final color = join
        ? AppColors.getIosBlue(brightness)
        : AppColors.getTextColor(brightness, isSecondary: true);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface(brightness),
        borderRadius: AppRadius.borderRadiusCell,
        border: Border.all(
          color: join ? color : AppColors.getDividerColor(brightness),
        ),
      ),
      child: CupertinoButton(
        key: ValueKey(
          join ? 'org-picker-join-entry' : 'org-picker-create-entry',
        ),
        minimumSize: const Size.square(AppSizes.touchTarget),
        padding: const EdgeInsets.all(AppSpacing.medium),
        borderRadius: AppRadius.borderRadiusCell,
        onPressed: join ? onJoin : onCreate,
        child: Text(
          join
              ? context.t.organization.picker.joinEnterprise
              : context.t.organization.home.createOrg,
          textAlign: TextAlign.center,
          style: context.textStyle(FontSizeType.normal, color: color),
        ),
      ),
    );
  }
}

Color _surface(Brightness brightness) => brightness == Brightness.dark
    ? AppColors.darkSurfaceGroupedTertiary
    : AppColors.getSurfaceColor(brightness);
