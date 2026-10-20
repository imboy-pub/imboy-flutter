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
import 'package:imboy/theme/default/font_types.dart';

/// Display-only context; switching still uses the existing atomic picker flow.
class CurrentSpaceTile extends ConsumerWidget {
  const CurrentSpaceTile({super.key, this.heading});

  final String? heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(productExperienceProvider);
    final account = ref.watch(currentUserProvider)?.uid ?? '';
    Widget tile(Organization? org) {
      final name = experience == ProductExperience.personal
          ? context.t.organization.experienceUi.personalSpace
          : org?.name ?? context.t.organization.picker.noneSelected;
      if (heading != null) {
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          onPressed: () => context.push(kOrganizationPickerPath),
          child:
              MediaQuery.textScalerOf(context).scale(
                    context.textStyle(FontSizeType.body).fontSize ??
                        FontSizeType.body.size,
                  ) >
                  24
              ? Text(
                  '$heading · $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(FontSizeType.body),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      heading!,
                      style: context.textStyle(
                        FontSizeType.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$name ⌄',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(FontSizeType.caption2),
                    ),
                  ],
                ),
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
}
