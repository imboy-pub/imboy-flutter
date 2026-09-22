/// 企业群治理页（FULL-05 / INT-18..21 的界面与状态）。
///
/// 承载四个能力点，全部走同一 [EnterpriseAppApi]（通道未绑定时诚实失败并
/// 展示 `errorUnbound*` 文案，不伪造数据）：
/// - 详情（INT-18）：标题 / 归档态 / 成员与角色（超限时明确「已停止加载」）；
/// - 更新（INT-19）：改名（空更新本地即拒）；
/// - 归档（INT-21）：**单向**，需二次确认，归档后隐藏全部写入口；
/// - 成员角色（INT-20）：候选角色**只来自**
///   [EnterpriseGroupRole.assignableRoles]，群主不可改、不可分配。
///
/// 颜色/间距/字号一律走 token；文案走 `enterpriseApp` 命名空间。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_app_error.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_group_admin.dart';
import 'package:imboy/modules/enterprise_app/infrastructure/enterprise_app_api.dart';
import 'package:imboy/modules/enterprise_app/presentation/enterprise_error_view.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class EnterpriseGroupPage extends StatefulWidget {
  const EnterpriseGroupPage({
    super.key,
    required this.groupId,
    this.api,
    this.idempotencyKeyFactory,
  });

  final EntityId groupId;

  /// 可注入客户端（测试注入 fake transport 的 api）。
  final EnterpriseAppApi? api;

  /// 幂等键工厂（写操作每用户动作一个键；重试复用同键 → 服务端重放原结果）。
  final String Function()? idempotencyKeyFactory;

  @override
  State<EnterpriseGroupPage> createState() => _EnterpriseGroupPageState();
}

class _EnterpriseGroupPageState extends State<EnterpriseGroupPage> {
  late final EnterpriseAppApi _api = widget.api ?? EnterpriseAppApi();
  late final String Function() _keyFactory =
      widget.idempotencyKeyFactory ?? _defaultKey;

  EnterpriseGroupDetail? _detail;
  EnterpriseErrorUiState? _error;
  bool _busy = false;

  /// 单调递增计数器：同一动作的重试复用同一键（服务端重放），
  /// 不同用户动作必须是不同键（否则会被判 idempotency_conflict）。
  static int _seq = 0;
  static String _defaultKey() =>
      'ui-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final EnterpriseGroupDetail detail = await _api.groupDetail(
        widget.groupId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _busy = false;
      });
    } on EnterpriseAppApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.uiState;
        _busy = false;
      });
    }
  }

  Future<void> _rename() async {
    final EnterpriseGroupDetail? detail = _detail;
    if (detail == null || detail.isArchived) return;
    final String? next = await _promptText(
      title: t.enterpriseApp.groupActionRename,
      hint: t.enterpriseApp.groupRenameHint,
      initial: detail.title,
    );
    if (next == null) return;
    final EnterpriseGroupUpdateDraft draft = EnterpriseGroupUpdateDraft(
      title: next,
    );
    await _guard(() async {
      await _api.updateGroup(
        widget.groupId,
        draft: draft,
        idempotencyKey: _keyFactory(),
      );
    });
  }

  Future<void> _archive() async {
    final EnterpriseGroupDetail? detail = _detail;
    if (detail == null || !detail.canArchive) return;
    final bool confirmed = await _confirm(
      title: t.enterpriseApp.groupArchiveTitle,
      hint: t.enterpriseApp.groupArchiveHint,
    );
    if (!confirmed) return;
    await _guard(() async {
      await _api.archiveGroup(widget.groupId, idempotencyKey: _keyFactory());
    });
  }

  Future<void> _setRole(
    EnterpriseGroupMember member,
    EnterpriseGroupRole role,
  ) async {
    await _guard(() async {
      await _api.setMemberRoles(
        widget.groupId,
        assignments: <EnterpriseGroupRoleAssignment>[
          EnterpriseGroupRoleAssignment(
            externalUserId: member.externalUserId.isEmpty
                ? member.userId
                : member.externalUserId,
            role: role,
          ),
        ],
        idempotencyKey: _keyFactory(),
      );
    });
  }

  /// 统一写操作守卫：busy 标记 + 错误归一 + 成功后刷新。
  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _busy = false);
      await _load();
    } on EnterpriseAppApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.uiState;
        _busy = false;
      });
    }
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initial,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: EnterpriseGroupUpdateDraft.maxTitleLength,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<bool> _confirm({required String title, required String hint}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(hint),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.enterpriseApp.groupActionArchive),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final EnterpriseErrorUiState? error = _error;
    final EnterpriseGroupDetail? detail = _detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.enterpriseApp.groupTitle),
        actions: <Widget>[
          if (detail != null && !detail.isArchived)
            IconButton(
              onPressed: _busy ? null : _rename,
              icon: const Icon(CupertinoIcons.pencil),
              tooltip: t.enterpriseApp.groupActionRename,
            ),
          if (detail != null && detail.canArchive)
            IconButton(
              onPressed: _busy ? null : _archive,
              icon: const Icon(CupertinoIcons.archivebox),
              tooltip: t.enterpriseApp.groupActionArchive,
            ),
        ],
      ),
      body: _buildBody(error: error, detail: detail),
    );
  }

  Widget _buildBody({
    required EnterpriseErrorUiState? error,
    required EnterpriseGroupDetail? detail,
  }) {
    if (error != null) {
      return SingleChildScrollView(
        child: EnterpriseErrorView(state: error, onRetry: _load),
      );
    }
    if (detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _GroupHeader(detail: detail),
          AppSpacing.verticalSmall,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
            child: Text(
              t.enterpriseApp.groupMembersTitle,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.slateText,
              ),
            ),
          ),
          ..._memberTiles(detail),
        ],
      ),
    );
  }

  List<Widget> _memberTiles(EnterpriseGroupDetail detail) {
    if (detail.members.isEmpty) {
      return <Widget>[EnterpriseEmptyView(message: t.enterpriseApp.groupEmpty)];
    }
    return detail.members
        .map(
          (EnterpriseGroupMember m) => ListTile(
            title: Text(m.userId),
            subtitle: Text(_roleLabel(m.role)),
            trailing: m.role.isLocked
                ? Tooltip(
                    message: t.enterpriseApp.groupRoleOwnerLocked,
                    child: const Icon(
                      CupertinoIcons.lock,
                      color: AppColors.slateText,
                    ),
                  )
                : PopupMenuButton<EnterpriseGroupRole>(
                    onSelected: (EnterpriseGroupRole r) => _setRole(m, r),
                    itemBuilder: (_) => EnterpriseGroupRole.assignableRoles
                        .map(
                          (EnterpriseGroupRole r) =>
                              PopupMenuItem<EnterpriseGroupRole>(
                                value: r,
                                child: Text(_roleLabel(r)),
                              ),
                        )
                        .toList(),
                  ),
          ),
        )
        .toList();
  }

  String _roleLabel(EnterpriseGroupRole role) {
    switch (role) {
      case EnterpriseGroupRole.owner:
        return t.enterpriseApp.groupRoleOwner;
      case EnterpriseGroupRole.admin:
        return t.enterpriseApp.groupRoleAdmin;
      case EnterpriseGroupRole.guest:
        return t.enterpriseApp.groupRoleGuest;
      case EnterpriseGroupRole.viceOwner:
        return t.enterpriseApp.groupRoleViceOwner;
      case EnterpriseGroupRole.member:
      case EnterpriseGroupRole.undefined:
        return t.enterpriseApp.groupRoleMember;
    }
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.detail});

  final EnterpriseGroupDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(
            detail.title.isEmpty ? detail.groupId : detail.title,
            style: context.textStyle(
              FontSizeType.medium,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            detail.memberCount >= kEnterpriseGroupMaxDetailMembers
                ? t.enterpriseApp.groupOverLimit
                : '${detail.memberCount}',
          ),
        ),
        if (detail.isArchived)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
            child: Chip(
              label: Text(t.enterpriseApp.groupArchivedBadge),
              backgroundColor: AppColors.slateText.withValues(alpha: 0.14),
            ),
          ),
      ],
    );
  }
}

/// 打开企业群页（供路由/入口调用）。
Future<void> openEnterpriseGroupPage(
  BuildContext context, {
  required EntityId groupId,
  EnterpriseAppApi? api,
}) {
  return Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => EnterpriseGroupPage(groupId: groupId, api: api),
    ),
  );
}
