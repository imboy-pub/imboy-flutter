/// 面聊记录（talk_record）编辑权限页（T18）。
///
/// 契约源：UI-SPEC §2「编辑权限」+ §3 角色表 + DESIGN §9：
/// - 候选选择（企业同事/个人联系人，fixture 候选集；候选≠授权凭证，§8）；
/// - 角色二选一：可查看与回听（viewer）/ 可校对与编辑（editor）——
///   分段控件选中态 C-F1；
/// - 允许导出开关：策略禁止时 disabled + 原因展示（§9；不能仅 UI 禁用，
///   服务端仍独立裁决）；
/// - 到期（可选）：开关 + 日期；到期后对方自动失去访问；
/// - 明确「编辑者不能管理 ACL 或删除」说明（UI-SPEC §2）；
/// - 保存 → PUT 全量授权 → 回名单（「权限已保存」反馈在名单页，
///   与发送卡片分离）。
///
/// 分区展示件见 talk_record_grant_edit_sections.dart。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_grant_edit_sections.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_providers.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart'
    show TalkRecordGrantInput, TalkRecordGrantModel;
import 'package:imboy/store/model/workspace_model.dart' show EntityId;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 编辑权限页（grantId 为空 = 新建授权；否则编辑现有授权）。
class TalkRecordGrantEditPage extends ConsumerStatefulWidget {
  const TalkRecordGrantEditPage({
    super.key,
    required this.recordId,
    this.grantId = '',
  });

  final String recordId;
  final String grantId;

  @override
  ConsumerState<TalkRecordGrantEditPage> createState() =>
      _TalkRecordGrantEditPageState();
}

class _TalkRecordGrantEditPageState
    extends ConsumerState<TalkRecordGrantEditPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  /// 表单状态（页面本地草稿；保存成功才提交）。
  TalkRecordGrantRole _role = TalkRecordGrantRole.viewer;
  bool _allowExport = false;
  bool _expiresEnabled = false;
  DateTime _expiresAt = DateTime(2099, 1, 1);
  TalkRecordShareCandidateModel? _selectedCandidate;
  bool _saving = false;
  bool _initializedFromGrant = false;

  bool get _isEditing => widget.grantId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(talkRecordShareCenterProvider.notifier).bind(widget.recordId);
      ref
          .read(talkRecordShareCandidatesProvider.notifier)
          .bind(widget.recordId);
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  void _hydrateFromGrant(TalkRecordGrantModel grant) {
    if (_initializedFromGrant) return;
    _initializedFromGrant = true;
    _role = grant.role;
    _allowExport = grant.allowExport;
    _expiresEnabled = grant.expiresAt != null;
    if (grant.expiresAt != null) _expiresAt = grant.expiresAt!;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final grantee = _granteeUserId();
    if (grantee.isEmpty) {
      setState(() => _saving = false);
      return;
    }
    final ok = await ref
        .read(talkRecordShareCenterProvider.notifier)
        .saveGrant(
          TalkRecordGrantInput(
            granteeUserId: grantee,
            role: _role,
            allowExport: _allowExport,
            expiresAt: _expiresEnabled ? _expiresAt : null,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // 保存成功回名单；「权限已保存」反馈在名单页（与发送卡片分离）。
      Navigator.of(context).pop();
    }
    // 失败/412：留在本页如实展示（输入保留，UI-SPEC §1 冲突不静默覆盖）。
  }

  EntityId _granteeUserId() {
    if (_isEditing) {
      final center = ref.read(talkRecordShareCenterProvider);
      for (final g in center.activeGrants) {
        if (g.id == widget.grantId) return g.granteeUserId;
      }
      return '';
    }
    return _selectedCandidate?.userId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(talkRecordShareCenterProvider);
    final Widget body;
    switch (center.phase) {
      case TalkRecordSharePhase.idle:
      case TalkRecordSharePhase.loading:
        body = const ShimmerList();
      case TalkRecordSharePhase.noAccess:
      case TalkRecordSharePhase.failed:
        body = const _NoAccessHint();
      case TalkRecordSharePhase.ready:
        body = _buildForm(context, center);
    }
    return IosPageTemplate(
      title: _isEditing
          ? t.talkRecord.grantEditTitle
          : t.talkRecord.grantEditTitleNew,
      body: body,
    );
  }

  Widget _buildForm(BuildContext context, TalkRecordShareCenterState center) {
    if (!center.canManage) {
      // 门控：非 owner 不出现授权表单（服务端同样拒绝，§4）。
      return const _NoAccessHint();
    }
    final grant = _isEditing ? _editingGrantOf(center) : null;
    if (_isEditing && grant == null) {
      return const _NoAccessHint();
    }
    if (grant != null) _hydrateFromGrant(grant);
    final policy = center.policy;
    final exportAllowed = policy?.exportGrantAllowed ?? false;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (grant != null)
              TalkRecordGrantGranteeCard(grant: grant)
            else
              TalkRecordCandidateSection(
                selected: _selectedCandidate,
                onSelect: (c) => setState(() => _selectedCandidate = c),
              ),
            const SizedBox(height: AppSpacing.xLarge),
            TalkRecordRoleSection(
              current: _role,
              onSelect: (r) => setState(() => _role = r),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            TalkRecordExportSection(
              value: _allowExport,
              enabled: exportAllowed,
              blockReason: policy?.exportBlockReason,
              onChanged: (v) => setState(() => _allowExport = v),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            TalkRecordExpiresSection(
              enabled: _expiresEnabled,
              expiresAt: _expiresAt,
              onToggle: (v) => setState(() => _expiresEnabled = v),
              onPick: _pickExpiresAt,
            ),
            const SizedBox(height: AppSpacing.xLarge),
            const TalkRecordEditorLimitHint(),
            if (center.writePhase == TalkRecordShareWritePhase.conflict)
              const TalkRecordConflictBanner(),
            if (center.writePhase == TalkRecordShareWritePhase.failed)
              const TalkRecordSaveFailedBanner(),
            const SizedBox(height: AppSpacing.regular),
            TalkRecordSaveButton(
              enabled: _canSave && !_saving,
              saving: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  TalkRecordGrantModel? _editingGrantOf(TalkRecordShareCenterState center) {
    for (final g in center.activeGrants) {
      if (g.id == widget.grantId) return g;
    }
    return null;
  }

  bool get _canSave =>
      _isEditing ||
      (_selectedCandidate != null && _selectedCandidate!.userId.isNotEmpty);

  Future<void> _pickExpiresAt() async {
    // sheet 内 onDateTimeChanged 实时更新本地草稿；关闭即保留所选日期。
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        key: const ValueKey('talk_record_grant_edit_expires_picker'),
        height: 280,
        color: Theme.of(sheetContext).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _expiresAt,
          minimumDate: DateTime.now(),
          onDateTimeChanged: (d) => setState(() => _expiresAt = d),
        ),
      ),
    );
  }
}

/// 无管理权限时的如实提示（非 owner 门控/加载失败共用）。
class _NoAccessHint extends StatelessWidget {
  const _NoAccessHint();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Text(
          t.talkRecord.shareEditorCannotManageAcl,
          textAlign: TextAlign.center,
          maxLines: null,
          style: context.textStyle(
            FontSizeType.body,
            color: brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}
