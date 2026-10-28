/// W05（channel-group-ux-v2.2 F10/实际工作区成员选择器）：工作区建群页。
///
/// - 成员来源是**真实工作区成员 API**（GET /api/v1/workspaces/:id/members），
///   不是好友列表；本地关键词过滤，加载失败区分错误态并可重试。
/// - 创建走受理合同（manifest 能力门，W04.b/W04.d.g）：先存后发、
///   24h 派发、重放原键原载荷；capabilityMissing 且无未知意图时回落
///   键less workspace 建群（成员集语义不变，无初始名）；已有未知意图
///   绝不剥键走旧 POST。
/// - 选人只决定群初始成员集合，**无顺带加入授权**：不改工作区成员、
///   不改角色，guest/无资格由服务端拒绝、客户端只解释（J03.a）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';
import 'package:imboy/service/creation_receipt/group_creation_receipt_service.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class WorkspaceGroupCreatePage extends ConsumerStatefulWidget {
  const WorkspaceGroupCreatePage({super.key, required this.workspaceId});

  final EntityId workspaceId;

  @override
  ConsumerState<WorkspaceGroupCreatePage> createState() =>
      _WorkspaceGroupCreatePageState();
}

class _WorkspaceGroupCreatePageState
    extends ConsumerState<WorkspaceGroupCreatePage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _search = TextEditingController();

  List<WorkspaceMemberModel> _members = const [];
  final Set<EntityId> _selected = <EntityId>{};
  bool _loading = true;
  bool _loadError = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  @override
  void dispose() {
    _title.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      // 实际工作区成员 API（与成员管理页同源）；本页规模取第一页 50。
      final page = await ref
          .read(workspaceApiProvider)
          .members(widget.workspaceId, size: 50);
      if (!mounted) return;
      setState(() => _members = page.list);
    } catch (e) {
      iPrint('[WorkspaceGroupCreatePage] load members failed: $e');
      if (mounted) setState(() => _loadError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<WorkspaceMemberModel> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members
        .where(
          (m) =>
              m.nickname.toLowerCase().contains(q) ||
              m.account.toLowerCase().contains(q),
        )
        .toList();
  }

  void _toggle(WorkspaceMemberModel m) {
    setState(() {
      if (!_selected.add(m.userId)) {
        _selected.remove(m.userId);
      }
    });
  }

  Future<void> _create() async {
    if (_creating || _selected.isEmpty) return;
    setState(() => _creating = true);
    AppLoading.show(status: t.common.loading);
    try {
      final title = _title.text.trim();
      final memberUserIds = _selected.map((id) => id).toList();
      final receipt = await GroupCreationReceiptService().createOrRecoverGroup(
        account: UserRepoLocal.to.currentUid,
        workspaceId: widget.workspaceId,
        memberUserIds: memberUserIds,
        title: title.isEmpty ? null : title,
      );
      if (receipt.ok) {
        AppLoading.dismiss();
        if (mounted) {
          AppLoading.showToast(t.group.groupCreated);
          Navigator.of(context).pop();
        }
        return;
      }
      if (receipt.failure == CreationFlowFailure.capabilityMissing &&
          !receipt.pendingIntentBlocked) {
        // 能力未启用且无未知意图：键less workspace 建群回退（成员集语义
        // 不变；初始名是合同增量，回退路径不带）。
        final r = await GroupApi().createWorkspaceGroup(
          workspaceId: widget.workspaceId,
          memberUserIds: memberUserIds,
        );
        AppLoading.dismiss();
        if (mounted) {
          if (r.error != null) {
            AppLoading.showError(r.error ?? t.common.tipFailed);
          } else {
            AppLoading.showToast(t.group.groupCreated);
            Navigator.of(context).pop();
          }
        }
        return;
      }
      // conflict/notAccepted/unknown：意图保留；expired/unavailable：已清。
      // capabilityMissing+未知意图：不剥键。统一展示可重试的失败文案。
      AppLoading.dismiss();
      if (mounted) {
        AppLoading.showError(
          receipt.errorText ??
              t.organization.manage.creationRecoveryUnavailable,
        );
      }
    } catch (e) {
      iPrint('[WorkspaceGroupCreatePage] create failed: $e');
      AppLoading.dismiss();
      if (mounted) AppLoading.showError(t.common.tipFailed);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visible = _visible;
    final searching = _search.text.trim().isNotEmpty;
    return IosPageTemplate(
      title: t.organization.manage.createGroup,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.regular,
                AppSpacing.regular,
                AppSpacing.regular,
                0,
              ),
              child: CupertinoTextField(
                controller: _title,
                placeholder: t.organization.manage.groupNameHint,
                maxLength: 200,
                enabled: !_creating,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.regular,
                AppSpacing.small,
                AppSpacing.regular,
                0,
              ),
              child: CupertinoSearchTextField(
                controller: _search,
                placeholder: '${t.common.selectContacts} · ${t.common.search}',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _loadError
                  ? _errorView()
                  : visible.isEmpty
                  ? Center(
                      child: Text(
                        searching ? t.common.searchNoResults : t.common.noData,
                        style: context.textStyle(
                          FontSizeType.subheadline,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.regular,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => AppSpacing.verticalTiny,
                      itemBuilder: (context, index) =>
                          _memberRow(context, visible[index]),
                    ),
            ),
            Padding(
              padding: AppSpacing.allRegular,
              child: RoundedCupertinoButton(
                text: _selected.isEmpty
                    ? t.organization.manage.createGroup
                    : '${t.organization.manage.createGroup}(${_selected.length + 1})',
                highlighted: _selected.isNotEmpty && !_creating,
                onPressed: _selected.isEmpty || _creating ? null : _create,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 44,
            color: AppColors.iosRed,
          ),
          AppSpacing.verticalRegular,
          Text(
            t.common.errorNetwork,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalMedium,
          CupertinoButton(
            onPressed: _loadMembers,
            child: Text(
              t.common.buttonRetry,
              style: context.textStyle(
                FontSizeType.body,
                color: AppColors.getIosBlue(Theme.of(context).brightness),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(BuildContext context, WorkspaceMemberModel m) {
    final isSelected = _selected.contains(m.userId);
    final colorScheme = Theme.of(context).colorScheme;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _creating ? null : () => _toggle(m),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.regular,
                right: AppSpacing.medium,
              ),
              child: Icon(
                isSelected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: isSelected
                    ? AppColors.getIosBlue(Theme.of(context).brightness)
                    : colorScheme.outline.withValues(alpha: 0.3),
                size: 26,
              ),
            ),
            Avatar(imgUri: m.avatar, width: 40, height: 40),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Text(
                m.nickname.isEmpty ? m.account : m.nickname,
                style: context.textStyle(
                  FontSizeType.body,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
