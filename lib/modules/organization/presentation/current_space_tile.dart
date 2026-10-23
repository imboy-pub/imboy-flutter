import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, Tooltip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/resource_entry_tile.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_sizes.dart';

/// Display-only context; switching still uses the existing atomic picker flow.
class CurrentSpaceTile extends ConsumerWidget {
  const CurrentSpaceTile({
    super.key,
    this.heading,
    this.compact = false,
    this.compactLabel,
  });

  final String? heading;
  final bool compact;

  /// A shell-bound enterprise/workspace label; never used for authorization.
  final String? compactLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(productExperienceProvider);
    final account = ref.watch(currentUserProvider)?.uid ?? '';
    Widget tile(Organization? org) {
      final name = experience == ProductExperience.personal
          ? context.t.organization.experienceUi.personalSpace
          : org?.name ?? context.t.organization.picker.noneSelected;
      if (heading != null) return _headingButton(context, name);
      if (compact) {
        final label = compactLabel?.trim();
        return _compactButton(
          context,
          label?.isNotEmpty == true ? label! : name,
        );
      }
      return ResourceEntryTile(
        showDivider: false,
        icon: experience == ProductExperience.personal
            ? CupertinoIcons.person_circle
            : CupertinoIcons.building_2_fill,
        title: name,
        subtitle: context.t.organization.experienceUi.currentSpace,
        onTap: () => context.push(kOrganizationPickerPath),
      );
    }

    if (account.isEmpty) return tile(null);
    return ValueListenableBuilder<Organization?>(
      valueListenable: CurrentOrganizationStore.forAccount(account).listenable,
      builder: (context, org, _) => tile(org),
    );
  }

  Widget _headingButton(BuildContext context, String name) {
    final brightness =
        CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    // A compact navigation bar has only 44pt for its middle widget.
    // Keep context on one line so dynamic type cannot hide a second row.
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      minimumSize: const Size(0, kMinInteractiveDimensionCupertino),
      onPressed: () => context.push(kOrganizationPickerPath),
      child: Text.rich(
        TextSpan(
          text: heading!,
          children: [
            TextSpan(
              text: ' · $name ⌄',
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(brightness, isSecondary: true),
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.body,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextColor(brightness),
        ),
      ),
    );
  }

  Widget _compactButton(BuildContext context, String label) {
    final color = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: context.t.organization.experienceUi.switchSpace,
        value: label,
        button: true,
        excludeSemantics: true,
        onTap: () => context.push(kOrganizationPickerPath),
        child: CupertinoButton(
          key: const ValueKey('mine-space-switch'),
          padding: EdgeInsets.zero,
          alignment: AlignmentDirectional.centerStart,
          minimumSize: const Size.square(AppSizes.touchTarget),
          onPressed: () => context.push(kOrganizationPickerPath),
          child: _compactLabel(context, label, color),
        ),
      ),
    );
  }

  Widget _compactLabel(BuildContext context, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(FontSizeType.normal, color: color),
        ),
      ),
      AppSpacing.horizontalTiny,
      Icon(
        CupertinoIcons.chevron_down,
        size: AppSizes.iconSizeXSmall,
        color: color,
      ),
    ],
  );
}
