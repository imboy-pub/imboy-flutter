/// 邀请页（双模式）：
/// - 治理模式（owner/admin）：列表 · 创建（一次性 token 只显示一次）· 撤销；
/// - 我的模式（?mode=mine）：收到的邀请 · 持 token 接受 · 拒绝 · 过期展示。
///
/// C11 语义冻结：token 明文只在 create 响应出现一次；accept 需要目标用户
/// 持有 token（口令式）；pending 不进 membership，接受成功后成员资格
/// 以服务端为准（本页只刷新邀请事实，不本地拼装成员行）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class OrganizationInvitationsPage extends StatefulWidget {
  const OrganizationInvitationsPage({
    super.key,
    required this.orgId,
    required this.mineMode,
    this.accountKey,
  });

  /// 我的模式下忽略（服务端按当前 JWT 解析 target）。
  final EntityId orgId;
  final bool mineMode;
  final String? accountKey;

  @override
  State<OrganizationInvitationsPage> createState() =>
      _OrganizationInvitationsPageState();
}

class _OrganizationInvitationsPageState
    extends State<OrganizationInvitationsPage> {
  final OrganizationApi _api = OrganizationApi();

  List<OrgInvitation> _items = const [];
  bool _loading = false;
  bool _permissionDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final items = widget.mineMode
          ? await _api.myInvitations()
          : await _api.orgInvitations(widget.orgId);
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = e.isForbidden && !widget.mineMode;
        _error = e.isForbidden ? null : '${e.message} (code=${e.code})';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _runCommand(
    Future<OrgInvitation> Function() action,
    String failureTitle,
  ) async {
    try {
      await action();
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('$failureTitle：${e.message} (${e.code})')),
      );
    }
    await _refresh();
  }

  Future<void> _create() async {
    final uidText = await orgPromptInput(
      context,
      title: '邀请成员',
      hint: '对方用户 UID（数字）',
    );
    if (uidText == null) return;
    final targetUid = int.tryParse(uidText);
    if (targetUid == null || targetUid <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('用户 UID 必须是正整数')));
      return;
    }
    try {
      final inv = await _api.createInvitation(widget.orgId, '$targetUid');
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      // 一次性 token：仅本次弹窗可见（C11：create 响应后服务端只存
      // digest），提示复制并线下转交；App 不持久化。
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('邀请已创建'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('领取口令（token）只显示这一次，请立即复制并线下转交对方：'),
              const SizedBox(height: AppSpacing.small),
              SelectableText(inv.token),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inv.token));
                ScaffoldMessenger.maybeOf(ctx)
                    ?.showSnackBar(const SnackBar(content: Text('已复制口令')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('复制口令'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('邀请失败：${e.message} (${e.code})')));
    }
  }

  Future<void> _accept(OrgInvitation inv) async {
    final token = await orgPromptInput(
      context,
      title: '接受邀请',
      hint: '粘贴邀请人给你的领取口令（token）',
    );
    if (token == null) return;
    await _runCommand(
      () => _api.acceptInvitation(inv.organizationId, token: token),
      '接受失败',
    );
  }

  Future<void> _reject(OrgInvitation inv) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: '拒绝邀请',
      consequence: '拒绝后该邀请进入终态，不可再接受。',
      confirmText: '确认拒绝',
    );
    if (ok) {
      await _runCommand(
        () => _api.rejectInvitation(inv.organizationId, inv.invitationId),
        '拒绝失败',
      );
    }
  }

  Future<void> _revoke(OrgInvitation inv) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: '撤销邀请',
      consequence: '撤销后该邀请进入终态，目标用户无法再凭口令接受。',
      confirmText: '确认撤销',
    );
    if (ok) {
      await _runCommand(
        () => _api.revokeInvitation(inv.organizationId, inv.invitationId),
        '撤销失败',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mineMode ? '我的邀请' : '邀请管理'),
        actions: [
          if (!widget.mineMode)
            Semantics(
              button: true,
              label: '创建邀请',
              child: IconButton(
                icon: const Icon(Icons.add),
                tooltip: '创建邀请',
                onPressed: _create,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && _items.isEmpty,
          error: _error,
          permissionDenied: _permissionDenied,
          empty:
              !_loading &&
              !_permissionDenied &&
              _error == null &&
              _items.isEmpty,
          emptyText: widget.mineMode ? '暂无邀请' : '暂无邀请记录',
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              for (final inv in _items)
                ListTile(
                  leading: Icon(
                    inv.isPending
                        ? CupertinoIcons.mail_solid
                        : (inv.isExpired
                              ? CupertinoIcons.clock
                              : CupertinoIcons.mail),
                  ),
                  title: Text(
                    widget.mineMode
                        ? '组织 ${inv.organizationId}'
                        : '邀请 ${inv.invitationId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    widget.mineMode
                        ? invitationSubtitle(inv)
                        : '目标 ${inv.targetUserId} · ${invitationSubtitle(inv)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _buildActionChip(inv),
                  onTap: _buildAction(inv),
                ),
              if (widget.mineMode)
                ListTile(
                  dense: true,
                  title: Text(
                    '接受邀请需要邀请人提供的领取口令（token）；'
                    '接受成功后成员资格以服务端为准。',
                    style: context.textStyle(FontSizeType.small),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildActionChip(OrgInvitation inv) {
    if (widget.mineMode && inv.isPending) {
      return const Icon(Icons.chevron_right);
    }
    if (!widget.mineMode && inv.isPending) {
      return TextButton(onPressed: () => _revoke(inv), child: const Text('撤销'));
    }
    return null;
  }

  VoidCallback? _buildAction(OrgInvitation inv) {
    if (widget.mineMode && inv.isPending) {
      return () => _showMineActions(inv);
    }
    return null;
  }

  Future<void> _showMineActions(OrgInvitation inv) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('凭口令接受'),
              onTap: () => Navigator.of(ctx).pop('accept'),
            ),
            ListTile(
              leading: Icon(
                Icons.cancel_outlined,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                '拒绝',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () => Navigator.of(ctx).pop('reject'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'accept':
        await _accept(inv);
      case 'reject':
        await _reject(inv);
    }
  }
}
