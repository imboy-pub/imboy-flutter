/// T9 (WP5) — 邀请工作区成员向导页
///
/// 步骤：按用户名/ID 搜索**已注册用户** → 选角色 → 勾选可选关系 → 提交；
/// 结果区三条独立展示（全称消歧）：
/// - 加入工作区（成为工作区成员）——必须成功
/// - 加入 General 群（成为群成员）——可选/可重试
/// - 订阅 Announcements 频道（成为频道订阅者）——可选/可重试
///
/// 可选关系调用既有 API：group join（member_uids 带入被邀人）与
/// channel subscribe（既有端点语义为订阅发起者本人——W0 后端无替他人
/// 订阅端点，此处按计划「调用既有 API」口径执行，语义差异记录在案）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_invite_code_controller.dart';
import 'package:imboy/page/workspace/workspace_invite_controller.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Template 资源定位（fallback：创建后改名也能找到默认资源）。
const String kWorkspaceDefaultGroupName = 'General';
const String kWorkspaceDefaultChannelName = 'Announcements';

/// 搜索结果用户条目（user/search 返回行的最小快照）。
class _CandidateUser {
  final EntityId id;
  final String nickname;
  final String account;

  const _CandidateUser({
    required this.id,
    required this.nickname,
    required this.account,
  });
}

class WorkspaceInvitePage extends ConsumerStatefulWidget {
  final EntityId workspaceId;

  const WorkspaceInvitePage({super.key, required this.workspaceId});

  @override
  ConsumerState<WorkspaceInvitePage> createState() =>
      _WorkspaceInvitePageState();
}

class _WorkspaceInvitePageState extends ConsumerState<WorkspaceInvitePage> {
  final TextEditingController _keywordCtrl = TextEditingController();
  final WorkspaceInviteResultsController _results =
      WorkspaceInviteResultsController();
  final WorkspaceInviteCodeController _inviteCode =
      WorkspaceInviteCodeController();

  List<_CandidateUser> _candidates = [];
  bool _searching = false;
  String? _searchError;
  _CandidateUser? _selected;
  WorkspaceMemberRole _role = WorkspaceMemberRole.member;
  bool _joinGroup = true;
  bool _subscribeChannel = true;
  bool _submitting = false;

  // Template 资源（General 群 / Announcements 频道）定位结果
  String _generalGroupId = '';
  String _announcementsChannelId = '';

  @override
  void initState() {
    super.initState();
    _locateTemplateResources();
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _results.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  /// 当前用户是否该工作区 Owner（镜像 members 页判定：成员列表里我的
  /// role == owner；服务端对 createInviteCode 仍有 403 兜底）。
  bool get _isOwner {
    final uid = UserRepoLocal.to.currentUid;
    if (uid.isEmpty) return false;
    final page = ref
        .watch(workspaceMembersProvider(widget.workspaceId))
        .whenOrNull(data: (value) => value);
    if (page == null) return false;
    return page.list.any(
      (m) => m.userId == uid && m.role == WorkspaceMemberRole.owner,
    );
  }

  /// 生成 / 重新生成团队码（后端同事务撤旧码：一工作区一个 active 码）。
  Future<void> _generateInviteCode() {
    return _inviteCode.generate(
      createInviteCode: () =>
          ref.read(workspaceApiProvider).createInviteCode(widget.workspaceId),
    );
  }

  /// 复制当前团队码（Clipboard + 轻提示，仓内复制惯例）。
  Future<void> _copyInviteCode() {
    final t = context.t;
    return _inviteCode.copy(
      writeToClipboard: (code) async {
        await Clipboard.setData(ClipboardData(text: code));
        if (mounted) AppLoading.showToast(t.main.copiedToClipboard);
      },
    );
  }

  /// 撤销当前团队码（成功后码清空，输码即 981）。
  Future<void> _revokeInviteCode() {
    return _inviteCode.revoke(
      revokeInviteCode: () =>
          ref.read(workspaceApiProvider).revokeInviteCode(widget.workspaceId),
    );
  }

  /// 定位 Template 默认资源：优先按名字精确匹配，找不到回落第一个
  /// workspace 资源（创建模板保证至少各一）。
  Future<void> _locateTemplateResources() async {
    try {
      final api = ref.read(workspaceApiProvider);
      final groups = await api.groups(widget.workspaceId);
      final channels = await api.channels(widget.workspaceId);
      if (!mounted) return;
      setState(() {
        final general = groups.where(
          (g) => g.title == kWorkspaceDefaultGroupName,
        );
        _generalGroupId = general.isNotEmpty
            ? general.first.groupId.toString()
            : (groups.isNotEmpty ? groups.first.groupId.toString() : '');
        final ann = channels.where(
          (c) => c.name == kWorkspaceDefaultChannelName,
        );
        _announcementsChannelId = ann.isNotEmpty
            ? ann.first.id.toString()
            : (channels.isNotEmpty ? channels.first.id.toString() : '');
      });
    } catch (_) {
      // 定位失败不阻塞邀请主流程：两项可选项各自置为不可用
      if (mounted) {
        setState(() {
          _generalGroupId = '';
          _announcementsChannelId = '';
        });
      }
    }
  }

  Future<void> _search() async {
    final keyword = _keywordCtrl.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final payload = await UserApi.to.userSearch(keyword: keyword, size: 20);
      final list = payload is Map<String, dynamic>
          ? (payload['list'] as List?)
          : null;
      final users = <_CandidateUser>[];
      if (list != null) {
        for (final row in list) {
          if (row is! Map<String, dynamic>) continue;
          final id = entityIdOf(row['id']);
          if (id.isEmpty) continue;
          // 排除自己与已是成员的重复目标由服务端幂等处理
          if (id == UserRepoLocal.to.currentUid) continue;
          users.add(
            _CandidateUser(
              id: id,
              nickname: row['nickname']?.toString() ?? '',
              account: row['account']?.toString() ?? '',
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() => _candidates = users);
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    final target = _selected;
    if (target == null || _submitting) return;
    setState(() => _submitting = true);
    _results.reset();
    final api = ref.read(workspaceApiProvider);
    final groupApi = GroupMemberApi();
    final channelApi = ChannelApi();
    final wsId = widget.workspaceId;

    await _results.submit(
      invite: () =>
          api.invite(workspaceId: wsId, userId: target.id, role: _role),
      joinGroup: _joinGroup && _generalGroupId.isNotEmpty
          ? () =>
                groupApi.join(gid: _generalGroupId, memberUserIds: [target.id])
          : null,
      subscribeChannel: _subscribeChannel && _announcementsChannelId.isNotEmpty
          ? () async {
              final ok = await channelApi.subscribe(_announcementsChannelId);
              if (!ok) {
                throw const WorkspaceApiException(1, 'subscribe failed');
              }
            }
          : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ref.invalidate(workspaceMembersProvider(wsId));
    ref.invalidate(workspaceOverviewProvider(wsId));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.inviteTitle)),
      body: ListView(
        padding: AppSpacing.allRegular,
        children: [
          Text(
            t.workspace.inviteDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalRegular,
          // 团队码卡片（仅 Owner；T2.6）：输码加入的另一半入口
          if (_isOwner) ...[
            _InviteCodeCard(
              controller: _inviteCode,
              onGenerate: _generateInviteCode,
              onCopy: _copyInviteCode,
              onRevoke: _revokeInviteCode,
            ),
            AppSpacing.verticalRegular,
          ],
          _SearchSection(
            controller: _keywordCtrl,
            searching: _searching,
            error: _searchError,
            onSearch: _search,
          ),
          if (_candidates.isNotEmpty) ...[
            AppSpacing.verticalRegular,
            ...[
              for (final u in _candidates)
                ListTile(
                  key: ValueKey('workspace-invite-candidate-${u.id}'),
                  dense: true,
                  leading: const Icon(CupertinoIcons.person_circle),
                  title: Text(u.nickname.isEmpty ? u.account : u.nickname),
                  subtitle: Text('@${u.account}'),
                  trailing: _selected == u
                      ? const Icon(
                          CupertinoIcons.check_mark,
                          color: AppColors.success,
                        )
                      : null,
                  onTap: () => setState(() => _selected = u),
                ),
            ],
          ],
          if (_selected != null) ...[
            AppSpacing.verticalRegular,
            _RolePicker(
              role: _role,
              onChanged: (r) => setState(() => _role = r),
            ),
            CheckboxListTile(
              key: const ValueKey('workspace-invite-join-group'),
              value: _joinGroup && _generalGroupId.isNotEmpty,
              onChanged: _generalGroupId.isEmpty
                  ? null
                  : (v) => setState(() => _joinGroup = v ?? false),
              title: Text(t.workspace.inviteJoinGroupOption),
              subtitle: _generalGroupId.isEmpty
                  ? Text(
                      t.workspace.inviteOptionUnavailable,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              key: const ValueKey('workspace-invite-subscribe-channel'),
              value: _subscribeChannel && _announcementsChannelId.isNotEmpty,
              onChanged: _announcementsChannelId.isEmpty
                  ? null
                  : (v) => setState(() => _subscribeChannel = v ?? false),
              title: Text(t.workspace.inviteSubscribeChannelOption),
              subtitle: _announcementsChannelId.isEmpty
                  ? Text(
                      t.workspace.inviteOptionUnavailable,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            AppSpacing.verticalRegular,
            FilledButton(
              key: const ValueKey('workspace-invite-submit'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.workspace.inviteSubmit),
            ),
          ],
          AppSpacing.verticalRegular,
          _ResultsSection(
            controller: _results,
            onRetryGroup: _retryGroup,
            onRetryChannel: _retryChannel,
          ),
        ],
      ),
    );
  }

  Future<void> _retryGroup() async {
    final target = _selected;
    if (target == null || _generalGroupId.isEmpty) return;
    await _results.retryGroup(
      () => GroupMemberApi().join(
        gid: _generalGroupId,
        memberUserIds: [target.id],
      ),
    );
  }

  Future<void> _retryChannel() async {
    if (_announcementsChannelId.isEmpty) return;
    await _results.retryChannel(() async {
      final ok = await ChannelApi().subscribe(_announcementsChannelId);
      if (!ok) {
        throw const WorkspaceApiException(1, 'subscribe failed');
      }
    });
  }
}

/// 搜索区。
class _SearchSection extends StatelessWidget {
  final TextEditingController controller;
  final bool searching;
  final String? error;
  final VoidCallback onSearch;

  const _SearchSection({
    required this.controller,
    required this.searching,
    required this.error,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CupertinoSearchTextField(
                controller: controller,
                placeholder: t.workspace.inviteSearchHint,
                onSubmitted: (_) => onSearch(),
              ),
            ),
            AppSpacing.horizontalSmall,
            IconButton(
              key: const ValueKey('workspace-invite-search-btn'),
              tooltip: t.workspace.inviteSearchHint,
              onPressed: searching ? null : onSearch,
              icon: searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.search),
            ),
          ],
        ),
        if (error != null) ...[
          AppSpacing.verticalTiny,
          Text(
            error!,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.iosRed),
          ),
        ],
      ],
    );
  }
}

/// 角色选择（Owner 仅服务端兜底；默认 member）。
class _RolePicker extends StatelessWidget {
  final WorkspaceMemberRole role;
  final ValueChanged<WorkspaceMemberRole> onChanged;

  const _RolePicker({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SegmentedButton<WorkspaceMemberRole>(
      key: const ValueKey('workspace-invite-role'),
      segments: [
        ButtonSegment(
          value: WorkspaceMemberRole.member,
          label: Text(t.workspace.roleMember),
        ),
        ButtonSegment(
          value: WorkspaceMemberRole.guest,
          label: Text(t.workspace.roleGuest),
        ),
      ],
      selected: {role},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// 三条独立结果区（全称消歧 + 独立状态 + 独立重试）。
class _ResultsSection extends StatelessWidget {
  final WorkspaceInviteResultsController controller;
  final VoidCallback onRetryGroup;
  final VoidCallback onRetryChannel;

  const _ResultsSection({
    required this.controller,
    required this.onRetryGroup,
    required this.onRetryChannel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.state;
        return WorkspaceSectionCard(
          title: t.workspace.inviteResultsTitle,
          child: Column(
            children: [
              _ResultRow(
                key: const ValueKey('workspace-invite-result-workspace'),
                label: t.workspace.inviteResultWorkspace,
                result: s.workspace,
              ),
              AppSpacing.verticalSmall,
              _ResultRow(
                key: const ValueKey('workspace-invite-result-group'),
                label: t.workspace.inviteResultGroup,
                result: s.group,
              ),
              AppSpacing.verticalSmall,
              _ResultRow(
                key: const ValueKey('workspace-invite-result-channel'),
                label: t.workspace.inviteResultChannel,
                result: s.channel,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final WorkspaceRelationResult result;

  const _ResultRow({super.key, required this.label, required this.result});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final (icon, color, text) = switch (result.phase) {
      WorkspaceRelationPhase.idle => (
        CupertinoIcons.minus_circle,
        theme.colorScheme.onSurfaceVariant,
        t.workspace.resultIdle,
      ),
      WorkspaceRelationPhase.running => (
        CupertinoIcons.clock,
        theme.colorScheme.onSurfaceVariant,
        t.workspace.resultRunning,
      ),
      WorkspaceRelationPhase.success => (
        CupertinoIcons.check_mark_circled,
        AppColors.success,
        t.workspace.resultSuccess,
      ),
      WorkspaceRelationPhase.failed => (
        CupertinoIcons.xmark_circle,
        AppColors.iosRed,
        result.message.isEmpty ? t.workspace.resultFailed : result.message,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        AppSpacing.horizontalSmall,
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          text,
          // 结果状态字：脚注档 footnote（13px）
          style: TextStyle(fontSize: FontSizeType.footnote.size, color: color),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// 团队码卡片（T2.6，仅 Owner）：生成/重新生成 + 复制 + 有效期 + 撤销。
///
/// 契约口径：一工作区一个 active 码；「重新生成」后端同事务撤旧码（覆盖），
/// 「撤销」走独立 revoke 端点（成功后码清空，输码即 981）。
class _InviteCodeCard extends StatelessWidget {
  final WorkspaceInviteCodeController controller;
  final VoidCallback onGenerate;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;

  const _InviteCodeCard({
    required this.controller,
    required this.onGenerate,
    required this.onCopy,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.state;
        return WorkspaceSectionCard(
          title: t.workspace.inviteCodeSectionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.phase == WorkspaceInviteCodePhase.ready) ...[
                SelectableText(
                  key: const ValueKey('workspace-invite-code-text'),
                  s.inviteCode.code,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                AppSpacing.verticalTiny,
                Text(
                  t.workspace.inviteCodeExpiresAt(
                    expiresAt: s.inviteCode.expiresAtLabel,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.verticalSmall,
              ],
              if (s.message.isNotEmpty) ...[
                Text(
                  s.message,
                  key: const ValueKey('workspace-invite-code-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                AppSpacing.verticalSmall,
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('workspace-invite-code-generate'),
                      onPressed: controller.isGenerating ? null : onGenerate,
                      icon: controller.isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(CupertinoIcons.qrcode),
                      // 生成 / 重新生成共用（重新生成覆盖旧码即撤销）
                      label: Text(t.workspace.inviteCodeGenerate),
                    ),
                  ),
                  if (s.phase == WorkspaceInviteCodePhase.ready) ...[
                    AppSpacing.horizontalSmall,
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('workspace-invite-code-copy'),
                        // 撤销在途时禁复制（可能复制到正被撤销的码）
                        onPressed: controller.isRevoking ? null : onCopy,
                        icon: const Icon(CupertinoIcons.doc_on_doc),
                        label: Text(t.workspace.inviteCodeCopy),
                      ),
                    ),
                  ],
                ],
              ),
              if (s.phase == WorkspaceInviteCodePhase.ready) ...[
                AppSpacing.verticalSmall,
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('workspace-invite-code-revoke'),
                    onPressed: controller.isRevoking ? null : onRevoke,
                    child: Text(
                      t.workspace.inviteCodeRevoke,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
