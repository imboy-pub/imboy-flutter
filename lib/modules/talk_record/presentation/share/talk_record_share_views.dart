/// 面聊记录（talk_record）分享管理名单视图与共享组件（T18）。
///
/// 从分享管理页（talk_record_share_manage_page.dart）拆出的展示件：
/// 可见范围概述卡、「谁可以查看」名单卡（创建者常驻行/授权行/空态/
/// 添加入口）与 pill/头像/横幅/行操作等基础件。行为契约见管理页头注释；
/// 本文件只做展示，不持有状态。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_providers.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

// ---------------------------------------------------------------------------
// 卡片与名单
// ---------------------------------------------------------------------------

/// 可见范围概述卡（§11.3：仅自己/已共享；完整名单仅 owner 本页可见）。
class TalkRecordShareVisibilityCard extends StatelessWidget {
  const TalkRecordShareVisibilityCard({super.key, required this.grantCount});

  final int grantCount;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_share_visibility_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.shareVisibilitySectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          // C-F3：概述可换行。
          Text(
            grantCount > 0
                ? t.talkRecord.shareVisibilityShared(count: grantCount)
                : t.talkRecord.shareVisibilityOwnerOnly,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.body,
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

/// 「谁可以查看」名单卡：创建者常驻行 + 授权行 + 添加入口。
class TalkRecordShareRosterCard extends StatelessWidget {
  const TalkRecordShareRosterCard({
    super.key,
    required this.state,
    required this.onRevoke,
  });

  final TalkRecordShareCenterState state;
  final void Function(TalkRecordGrantModel grant) onRevoke;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final record = state.record!;
    final isOrg = record.scope == TalkRecordScope.organization;
    final grants = state.activeGrants;
    return Container(
      key: const ValueKey('talk_record_share_roster_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.shareRosterSectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          const TalkRecordShareOwnerRow(),
          for (final grant in grants)
            TalkRecordGrantRowView(
              grant: grant,
              onEdit: () => _pushGrantEdit(context, grantId: grant.id),
              onRevoke: () => onRevoke(grant),
            ),
          if (grants.isEmpty) const TalkRecordShareEmptyGrants(),
          TalkRecordShareAddEntry(isOrg: isOrg, recordId: state.recordId),
        ],
      ),
    );
  }

  void _pushGrantEdit(BuildContext context, {String grantId = ''}) {
    final query = grantId.isEmpty ? '' : '?grant_id=$grantId';
    context.push(
      '$kTalkRecordDetailPath/${state.recordId}'
      '/share/$kTalkRecordGrantEditSegment$query',
    );
  }
}

/// 创建者常驻行（我 · 创建者；owner 在主表不在 grant，§2）。
class TalkRecordShareOwnerRow extends StatelessWidget {
  const TalkRecordShareOwnerRow({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_share_owner_row'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Row(
        children: [
          const TalkRecordAvatarBadge(icon: CupertinoIcons.person_crop_circle),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.talkRecord.shareOwnerRowLabel,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  t.talkRecord.shareOwnerRowHint,
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
          TalkRecordRolePill(
            key: const ValueKey('talk_record_share_owner_role_pill'),
            text: t.talkRecord.roleOwner,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

/// 授权行：首行姓名 + 角色 pill；次行标记 + 编辑/撤销操作
/// （UI-SPEC §1：操作放独立下一行，长姓名/角色不挤压正文）。
class TalkRecordGrantRowView extends StatelessWidget {
  const TalkRecordGrantRowView({
    super.key,
    required this.grant,
    required this.onEdit,
    required this.onRevoke,
  });

  final TalkRecordGrantModel grant;
  final VoidCallback onEdit;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isEditor = grant.role == TalkRecordGrantRole.editor;
    return Container(
      key: ValueKey('talk_record_share_grant_row_${grant.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: brightness == Brightness.dark
                ? AppColors.darkDivider
                : AppColors.lightDivider,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TalkRecordAvatarBadge(label: grant.granteeDisplayName),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Text(
                  grant.granteeDisplayName,
                  // C-F3：长姓名换行不截断。
                  maxLines: null,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              TalkRecordRolePill(
                key: ValueKey('talk_record_share_role_pill_${grant.id}'),
                text: isEditor
                    ? t.talkRecord.shareGrantRoleEditor
                    : t.talkRecord.shareGrantRoleViewer,
                emphasized: isEditor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (grant.allowExport)
                      TalkRecordMarkPill(
                        key: ValueKey(
                          'talk_record_share_export_pill_${grant.id}',
                        ),
                        text: t.talkRecord.shareAllowExportPill,
                      ),
                    if (grant.expiresAt != null)
                      TalkRecordMarkPill(
                        key: ValueKey(
                          'talk_record_share_expires_pill_${grant.id}',
                        ),
                        text: t.talkRecord.shareExpiresPill(
                          date: talkRecordShareFormatDate(grant.expiresAt!),
                        ),
                      ),
                  ],
                ),
              ),
              // C-F4：行内动作触达 ≥44。
              TalkRecordShareRowAction(
                key: ValueKey('talk_record_share_edit_action_${grant.id}'),
                label: t.talkRecord.shareGrantEditAction,
                onPressed: onEdit,
              ),
              TalkRecordShareRowAction(
                key: ValueKey('talk_record_share_revoke_action_${grant.id}'),
                label: t.talkRecord.shareGrantRevokeAction,
                destructive: true,
                onPressed: onRevoke,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 0 授权空态（默认仅创建者可见；共享=显式授权，不暗示全员可读）。
class TalkRecordShareEmptyGrants extends StatelessWidget {
  const TalkRecordShareEmptyGrants({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      key: const ValueKey('talk_record_share_empty_grants'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.shareEmptyTitle,
            style: context.textStyle(
              FontSizeType.body,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            t.talkRecord.shareEmptyBody,
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

/// 添加入口（企业=符合权限同事 / 个人=联系人，DESIGN §9）。
class TalkRecordShareAddEntry extends StatelessWidget {
  const TalkRecordShareAddEntry({
    super.key,
    required this.isOrg,
    required this.recordId,
  });

  final bool isOrg;
  final String recordId;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      key: const ValueKey('talk_record_share_add_entry'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(
        '$kTalkRecordDetailPath/$recordId/share/$kTalkRecordGrantEditSegment',
      ),
      child: ConstrainedBox(
        // C-F4：触达 ≥44。
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.person_badge_plus,
              size: AppSpacing.xLarge,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOrg
                        ? t.talkRecord.shareAddEntryOrg
                        : t.talkRecord.shareAddEntryPersonal,
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    isOrg
                        ? t.talkRecord.shareAddHintOrg
                        : t.talkRecord.shareAddHintPersonal,
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
            Icon(
              CupertinoIcons.add,
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
// 基础件（pill/头像/横幅/行操作）
// ---------------------------------------------------------------------------

/// 反馈横幅（保存/发送/冲突统一形态）。
class TalkRecordShareFeedbackBanner extends StatelessWidget {
  const TalkRecordShareFeedbackBanner({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: null,
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 行内动作（编辑/撤销；C-F4 触达 ≥44）。
class TalkRecordShareRowAction extends StatelessWidget {
  const TalkRecordShareRowAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.getIosRed(Theme.of(context).brightness)
        : AppColors.primaryDark;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Text(
        label,
        style: context.textStyle(
          FontSizeType.body,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 角色 pill（文字承载角色，不只靠颜色，UI-SPEC §1）。
class TalkRecordRolePill extends StatelessWidget {
  const TalkRecordRolePill({
    super.key,
    required this.text,
    this.emphasized = false,
  });

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(
          alpha: brightness == Brightness.dark ? 0.24 : 0.08,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: context.textStyle(
          FontSizeType.small,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// 标记 pill（可导出/到期等次级信息）。
class TalkRecordMarkPill extends StatelessWidget {
  const TalkRecordMarkPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: context.textStyle(FontSizeType.small, color: secondary),
      ),
    );
  }
}

/// 头像占位（图标或姓名首字）。
class TalkRecordAvatarBadge extends StatelessWidget {
  const TalkRecordAvatarBadge({super.key, this.icon, this.label});

  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final initial = (label == null || label!.isEmpty) ? '' : label![0];
    return Container(
      width: AppSpacing.xxxLarge + 8,
      height: AppSpacing.xxxLarge + 8,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? Icon(icon, size: AppSpacing.xLarge, color: AppColors.primaryDark)
          : Text(
              initial,
              style: context.textStyle(
                FontSizeType.normal,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
    );
  }
}

/// 卡片底色（明暗分组面）。
BoxDecoration talkRecordShareCardDecoration(Brightness brightness) =>
    BoxDecoration(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(10),
    );

/// 到期日期显示（yyyy-MM-dd；组件级本地格式，真机联调复核 locale）。
String talkRecordShareFormatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
