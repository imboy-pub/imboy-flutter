/// 邀请页（双模式）：
/// - 治理模式（owner/admin）：列表 · 创建（一次性 token 只显示一次）· 撤销；
/// - 我的模式（?mode=mine）：收到的邀请 · 免口令两步确认接受 · 拒绝 · 过期展示。
///
/// C11 语义 + P0 直达：token 明文只在 create 响应出现一次；定向邀请
/// （target_user_id 必填）以当前登录身份即凭据，接受时无需口令——
/// 行点击为第一步，确认弹窗为第二步；显式口令路径仍由 API 层保留
/// （向后兼容）。pending 不进 membership，接受成功后成员资格以服务端
/// 为准（本页只刷新邀请事实，不本地拼装成员行）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
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
      title: t.organization.invitations.inviteMember,
      hint: t.organization.common.targetUidHint,
    );
    if (uidText == null) return;
    final targetUid = int.tryParse(uidText);
    if (targetUid == null || targetUid <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(t.organization.common.uidMustBePositive)),
      );
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
          title: Text(t.organization.invitations.invitationCreated),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.organization.invitations.tokenOnceNotice),
              const SizedBox(height: AppSpacing.small),
              SelectableText(inv.token),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inv.token));
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  SnackBar(
                    content: Text(t.organization.invitations.tokenCopied),
                  ),
                );
              },
              icon: const Icon(CupertinoIcons.doc_on_doc),
              label: Text(t.organization.invitations.copyToken),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.organization.common.close),
            ),
          ],
        ),
      );
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            t.organization.invitations.inviteFailed(
              msg: e.message,
              code: e.code,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _accept(OrgInvitation inv) async {
    // 免口令（P0 定向邀请直达）：行点击已算第一步，这里是第二步确认。
    final ok = await orgConfirmAction(
      context,
      title: t.organization.invitations.acceptTitle,
      consequence: t.organization.invitations.acceptBody(
        orgId: inv.organizationId,
      ),
      confirmText: t.organization.invitations.confirmAccept,
    );
    if (!ok) return;
    await _runCommand(
      () => _api.acceptInvitation(inv.organizationId),
      t.organization.invitations.acceptFailed,
    );
  }

  Future<void> _reject(OrgInvitation inv) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.invitations.rejectTitle,
      consequence: t.organization.invitations.rejectBody,
      confirmText: t.organization.invitations.confirmReject,
    );
    if (ok) {
      await _runCommand(
        () => _api.rejectInvitation(inv.organizationId, inv.invitationId),
        t.organization.invitations.rejectFailed,
      );
    }
  }

  Future<void> _revoke(OrgInvitation inv) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.invitations.revokeTitle,
      consequence: t.organization.invitations.revokeBody,
      confirmText: t.organization.invitations.confirmRevoke,
    );
    if (ok) {
      await _runCommand(
        () => _api.revokeInvitation(inv.organizationId, inv.invitationId),
        t.organization.invitations.revokeFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mineMode
              ? t.organization.invitations.myInvitations
              : t.organization.invitations.manageInvitations,
        ),
        actions: [
          if (!widget.mineMode)
            Semantics(
              button: true,
              label: t.organization.invitations.createInvitation,
              child: IconButton(
                icon: const Icon(CupertinoIcons.add),
                tooltip: t.organization.invitations.createInvitation,
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
          emptyText: widget.mineMode
              ? t.organization.invitations.empty
              : t.organization.invitations.emptyRecord,
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
                        ? t.organization.invitations.orgLine(
                            orgId: inv.organizationId,
                          )
                        : t.organization.invitations.invitationLine(
                            invitationId: inv.invitationId,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    widget.mineMode
                        ? invitationSubtitle(inv)
                        : t.organization.invitations.targetLine(
                            targetUserId: inv.targetUserId,
                            subtitle: invitationSubtitle(inv),
                          ),
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
                    t.organization.invitations.acceptNotice,
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
      return const Icon(CupertinoIcons.chevron_right);
    }
    if (!widget.mineMode && inv.isPending) {
      return TextButton(
        onPressed: () => _revoke(inv),
        child: Text(t.organization.invitations.revokeAction),
      );
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
              leading: const Icon(CupertinoIcons.checkmark_circle),
              title: Text(t.organization.invitations.acceptAction),
              onTap: () => Navigator.of(ctx).pop('accept'),
            ),
            ListTile(
              leading: Icon(
                CupertinoIcons.xmark_circle,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                t.organization.invitations.rejectAction,
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
