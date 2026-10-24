import 'package:flutter/cupertino.dart';
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

/// Display-only context; switching still uses the existing atomic picker flow.
class CurrentSpaceTile extends ConsumerWidget {
  const CurrentSpaceTile({super.key, this.heading});

  /// 导航栏标题前缀（如频道页「频道 · 企业名 ⌄」）；null 时渲染为入口行。
  final String? heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(productExperienceProvider);
    final account = ref.watch(currentUserProvider)?.uid ?? '';
    Widget tile(Organization? org) {
      final name = experience == ProductExperience.personal
          ? context.t.organization.experienceUi.personalSpace
          : org?.name ?? context.t.organization.picker.noneSelected;
      if (heading != null) return _headingButton(context, name);
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
}
