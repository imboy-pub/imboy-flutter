/// 企业邀请同事页（APP-M02）：
///
/// 两个 Tab——「邀请同事」（微信邀请 / 面对面邀请 / 从微信群中添加）与
/// 「可能的同事」（已邀请、等待加入的待决邀请列表）。分段控件嵌入导航栏
/// 中央（对齐企业微信参考稿；[IosPageTemplate.middle]），右上角「···」
/// 挂复制邀请码 / 微信邀请 / 重新加载。
///
/// 数据面：
/// - 邀请码：GET/POST `/organizations/:orgId/invite_code`（读面任意
///   active 成员可读码分享；建码/轮换仅 owner/admin——普通成员无码时
///   建码 403，页面以文案引导联系管理员）；
/// - 可能的同事：GET `/organizations/:orgId/invitations?status=pending`
///   （任意 active 成员可读；行含 target 昵称/账号/头像与邀请人昵称富化
///   列，不含手机号/邮箱）；撤销 POST `.../invitations/:id/revoke`
///   （owner/admin；客户端按 org detail 的 canGovern 预先隐藏撤销入口，
///   服务端 403 仍是唯一裁决）。
///
/// 分享面：fluwx 直发微信会话（WECHAT_APP_ID 已注入且已装微信）；
/// 未配置/未安装/SDK 异常一律回落 share_plus 系统分享面板。
library;

import 'package:fluwx/fluwx.dart';
import 'package:imboy/app_core/routing/organization_invite_link.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/payment_config.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/modules/organization/presentation/org_invite_qr_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 组装微信/系统分享的邀请文案（邀请码即加入凭证）。第三段是 H5 落地页
/// 链接（imboy 后端 GET /invite/org/:code；微信聊天内 imboy:// 私有
/// scheme 不可点，https 链接是唯一「点一下」路径），落地页负责展示/复制
/// 邀请码并尝试拉起 App。
String buildInviteShareText(String orgName, String code) {
  final name = orgName.isEmpty ? 'imboy' : orgName;
  return t.organization.inviteColleagues.shareText(
    orgName: name,
    code: code,
    inviteUrl: organizationInviteUrl(code),
  );
}

/// 分享邀请文案：fluwx 直发微信会话优先，未配置/未安装/异常回落系统面板。
Future<void> shareInviteText(String orgName, String code) async {
  final text = buildInviteShareText(orgName, code);
  final fluwx = Fluwx();
  try {
    if (PaymentConfig.isWechatConfigured) {
      final registered = await fluwx.registerApi(
        appId: PaymentConfig.wechatAppId,
        universalLink: PaymentConfig.wechatUniversalLink.isEmpty
            ? null
            : PaymentConfig.wechatUniversalLink,
      );
      final installed = registered && await fluwx.isWeChatInstalled;
      if (installed) {
        await fluwx.share(
          WeChatShareTextModel(text, scene: WeChatScene.session),
        );
        return;
      }
    }
  } on Object {
    // SDK 未注册 / 平台不支持 / 微信查询失败：回落系统分享面板。
  }
  await SharePlus.instance.share(ShareParams(text: text));
}

/// 成员头像：有图走通用 [Avatar]；无图用首字回退（灰底 + 昵称首字，
/// 不是问号/空白——空灰块看起来像加载失败）。
Widget inviteMemberAvatar(String imgUri, String displayName) {
  if (imgUri.isNotEmpty) {
    return Avatar(imgUri: imgUri, width: 44, height: 44);
  }
  return Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      color: AppColors.primaryAlpha10,
    ),
    child: AvatarFallbackContent(
      name: displayName,
      color: AppColors.primary,
      iconSize: 22,
    ),
  );
}

/// 企业邀请同事页（通讯录右上角 / 列表底部「+ 邀请同事」入口）。
class OrgInviteColleaguesPage extends StatefulWidget {
  const OrgInviteColleaguesPage({
    super.key,
    required this.orgId,
    this.orgName = '',
    this.api,
  });

  final EntityId orgId;
  final String orgName;

  /// 测试注入（缺省真实 [OrganizationApi]，复用既有 Token/HttpClient）。
  final OrganizationApi? api;

  @override
  State<OrgInviteColleaguesPage> createState() =>
      _OrgInviteColleaguesPageState();
}

class _OrgInviteColleaguesPageState extends State<OrgInviteColleaguesPage> {
  late final OrganizationApi _api = widget.api ?? OrganizationApi();

  /// 0 = 邀请同事；1 = 可能的同事。
  int _tab = 0;

  // ---- 邀请码 ----
  bool _codeLoading = true;

  /// 首次读取的在飞 Future：邀请动作在码未就绪时先等它落地，
  /// 避免加载中误触发「建码」（普通成员必 403）。
  Future<void> _codeLoad = Future.value();
  OrganizationInviteCode _invite = const OrganizationInviteCode();
  bool _codeForbidden = false;
  String? _codeError;
  bool _generating = false;

  // ---- 分享防抖（fluwx/分享面板无完成回调，双击会叠两层面板） ----
  bool _inviting = false;

  // ---- 撤销入口预隐藏（org detail canGovern；服务端 403 仍唯一裁决） ----
  bool _canGovern = false;

  // ---- 可能的同事（显式状态机；错误一律友好化，不外泄原始异常） ----
  bool _possibleLoading = true;
  String? _possibleError;
  List<OrgInvitation> _possible = const [];

  @override
  void initState() {
    super.initState();
    _codeLoad = _loadInviteCode();
    _loadOrg();
    _reloadPossible();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  // ==================== 邀请码 ====================

  Future<void> _loadInviteCode() async {
    if (!mounted) return;
    setState(() {
      _codeLoading = true;
      _codeError = null;
      _codeForbidden = false;
    });
    try {
      final invite = await _api.getInviteCode(widget.orgId);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _codeLoading = false;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _codeLoading = false;
        _codeForbidden = e.isForbidden;
        _codeError = e.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _codeLoading = false;
        _codeError = context.t.organization.inviteColleagues.codeLoadFailed;
      });
    }
  }

  /// org detail 只取 canGovern（预先隐藏撤销入口）；失败保持 false——
  /// 宁可少显示一个入口，也不显示点了必 403 的按钮。
  Future<void> _loadOrg() async {
    try {
      final org = await _api.detail(widget.orgId);
      if (!mounted) return;
      setState(() => _canGovern = org.canGovern);
    } on Object {
      // best-effort：入口预隐藏失败不阻塞页面。
    }
  }

  /// 生成/重新生成邀请码（重新生成 = 旧码立即失效，需用户确认）。
  Future<void> _generateInviteCode() async {
    final t = context.t;
    if (_generating) return;
    if (_invite.code.isNotEmpty) {
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
    setState(() => _generating = true);
    try {
      final invite = await _api.createInviteCode(widget.orgId);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _generating = false;
        _codeError = null;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _toast(
        e.isForbidden
            ? t.organization.inviteColleagues.generateForbidden
            : e.message,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _generating = false);
      _toast(t.organization.inviteQr.generateFailed);
    }
  }

  /// 邀请动作前确保有可用码；无码时尝试建码（owner/admin）。
  /// 返回 null = 无法取得可用码（已 toast 引导）。
  Future<OrganizationInviteCode?> _ensureInviteCode() async {
    if (_codeLoading) await _codeLoad;
    if (_invite.code.isNotEmpty) return _invite;
    await _generateInviteCode();
    return _invite.code.isEmpty ? null : _invite;
  }

  Future<void> _inviteByWechat() async {
    if (_inviting) return;
    final t = context.t;
    setState(() => _inviting = true);
    try {
      final invite = await _ensureInviteCode();
      if (invite == null) {
        _toast(t.organization.inviteColleagues.codeMissingHint);
        return;
      }
      await shareInviteText(widget.orgName, invite.code);
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  void _openFaceToFace() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            OrgInviteQrPage(orgId: widget.orgId, orgName: widget.orgName),
      ),
    );
  }

  void _openFromGroupGuide() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => OrgInviteFromGroupGuidePage(
          orgId: widget.orgId,
          orgName: widget.orgName,
          api: widget.api,
        ),
      ),
    );
  }

  /// 右上角「···」：复制邀请码 / 微信邀请 / 重新加载。
  Future<void> _openMoreSheet() async {
    final t = context.t;
    final hasCode = _invite.code.isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('org-invite-sheet-copy'),
              leading: const Icon(CupertinoIcons.doc_on_doc),
              title: Text(t.organization.inviteColleagues.copyInviteCode),
              enabled: hasCode,
              onTap: hasCode
                  ? () {
                      Navigator.of(sheetCtx).pop();
                      Clipboard.setData(ClipboardData(text: _invite.code));
                      _toast(t.organization.inviteQr.copied);
                    }
                  : null,
            ),
            ListTile(
              key: const ValueKey('org-invite-sheet-wechat'),
              leading: const Icon(CupertinoIcons.chat_bubble_fill),
              title: Text(t.organization.inviteColleagues.wechatInvite),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _inviteByWechat();
              },
            ),
            ListTile(
              key: const ValueKey('org-invite-sheet-reload'),
              leading: const Icon(CupertinoIcons.refresh),
              title: Text(t.organization.common.reload),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _loadInviteCode();
                _reloadPossible();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 可能的同事 ====================

  Future<void> _reloadPossible() async {
    if (!mounted) return;
    setState(() {
      _possibleLoading = true;
      _possibleError = null;
    });
    try {
      final list = await _api.orgInvitations(
        widget.orgId,
        status: 'pending',
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _possible = list;
        _possibleLoading = false;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _possibleError = e.message;
        _possibleLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _possibleError =
            context.t.organization.inviteColleagues.possibleLoadFailed;
        _possibleLoading = false;
      });
    }
  }

  Future<void> _revoke(OrgInvitation inv) async {
    final t = context.t;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.organization.inviteColleagues.revokeTitle),
        content: Text(
          t.organization.inviteColleagues.revokeBody(
            name: inv.targetDisplayName,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.organization.inviteColleagues.revoke),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.revokeInvitation(widget.orgId, inv.invitationId);
      if (!mounted) return;
      _toast(t.organization.inviteColleagues.revoked);
      await _reloadPossible();
    } on OrganizationApiException catch (e) {
      _toast(e.message);
    } on Object {
      _toast(t.organization.inviteColleagues.revokeFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IosPageTemplate(
      title: context.t.organization.inviteColleagues.title,
      // 分段控件嵌导航栏中央（企业微信参考稿样式）。
      middle: _middleSegmented(context),
      actions: [_moreButton(context)],
      body: _tab == 0 ? _buildInviteTab(context) : _buildPossibleTab(context),
    );
  }

  // ==================== 导航栏 ====================

  Widget _middleSegmented(BuildContext context) {
    final t = context.t;
    return CupertinoSlidingSegmentedControl<int>(
      key: const ValueKey('org-invite-colleagues-tabs'),
      groupValue: _tab,
      onValueChanged: (v) => setState(() => _tab = v ?? 0),
      children: {
        0: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.tiny,
          ),
          child: Text(t.organization.inviteColleagues.tabInvite),
        ),
        1: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.tiny,
          ),
          child: Text(t.organization.inviteColleagues.tabPossible),
        ),
      },
    );
  }

  Widget _moreButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoButton(
      key: const ValueKey('org-invite-more'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: _openMoreSheet,
      child: Semantics(
        label: context.t.organization.common.moreActions,
        button: true,
        child: Icon(
          CupertinoIcons.ellipsis,
          size: 20,
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  // ==================== Tab 1：邀请同事 ====================

  Widget _buildInviteTab(BuildContext context) {
    final t = context.t;
    final hasCode = _invite.code.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _loadInviteCode,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        children: [
          if (_codeForbidden)
            _banner(
              context,
              text:
                  _codeError ?? t.organization.inviteColleagues.codeMissingHint,
            )
          else if (_codeError != null)
            _banner(
              context,
              text: _codeError!,
              actionLabel: t.common.buttonRetry,
              onAction: _loadInviteCode,
            )
          else if (hasCode || _codeLoading)
            const SizedBox.shrink()
          else
            _banner(
              context,
              text: t.organization.inviteColleagues.codeMissingHint,
              actionLabel: _generating
                  ? null
                  : t.organization.inviteColleagues.generateCode,
              busy: _generating,
              onAction: _generateInviteCode,
            ),
          _card(context, [
            _menuRow(
              context,
              key: const ValueKey('org-invite-wechat'),
              icon: CupertinoIcons.chat_bubble_fill,
              title: t.organization.inviteColleagues.wechatInvite,
              subtitle: t.organization.inviteColleagues.wechatInviteHint,
              onTap: _inviteByWechat,
            ),
            _rowDivider(context),
            _menuRow(
              context,
              key: const ValueKey('org-invite-face-to-face'),
              icon: CupertinoIcons.qrcode,
              title: t.organization.inviteColleagues.faceToFace,
              subtitle: t.organization.inviteColleagues.faceToFaceHint,
              onTap: _openFaceToFace,
            ),
          ]),
          const SizedBox(height: AppSpacing.small),
          _card(context, [
            _menuRow(
              context,
              key: const ValueKey('org-invite-from-group'),
              icon: CupertinoIcons.person_2_fill,
              title: t.organization.inviteColleagues.fromWechatGroup,
              subtitle: t.organization.inviteColleagues.fromWechatGroupHint,
              onTap: _openFromGroupGuide,
            ),
          ]),
          if (hasCode) ...[
            const SizedBox(height: AppSpacing.small),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
              ),
              child: Text(
                t.organization.inviteColleagues.codeValidityHint,
                textAlign: TextAlign.center,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.iosGray,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 状态引导条：默认品牌色浅底；actionLabel 为空只展示文案（409/禁用）。
  Widget _banner(
    BuildContext context, {
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
    bool busy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.tiny,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryAlpha10,
          borderRadius: BorderRadius.circular(AppRadius.cell),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (actionLabel != null || busy) ...[
              const SizedBox(width: AppSpacing.small),
              busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : CupertinoButton(
                      key: const ValueKey('org-invite-banner-action'),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: onAction,
                      child: Text(
                        actionLabel!,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== Tab 2：可能的同事 ====================

  Widget _buildPossibleTab(BuildContext context) {
    if (_possibleError != null) {
      return OrgStateView(
        loading: false,
        error: _possibleError,
        empty: false,
        onRetry: _reloadPossible,
      );
    }
    return RefreshIndicator(
      onRefresh: _reloadPossible,
      child: _possibleBody(context),
    );
  }

  Widget _possibleBody(BuildContext context) {
    final t = context.t;
    if (_possibleLoading && _possible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_possible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.person_2,
                  size: 44,
                  color: AppColors.iosGray,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  t.organization.inviteColleagues.possibleEmpty,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.iosGray,
                  ),
                ),
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  t.organization.inviteColleagues.possibleEmptyHint,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.iosGray,
                  ),
                ),
                const SizedBox(height: AppSpacing.regular),
                FilledButton(
                  key: const ValueKey('org-invite-possible-cta'),
                  onPressed: () => setState(() => _tab = 0),
                  child: Text(t.organization.inviteColleagues.possibleEmptyCta),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      itemCount: _possible.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.tiny),
      itemBuilder: (context, i) => _possibleRow(context, _possible[i]),
    );
  }

  Widget _possibleRow(BuildContext context, OrgInvitation inv) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invitedAt = int.tryParse(inv.createdAt) ?? 0;
    final timeText = invitedAt > 0
        ? DateTimeHelper.dateTimeFmt(
            DateTime.fromMillisecondsSinceEpoch(invitedAt * 1000),
          )
        : '';
    final subtitle = [
      if (inv.inviterName.isNotEmpty)
        t.organization.inviteColleagues.invitedBy(name: inv.inviterName),
      if (timeText.isNotEmpty)
        t.organization.inviteColleagues.invitedAt(time: timeText),
    ].join(' · ');
    return Container(
      key: ValueKey('org-invite-possible-${inv.invitationId}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.regular),
      ),
      child: Row(
        children: [
          inviteMemberAvatar(inv.targetAvatar, inv.targetDisplayName),
          const SizedBox(width: AppSpacing.regular),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.targetDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: AppColors.iosGray,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 撤销仅对治理角色预先显示（客户端减法；服务端 403 仍唯一裁决）。
          if (_canGovern)
            TextButton(
              key: ValueKey('org-invite-revoke-${inv.invitationId}'),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.iosRedDark
                    : AppColors.iosRed,
              ),
              onPressed: () => _revoke(inv),
              child: Text(t.organization.inviteColleagues.revoke),
            ),
        ],
      ),
    );
  }

  // ==================== 通用部件 ====================

  Widget _card(BuildContext context, List<Widget> rows) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.regular),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Widget _menuRow(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ImBoyListTile(
      key: key,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.cell),
          color: AppColors.primary,
        ),
        child: Icon(icon, size: 20, color: AppColors.onPrimary),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.footnote,
          color: AppColors.iosGray,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: isDark ? AppColors.iosGray3Dark : AppColors.iosGray3,
      ),
    );
  }

  Widget _rowDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 0.5,
        color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.4),
      ),
    );
  }
}

/// 「从微信群中添加」引导页：第三方应用无法读取微信群成员（微信开放
/// 平台边界），收敛为「把邀请码分享到微信群」的引导流——步骤说明 +
/// 一键分享（与微信邀请同一分享链路）。
class OrgInviteFromGroupGuidePage extends StatefulWidget {
  const OrgInviteFromGroupGuidePage({
    super.key,
    required this.orgId,
    this.orgName = '',
    this.api,
  });

  final EntityId orgId;
  final String orgName;

  /// 测试注入（缺省真实 [OrganizationApi]）。
  final OrganizationApi? api;

  @override
  State<OrgInviteFromGroupGuidePage> createState() =>
      _OrgInviteFromGroupGuidePageState();
}

class _OrgInviteFromGroupGuidePageState
    extends State<OrgInviteFromGroupGuidePage> {
  late final OrganizationApi _api = widget.api ?? OrganizationApi();

  bool _loading = true;
  String? _error;
  String _code = '';
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await _api.getInviteCode(widget.orgId);
      if (!mounted) return;
      setState(() {
        _code = invite.code;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.t.organization.inviteColleagues.codeLoadFailed;
      });
    }
  }

  Future<void> _share() async {
    if (_sharing || _code.isEmpty) return;
    setState(() => _sharing = true);
    try {
      await shareInviteText(widget.orgName, _code);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final steps = [
      t.organization.inviteColleagues.groupStep1,
      t.organization.inviteColleagues.groupStep2,
      t.organization.inviteColleagues.groupStep3,
    ];
    return IosPageTemplate(
      title: t.organization.inviteColleagues.fromWechatGroup,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: context.textStyle(FontSizeType.normal),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.regular),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
            AppSpacing.verticalSmall,
            Center(
              child: TextButton(
                onPressed: _load,
                child: Text(t.common.buttonRetry),
              ),
            ),
          ] else if (_code.isEmpty) ...[
            Text(
              t.organization.inviteColleagues.guideCodeMissing,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
          ] else ...[
            Center(
              child: Container(
                key: const ValueKey('org-invite-group-code'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular,
                  vertical: AppSpacing.small,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha10,
                  borderRadius: BorderRadius.circular(AppRadius.cell),
                ),
                child: Text(
                  t.organization.inviteColleagues.codeLabelWith(code: _code),
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.regular),
          FilledButton.icon(
            key: const ValueKey('org-invite-group-share'),
            onPressed: _loading || _sharing || _code.isEmpty ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.chat_bubble_fill),
            label: Text(t.organization.inviteColleagues.shareToWechat),
          ),
        ],
      ),
    );
  }
}
