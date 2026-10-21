/// 面聊记录保存位置页（T10）。
///
/// 契约源：UI-SPEC.md §2「保存位置」+ DESIGN.md §9：
/// - 选择个人或有权企业（+可选工作区；企业空间可不选工作区）；
/// - 变更前说明：保留标题、清空不适用参与者、告知处理方式重新校验；
/// - 确认后更改**本次草稿**，不迁移已有记录；
/// - 个人上下文不显示工作区行；保存期限按 creation-contexts 返回的
///   部署策略如实展示，不硬编码天数。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordCreationContextModel;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'talk_record_entry_context.dart';
import 'talk_record_providers.dart';

/// 保存位置页。
class TalkRecordSaveLocationPage extends ConsumerWidget {
  const TalkRecordSaveLocationPage({super.key, required this.entryContext});

  /// 入口上下文（草稿未改过时的当前选择）。
  final TalkRecordEntryContext entryContext;

  void _confirmChange(
    BuildContext context,
    WidgetRef ref,
    TalkRecordCreationContextModel target,
    String targetName,
    TalkRecordEntryContext current,
  ) {
    final next = talkRecordEntryContextFromCreation(target);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(t.talkRecord.changeConfirmTitle),
        // C-F3：说明逐条 Text 自然换行，禁单行截断（原型缺陷不复刻）。
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.talkRecord.changeConfirmTarget(name: targetName)),
            const SizedBox(height: AppSpacing.small),
            Text(t.talkRecord.changeConfirmKeepTitle),
            const SizedBox(height: AppSpacing.small),
            Text(t.talkRecord.changeConfirmClearParticipants),
            const SizedBox(height: AppSpacing.small),
            Text(t.talkRecord.changeConfirmRecheck),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // 只改本次草稿；参与者清空由 Notifier 按跨归属判定执行。
              ref
                  .read(talkRecordDraftProvider.notifier)
                  .setSaveTo(next, previousEffective: current);
              // 回准备页（返回上一页，不回列表）。
              if (context.mounted) context.pop();
            },
            child: Text(
              t.talkRecord.changeConfirmAction,
              key: const ValueKey('talk_record_change_confirm'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final contextsAsync = ref.watch(talkRecordCreationContextsProvider);
    final draft = ref.watch(talkRecordDraftProvider);
    final current = draft.saveTo ?? entryContext;

    return CupertinoPageScaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.talkRecord.saveLocationTitle),
        automaticallyImplyLeading: true,
      ),
      child: SafeArea(
        top: false,
        child: contextsAsync.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => _LoadFailedView(
            onRetry: () => ref.invalidate(talkRecordCreationContextsProvider),
          ),
          data: (contexts) {
            final personal = contexts
                .where((c) => c.scope == TalkRecordScope.personal)
                .toList(growable: false);
            final organizations = contexts
                .where((c) => c.scope == TalkRecordScope.organization)
                .toList(growable: false);
            final orgRoots = organizations
                .where((c) => c.workspaceId.isEmpty)
                .toList(growable: false);
            final workspaces = organizations
                .where((c) => c.workspaceId.isNotEmpty)
                .toList(growable: false);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.regular),
              children: [
                if (personal.isNotEmpty) ...[
                  _SectionHeader(t.talkRecord.saveLocationPersonalSection),
                  for (final item in personal)
                    _LocationTile(
                      key: ValueKey('talk_record_location_${item.contextKey}'),
                      title: item.displayName.isNotEmpty
                          ? item.displayName
                          : t.talkRecord.contextPersonal,
                      subtitle: _retentionText(item),
                      selected: _isSelected(current, item),
                      onTap: () => _handleTap(context, ref, item, current),
                    ),
                ],
                if (orgRoots.isNotEmpty) ...[
                  _SectionHeader(t.talkRecord.saveLocationOrgSection),
                  for (final item in orgRoots) ...[
                    _LocationTile(
                      key: ValueKey('talk_record_location_${item.contextKey}'),
                      title: item.displayName.isNotEmpty
                          ? item.displayName
                          : t.talkRecord.contextOrgFallback,
                      subtitle: _retentionText(item),
                      selected: _isSelected(current, item),
                      onTap: () => _handleTap(context, ref, item, current),
                    ),
                    // 工作区子行（企业空间可不选工作区：根行即“不指定”）。
                    for (final ws in workspaces.where(
                      (w) => w.organizationId == item.organizationId,
                    ))
                      _LocationTile(
                        key: ValueKey('talk_record_location_${ws.contextKey}'),
                        title: ws.displayName.isNotEmpty
                            ? ws.displayName
                            : t.talkRecord.saveLocationWorkspaceOptional,
                        subtitle: _retentionText(ws),
                        indent: true,
                        selected: _isSelected(current, ws),
                        onTap: () => _handleTap(context, ref, ws, current),
                      ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    TalkRecordCreationContextModel item,
    TalkRecordEntryContext current,
  ) {
    final same = _isSelected(current, item);
    if (same) {
      // 点当前选择：直接返回（不弹确认、不重复写草稿）。
      context.pop();
      return;
    }
    _confirmChange(context, ref, item, _displayNameOf(item), current);
  }

  bool _isSelected(
    TalkRecordEntryContext current,
    TalkRecordCreationContextModel item,
  ) {
    return current.matchesContext(
      scope: item.scope,
      organizationId: item.organizationId,
      workspaceId: item.workspaceId,
    );
  }

  String _displayNameOf(TalkRecordCreationContextModel item) {
    if (item.scope == TalkRecordScope.personal) {
      return t.talkRecord.contextPersonal;
    }
    if (item.workspaceId.isNotEmpty) {
      final org = _orgNameOf(item);
      return org.isEmpty ? item.displayName : '$org · ${item.displayName}';
    }
    return item.displayName.isNotEmpty
        ? item.displayName
        : t.talkRecord.contextOrgFallback;
  }

  /// 工作区行的企业名（creation-contexts fixture 未冻结处宽松取 raw；
  /// 取不到时展示名退化为工作区名，不猜测）。
  String _orgNameOf(TalkRecordCreationContextModel item) {
    final raw = item.raw['organization_name']?.toString() ?? '';
    return raw;
  }

  String? _retentionText(TalkRecordCreationContextModel item) {
    if (item.retentionPolicy.isEmpty) return null;
    return '${t.talkRecord.retentionPolicyLabel}：${item.retentionPolicy}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.small,
        top: AppSpacing.medium,
        bottom: AppSpacing.small,
      ),
      child: Text(
        text,
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.indent = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 触达 ≥44pt。
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.fromLTRB(
          indent ? AppSpacing.xLarge : AppSpacing.medium,
          AppSpacing.small,
          AppSpacing.medium,
          AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.small),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    // C-F3：长名可换行。
                    style: context.textStyle(
                      FontSizeType.medium,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      // C-F3：期限说明可换行。
                      style: context.textStyle(
                        FontSizeType.small,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.check_mark,
                size: AppSpacing.xLarge,
                color: AppColors.primaryDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailedView extends StatelessWidget {
  const _LoadFailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.talkRecord.loadFailedTitle,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.medium,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          CupertinoButton(
            key: const ValueKey('talk_record_locations_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}

/// 供路由/测试使用的键（个人/企业根行的 ValueKey 前缀）。
const String kTalkRecordLocationTileKeyPrefix = 'talk_record_location_';

/// 供测试使用的辅助：把创建上下文转为入口上下文（与页面内私有实现同义）。
TalkRecordEntryContext talkRecordEntryContextFromCreation(
  TalkRecordCreationContextModel item,
) {
  final rawOrgName = item.raw['organization_name']?.toString() ?? '';
  final orgName = item.workspaceId.isNotEmpty
      ? rawOrgName
      : (item.displayName.isNotEmpty ? item.displayName : rawOrgName);
  return TalkRecordEntryContext(
    scope: item.scope == TalkRecordScope.organization
        ? TalkRecordScope.organization
        : TalkRecordScope.personal,
    organizationId: item.organizationId,
    organizationName: item.organizationId.isEmpty ? '' : orgName,
    workspaceId: item.workspaceId,
    workspaceName: item.workspaceId.isEmpty ? '' : item.displayName,
  );
}
