/// 面聊记录（talk_record）编辑权限页分区组件（T18）。
///
/// 从编辑权限页（talk_record_grant_edit_page.dart）拆出的展示件：
/// 被授权人卡、候选选择区、角色分段（C-F1）、允许导出开关（策略禁用
/// 态 disabled + 原因）、到期区（可选）、说明/横幅与保存主按钮（C-F2）。
/// 行为契约见页面头注释；本文件只做展示，状态由页面持有。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_providers.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_service.dart'
    show TalkRecordExportBlockReason;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

// ---------------------------------------------------------------------------
// 被授权人 / 候选选择
// ---------------------------------------------------------------------------

/// 编辑模式：被授权人卡（不可换人——PUT 语义按人授权）。
class TalkRecordGrantGranteeCard extends StatelessWidget {
  const TalkRecordGrantGranteeCard({super.key, required this.grant});

  final TalkRecordGrantModel grant;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_grant_edit_grantee_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: _cardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.grantEditGranteeLabel,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            grant.granteeDisplayName,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.body,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 新建模式：候选选择区（搜索 + 列表；fixture 候选集）。
class TalkRecordCandidateSection extends ConsumerWidget {
  const TalkRecordCandidateSection({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final TalkRecordShareCandidateModel? selected;
  final ValueChanged<TalkRecordShareCandidateModel> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final state = ref.watch(talkRecordShareCandidatesProvider);
    return Container(
      key: const ValueKey('talk_record_grant_edit_candidates_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: _cardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.grantEditCandidateSection,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          CupertinoSearchTextField(
            key: const ValueKey('talk_record_grant_edit_candidate_search'),
            placeholder: t.talkRecord.grantEditCandidateSearchHint,
            onChanged: (q) => ref
                .read(talkRecordShareCandidatesProvider.notifier)
                .setQuery(q),
          ),
          const SizedBox(height: AppSpacing.small),
          if (state.phase == TalkRecordCandidatesPhase.loading)
            const CupertinoActivityIndicator()
          else if (state.phase == TalkRecordCandidatesPhase.failed)
            Text(
              t.talkRecord.grantEditCandidatesUnavailable,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.getIosOrange(brightness),
              ),
            )
          else if (state.candidates.isEmpty)
            Text(
              t.talkRecord.grantEditCandidateEmpty,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.body,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            )
          else
            for (final c in state.candidates)
              _CandidateRow(
                candidate: c,
                selected: selected?.userId == c.userId,
                onTap: () => onSelect(c),
              ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final TalkRecordShareCandidateModel candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      key: ValueKey('talk_record_grant_edit_candidate_${candidate.userId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        // C-F4：触达 ≥44。
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.displayName,
                    maxLines: null,
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                      color: brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (candidate.account.isNotEmpty)
                    Text(
                      candidate.account,
                      maxLines: null,
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(
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

// ---------------------------------------------------------------------------
// 角色 / 导出 / 到期
// ---------------------------------------------------------------------------

/// 角色分段（C-F1：选中态 primaryDark 实底 + 白字 w600；对齐 T16 页签）。
class TalkRecordRoleSection extends StatelessWidget {
  const TalkRecordRoleSection({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final TalkRecordGrantRole current;
  final ValueChanged<TalkRecordGrantRole> onSelect;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_grant_edit_role_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: _cardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.grantEditRoleSectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          SizedBox(
            height: AppSpacing.xxxLarge,
            child: Row(
              children: [
                for (final (i, role) in [
                  TalkRecordGrantRole.viewer,
                  TalkRecordGrantRole.editor,
                ].indexed)
                  Expanded(
                    child: _RoleSegment(
                      role: role,
                      selected: current == role,
                      borderRadius: BorderRadius.horizontal(
                        left: i == 0 ? const Radius.circular(8) : Radius.zero,
                        right: i == 1 ? const Radius.circular(8) : Radius.zero,
                      ),
                      onTap: () => onSelect(role),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            current == TalkRecordGrantRole.editor
                ? t.talkRecord.grantEditRoleEditorHint
                : t.talkRecord.grantEditRoleViewerHint,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.footnote,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSegment extends StatelessWidget {
  const _RoleSegment({
    required this.role,
    required this.selected,
    required this.borderRadius,
    required this.onTap,
  });

  final TalkRecordGrantRole role;
  final bool selected;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final unselectedBg = brightness == Brightness.dark
        ? AppColors.darkSurfaceGrouped
        : AppColors.lightSurfaceGrouped;
    final unselectedFg = brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final label = role == TalkRecordGrantRole.editor
        ? t.talkRecord.shareGrantRoleEditor
        : t.talkRecord.shareGrantRoleViewer;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        key: ValueKey('talk_record_grant_edit_role_${role.wireName}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: selected
              ? const ValueKey('talk_record_grant_edit_role_selected')
              : null,
          height: AppSpacing.xxxLarge,
          decoration: BoxDecoration(
            // C-F1：primaryDark(#1565C0) 实底 + 白字 w600（5.75:1）。
            color: selected ? AppColors.primaryDark : unselectedBg,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.normal,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.onPrimary : unselectedFg,
            ),
          ),
        ),
      ),
    );
  }
}

/// 允许导出开关（策略禁用态：disabled + 原因展示，§9）。
class TalkRecordExportSection extends StatelessWidget {
  const TalkRecordExportSection({
    super.key,
    required this.value,
    required this.enabled,
    required this.blockReason,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final TalkRecordExportBlockReason? blockReason;
  final ValueChanged<bool> onChanged;

  String get _blockReasonText => switch (blockReason) {
    TalkRecordExportBlockReason.organizationPolicy =>
      t.talkRecord.grantEditExportBlockedOrg,
    TalkRecordExportBlockReason.instancePolicy ||
    TalkRecordExportBlockReason.unknown ||
    null => t.talkRecord.grantEditExportBlockedUnknown,
    TalkRecordExportBlockReason.none => '',
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_grant_edit_export_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: _cardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.talkRecord.grantEditExportSectionTitle,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              CupertinoSwitch(
                key: const ValueKey('talk_record_grant_edit_export_switch'),
                value: enabled && value,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
          if (!enabled) ...[
            const SizedBox(height: AppSpacing.tiny),
            Text(
              _blockReasonText,
              key: const ValueKey('talk_record_grant_edit_export_blocked_hint'),
              maxLines: null,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.getIosOrange(brightness),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 到期（可选）：开关 + 日期显示 + 更改。
class TalkRecordExpiresSection extends StatelessWidget {
  const TalkRecordExpiresSection({
    super.key,
    required this.enabled,
    required this.expiresAt,
    required this.onToggle,
    required this.onPick,
  });

  final bool enabled;
  final DateTime expiresAt;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_grant_edit_expires_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: _cardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.talkRecord.grantEditExpiresSectionTitle,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              CupertinoSwitch(
                key: const ValueKey('talk_record_grant_edit_expires_switch'),
                value: enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: GestureDetector(
                key: const ValueKey('talk_record_grant_edit_expires_value'),
                behavior: HitTestBehavior.opaque,
                onTap: onPick,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.talkRecord.grantEditExpiresOn(
                            date: grantEditFormatDate(expiresAt),
                          ),
                          style: context.textStyle(
                            FontSizeType.body,
                            color: brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: AppSpacing.medium + 4,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: Text(
                t.talkRecord.grantEditExpiresHint,
                maxLines: null,
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 说明 / 横幅 / 保存
// ---------------------------------------------------------------------------

/// 编辑者不能管理 ACL/删除说明（UI-SPEC §2 明确要求展示）。
class TalkRecordEditorLimitHint extends StatelessWidget {
  const TalkRecordEditorLimitHint({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      key: const ValueKey('talk_record_grant_edit_editor_limit_hint'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny),
      child: Text(
        t.talkRecord.shareEditorCannotManageAcl,
        maxLines: null,
        style: context.textStyle(
          FontSizeType.footnote,
          color: brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class TalkRecordConflictBanner extends StatelessWidget {
  const TalkRecordConflictBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_grant_edit_conflict_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.regular),
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.getIosOrange(brightness).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t.talkRecord.grantEditConflict,
        maxLines: null,
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w600,
          color: AppColors.getIosOrange(brightness),
        ),
      ),
    );
  }
}

class TalkRecordSaveFailedBanner extends StatelessWidget {
  const TalkRecordSaveFailedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_grant_edit_save_failed_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.regular),
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.getIosOrange(brightness).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t.talkRecord.grantEditSaveFailed,
        maxLines: null,
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w600,
          color: AppColors.getIosOrange(brightness),
        ),
      ),
    );
  }
}

class TalkRecordSaveButton extends StatelessWidget {
  const TalkRecordSaveButton({
    super.key,
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // C-F2：主操作 ≥48pt、primaryDark 实底 + 白字 w600。
      height: 48,
      child: CupertinoButton(
        key: const ValueKey('talk_record_grant_edit_save'),
        minimumSize: const Size.fromHeight(48),
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(8),
        onPressed: enabled ? onPressed : null,
        child: Text(
          saving ? t.talkRecord.grantEditSaving : t.talkRecord.grantEditSave,
          style: context.textStyle(
            FontSizeType.body,
            fontWeight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(Brightness brightness) => BoxDecoration(
  color: brightness == Brightness.dark
      ? AppColors.darkSurface
      : AppColors.lightSurface,
  borderRadius: BorderRadius.circular(10),
);

/// 到期日期显示（yyyy-MM-dd；组件级本地格式，真机联调复核 locale）。
String grantEditFormatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
