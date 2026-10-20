import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Reading and management pages share a bounded content column and quiet cells.
/// The caller retains scrolling, safe areas, state handling and permissions.
class ResourcePageLayout extends StatelessWidget {
  const ResourcePageLayout({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 680;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: SizedBox.expand(
            child: Theme(data: _resourceTheme(theme), child: child),
          ),
        ),
      ),
    );
  }

  ThemeData _resourceTheme(ThemeData theme) => theme.copyWith(
    splashFactory: NoSplash.splashFactory,
    listTileTheme: theme.listTileTheme.copyWith(
      contentPadding: AppSpacing.pageHorizontal,
      horizontalTitleGap: AppSpacing.medium,
      minLeadingWidth: AppSpacing.xxLarge,
      minVerticalPadding: AppSpacing.medium,
      iconColor: theme.colorScheme.onSurfaceVariant,
    ),
    cardTheme: theme.cardTheme.copyWith(
      elevation: 0,
      surfaceTintColor: AppColors.transparent,
      color: theme.colorScheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.cell),
      ),
    ),
    inputDecorationTheme: _inputTheme(theme),
  );

  InputDecorationThemeData _inputTheme(ThemeData theme) =>
      theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        contentPadding: AppSpacing.allMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cell),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cell),
          borderSide: BorderSide(color: AppColors.getIosBlue(theme.brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cell),
          borderSide: BorderSide.none,
        ),
      );
}
