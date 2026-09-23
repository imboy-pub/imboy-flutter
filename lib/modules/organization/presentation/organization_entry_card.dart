/// P0 企业入口卡（计划 §14.1）——嵌入现有 ContactPage 顶部，稳定增量：
/// - 有企业：展示当前企业（指针 ∩ mine 真源），点击进入 P1 类企业微信
///   通讯录；多企业提供「切换」入口（复用既有 OrganizationPickerPage 的
///   CurrentOrganizationStore / Workspace provider invalidation 流程）；
/// - 无企业（mine() 成功且空）：展示加入/创建入口（复用既有页面），
///   不整块卸载；
/// - 网络/权限错误：错误态 + 重试，绝不伪装成无企业；
/// - 进入页与下拉刷新由宿主 ContactPage 触发 [OrganizationEntryNotifier.fetch]。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';

/// 账号指针监听（ValueListenableBuilder 包裹，指针切换后行内即时更新）。
class OrganizationEntryCard extends ConsumerWidget {
  const OrganizationEntryCard({super.key, this.accountKey});

  /// 测试可注入账号键；缺省登录 UID。
  final String? accountKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(organizationEntryProvider);
    final key = accountKey ?? organizationAccountKey();
    if (key.isEmpty) {
      // 未登录/账号键缺失：按未加载渲染轻量占位，不触发网络。
      return const SizedBox.shrink();
    }
    final store = CurrentOrganizationStore.forAccount(key);
    return ValueListenableBuilder<Organization?>(
      valueListenable: store.listenable,
      builder: (context, pointer, _) {
        final current = resolveCurrentOrganization(entry, pointer);
        return _OrganizationEntryBody(
          entry: entry,
          current: current,
          onRetry: () => ref.read(organizationEntryProvider.notifier).fetch(),
        );
      },
    );
  }
}

class _OrganizationEntryBody extends StatelessWidget {
  const _OrganizationEntryBody({
    required this.entry,
    required this.current,
    required this.onRetry,
  });

  final OrganizationEntryState entry;
  final Organization? current;
  final VoidCallback onRetry;

  void _openDirectory(BuildContext context, Organization org) {
    context.push(
      '$kOrganizationHomePath/${org.id}/directory'
      '?name=${Uri.encodeComponent(org.name)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    if (!entry.loaded && entry.error == null) {
      // 首拉在途：轻量占位（不阻塞下方联系人列表）。
      return Padding(
        key: const Key('org_entry_loading'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        child: Text(
          t.common.loading,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.iosGray),
        ),
      );
    }

    if (entry.error != null && !entry.hasOrganizations) {
      // 错误态（无数据兜底）：不伪装成无企业。
      return _errorRow(context, key: const Key('org_entry_error'));
    }

    if (!entry.loaded && entry.orgs.isEmpty) {
      return const SizedBox.shrink(key: Key('org_entry_idle'));
    }

    if (entry.orgs.isEmpty) {
      // 无企业（mine() 成功且空）：加入/创建入口（复用既有页面），不整块卸载。
      return Padding(
        key: const Key('org_entry_empty'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
        child: Row(
          children: [
            Expanded(
              child: _EntryTile(
                icon: CupertinoIcons.person_crop_circle_badge_plus,
                label: t.organization.picker.joinEnterprise,
                onTap: () =>
                    context.push('$kOrganizationPickerPath?autoJoin=1'),
              ),
            ),
            AppSpacing.horizontalSmall,
            Expanded(
              child: _EntryTile(
                icon: CupertinoIcons.add_circled,
                label: t.organization.home.createOrg,
                onTap: () => context.push(kOrganizationHomePath),
              ),
            ),
          ],
        ),
      );
    }

    // 有企业：当前企业行（+ 多企业切换入口）；刷新失败时附内联错误行
    // （保留入口行 + 旧数据，不清空、不伪装无企业）。
    return Column(
      key: const Key('org_entry_row'),
      children: [
        _orgRow(context),
        if (entry.error != null)
          _errorRow(context, key: const Key('org_entry_stale_error')),
      ],
    );
  }

  Widget _orgRow(BuildContext context) {
    final t = context.t;
    final org = current ?? entry.orgs.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Row(
        children: [
          Expanded(
            child: _EntryTile(
              icon: CupertinoIcons.building_2_fill,
              label: org.name,
              sublabel: t.organization.contactEntry.browserEntry,
              onTap: () => _openDirectory(context, org),
            ),
          ),
          if (entry.orgs.length > 1) ...[
            AppSpacing.horizontalSmall,
            Flexible(
              child: _EntryTile(
                icon: CupertinoIcons.arrow_left_right_square,
                label: t.organization.picker.switchEnterprise,
                onTap: () => context.push(kOrganizationPickerPath),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorRow(BuildContext context, {required Key key}) {
    final t = context.t;
    final theme = Theme.of(context);
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${t.organization.contactEntry.loadFailed}：${entry.error}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(t.common.buttonRetry)),
        ],
      ),
    );
  }
}

/// 入口小瓦片：图标 + 主/副文案，触达区 ≥ 44pt。
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
          .withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadius.cell),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.cell),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.medium,
            vertical: AppSpacing.small + AppSpacing.tiny,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.cell),
                  color: AppColors.primaryAlpha10,
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              AppSpacing.horizontalSmall,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.caption2,
                          color: AppColors.iosGray,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 12,
                color: AppColors.iosGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
