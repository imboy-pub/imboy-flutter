/// 企业邀请二维码页（GZAPP-J11 出码侧）：
/// Owner/Admin 出示本企业邀请二维码 + 明码口令，成员扫码或输码即可加入，
/// 不再需要手输 19 位企业 ID（用户加入体验收敛：双输入 → 扫码/单码）。
///
/// 数据面：治理面 GET/POST /organizations/:orgId/invite_code
/// （一组织至多一个 active 码；重新生成 = 旧码立即失效；7 天有效）。
/// QR payload 契约：`imboy://org/join?c=<CODE>`，扫码端由
/// OrgJoinScannerPage 解析；明码 8 位 A-Z2-9（排除 0/O/1/I）供口令传达。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 企业邀请 QR payload 前缀（扫码端同款常量，见 org_join_scanner_page）。
const String kOrgJoinQrPrefix = 'imboy://org/join?c=';

class OrgInviteQrPage extends StatefulWidget {
  const OrgInviteQrPage({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  final EntityId orgId;
  final String orgName;

  @override
  State<OrgInviteQrPage> createState() => _OrgInviteQrPageState();
}

class _OrgInviteQrPageState extends State<OrgInviteQrPage> {
  final OrganizationApi _api = OrganizationApi();

  bool _loading = true;
  bool _permissionDenied = false;
  String? _error;

  /// 409（组织 pending/rejected，服务端拒出码）：确定性禁用态，重试无意义。
  bool _inviteDisabled = false;
  bool _regenerating = false;
  OrganizationInviteCode _invite = const OrganizationInviteCode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
      _inviteDisabled = false;
    });
    try {
      final invite = await _api.getInviteCode(widget.orgId);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _loading = false;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      // await 之后才取 t：_load 由 initState 直调，initState 完成前
      // dependOnInherited 会被框架拒绝（widget 测试实证）。
      final t = context.t;
      setState(() {
        _loading = false;
        _permissionDenied = e.isForbidden;
        // 深链直达本页时的 409：入口按钮已按组织状态禁用，这里兜底——
        // 用本地化禁用文案替代后端透传 msg，且不引导无意义重试。
        _inviteDisabled = e.isConflict;
        _error = e.isConflict
            ? t.organization.inviteQr.inviteDisabledPending
            : e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 生成 / 重新生成（重新生成 = 旧码立即失效，需用户确认）。
  Future<void> _generate({required bool confirmFirst}) async {
    final t = context.t;
    if (_regenerating) return;
    if (confirmFirst) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.organization.inviteQr.regenerateTitle),
          content: Text(t.organization.inviteQr.regenerateBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.common.buttonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.organization.inviteQr.regenerateTitle),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _regenerating = true;
    });
    try {
      final invite = await _api.createInviteCode(widget.orgId);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _regenerating = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _regenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.organization.inviteQr.generateFailed)),
      );
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _invite.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.organization.inviteQr.copied)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.organization.inviteQr.title)),
      body: OrgStateView(
        loading: _loading,
        error: _permissionDenied ? null : _error,
        permissionDenied: _permissionDenied,
        empty: false,
        emptyText: '',
        onRetry: _load,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final t = context.t;
    // permissionDenied 视图由 OrgStateView 统一渲染（403 不引导盲目重试），
    // 这里只处理「可加载但失败 / 无码 / 有码」三态。
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle),
            AppSpacing.verticalSmall,
            Text(
              _inviteDisabled ? _error! : t.organization.inviteQr.loadFailed,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalSmall,
            // 禁用态（409）不提供重试：审核通过前重试必然仍是 409。
            if (!_inviteDisabled)
              TextButton(onPressed: _load, child: Text(t.common.buttonRetry)),
          ],
        ),
      );
    }
    if (_invite.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.qrcode, size: 56),
            AppSpacing.verticalMedium,
            Text(
              t.organization.inviteQr.generateFirst,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalMedium,
            FilledButton.icon(
              key: const ValueKey('org-invite-generate'),
              onPressed: _regenerating
                  ? null
                  : () => _generate(confirmFirst: false),
              icon: const Icon(CupertinoIcons.qrcode_viewfinder),
              label: Text(t.organization.inviteQr.generate),
            ),
          ],
        ),
      );
    }
    final expiresLine = _invite.expiresAt > 0
        ? t.organization.inviteQr.expiresWith(
            date: _formatExpires(_invite.expiresAt),
          )
        : '';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.large),
      children: [
        Text(
          widget.orgName,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        AppSpacing.verticalMedium,
        Center(
          child: Container(
            key: const ValueKey('org-invite-qr'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground, // QR 需白底黑码才能被扫出
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: '$kOrgJoinQrPrefix${_invite.code}',
              version: QrVersions.auto,
              size: 220,
            ),
          ),
        ),
        AppSpacing.verticalMedium,
        Text(
          t.organization.inviteQr.scanHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        AppSpacing.verticalLarge,
        // 明码口令：无法当面扫码时以文字传达（8 位 A-Z2-9，手抄友好）。
        Center(
          child: Column(
            children: [
              Text(
                t.organization.inviteQr.codeLabel,
                style: theme.textTheme.bodySmall,
              ),
              AppSpacing.verticalSmall,
              GestureDetector(
                key: const ValueKey('org-invite-code-copy'),
                onLongPress: _copyCode,
                onTap: _copyCode,
                child: Text(
                  _invite.code,
                  key: const ValueKey('org-invite-code-text'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (expiresLine.isNotEmpty) ...[
                AppSpacing.verticalSmall,
                Text(expiresLine, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        AppSpacing.verticalLarge,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('org-invite-copy'),
              onPressed: _copyCode,
              icon: const Icon(CupertinoIcons.doc_on_doc),
              label: Text(t.organization.inviteQr.copyCode),
            ),
            AppSpacing.horizontalMedium,
            TextButton.icon(
              key: const ValueKey('org-invite-regenerate'),
              onPressed: _regenerating
                  ? null
                  : () => _generate(confirmFirst: true),
              icon: const Icon(CupertinoIcons.arrow_clockwise),
              label: Text(t.organization.inviteQr.regenerate),
            ),
          ],
        ),
      ],
    );
  }

  String _formatExpires(int epochSeconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
