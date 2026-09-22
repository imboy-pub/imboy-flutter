/// 企业选择器（GZAPP-04 G9，计划 §5.1）——「切换工作区」升级为
/// 「切换企业」，数据源必须是当前用户的 Organization membership
/// （GET /organizations/mine），禁止只换文案继续读 Workspace 列表。
///
/// 结构：
/// - 我的企业列表（mine() 真源；本地缓存只作转场即时渲染）
/// - 底部常驻『加入企业』入口（GZAPP-J11 收敛：单码输入 / 扫码 →
///   preview「确认加入 XX 企业」→ code-only join
///   POST /organizations/invite_code/join——码全局唯一即凭据，
///   用户不再手输 19 位企业 ID；旧双输入端点保留但不再是主路径）
/// - 切换动作携带 G11 缓存失效清单（不得残留上一企业缓存）：
///   ① OrganizationCache.invalidateOrg(上一企业) ② CurrentOrganizationStore
///   指针切换 ③ workspaceShellProvider.loadMine() 重建 WS 列表并按该企业
///   default-workspace 指针落位（页面数据族 provider 以 wsId family 参数
///   自动随 selectWorkspace 重建，无跨企业残留）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/modules/organization/presentation/org_join_scanner_page.dart';

class OrganizationPickerPage extends ConsumerStatefulWidget {
  const OrganizationPickerPage({
    super.key,
    this.accountKey,
    this.autoJoin = false,
  });

  /// 缓存/指针账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

  /// 进入即自动打开「加入企业」邀请码对话框（计划 §5.1：正常入口点「加入企业」
  /// 应当一步到达加入动作，而不是先落到选择器再让用户找第二次）。
  final bool autoJoin;

  @override
  ConsumerState<OrganizationPickerPage> createState() =>
      _OrganizationPickerPageState();
}

class _OrganizationPickerPageState
    extends ConsumerState<OrganizationPickerPage> {
  final OrganizationApi _api = OrganizationApi();

  List<Organization> _orgs = const [];
  bool _loading = false;
  String? _error;

  String get _accountKey => widget.accountKey ?? UserRepoLocal.to.currentUid;

  OrganizationCache get _cache => OrganizationCache.forAccount(_accountKey);

  CurrentOrganizationStore get _currentStore =>
      CurrentOrganizationStore.forAccount(_accountKey);

  Organization? get _currentOrg {
    final pointed = _currentStore.value;
    if (pointed == null) return null;
    // 指针非真源：不在 mine 列表（被移出/归档清理）→ 视为无当前企业。
    for (final o in _orgs) {
      if (o.id == pointed.id) return o;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.autoJoin) {
      // 等首帧后再弹：对话框依赖已挂载的 Navigator/Overlay。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _joinByCode();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.mine();
      _cache.saveOrgs(page.list);
      if (!mounted) return;
      setState(() {
        _orgs = page.list;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.message} (code=${e.code})';
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

  /// 切换企业（G11：缓存失效清单集中在切换动作内，见文件头注释）。
  Future<void> _switchTo(Organization org) async {
    final prev = _currentOrg;
    if (prev?.id == org.id) {
      _leave();
      return;
    }
    // ① 上一企业展示缓存失效（orgs/members/departments 一并丢弃）。
    if (prev != null) {
      _cache.invalidateOrg(prev.id);
    }
    // ①b 工作区维度视图族显式失效（计划 §5.1「不得残留上一企业缓存」）：
    //     这五个是 autoDispose.family(key=wsId)，换企业后 key 虽会变，
    //     但「靠 key 变化 + autoDispose 兜底」不是显式失效——若上一企业的
    //     某页仍被监听（切换前刚打开过），其缓存会活到该页被销毁为止。
    //     在切换动作里整体 invalidate family，等于清掉所有 wsId 的实例。
    ref.invalidate(workspaceOverviewProvider);
    ref.invalidate(workspaceChannelsProvider);
    ref.invalidate(workspaceGroupsProvider);
    ref.invalidate(workspaceMembersProvider);
    ref.invalidate(workspaceProjectsProvider);
    // ② 当前企业指针切换（持久化，供 chip / WS picker 顶部企业行）。
    _currentStore.set(org);
    // ③ WS 壳按新企业重建：默认/上次 Workspace 落位（defaultWorkspace
    //    是指向事实；缺失或不在已加入列表时维持 loadMine 的自动选择）。
    //    keepListOnFailure:false —— 企业指针已切走，若此处失败必须清空列表，
    //    否则出现「指针新企业 + 列表旧企业」的残留窗口（§5.1）。
    await ref
        .read(workspaceShellProvider.notifier)
        .loadMine(keepListOnFailure: false);
    await _landDefaultWorkspace(org);
    if (!mounted) return;
    _leave();
  }

  /// 离开本页：正常从切换 chip/企业行 push 进入 → pop 返回；被 go 挂为
  /// 根页（无栈可弹）时回壳挂载点，避免 pop 空栈断言。
  void _leave() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/bottom_navigation');
    }
  }

  Future<void> _landDefaultWorkspace(Organization org) async {
    try {
      final dw = await _api.defaultWorkspace(org.id);
      if (!dw.isSet) return;
      final shell = ref.read(workspaceShellProvider);
      final joined = shell.workspaces.any(
        (ws) => ws.id == dw.defaultWorkspaceId,
      );
      if (joined) {
        ref
            .read(workspaceShellProvider.notifier)
            .selectWorkspace(dw.defaultWorkspaceId);
      }
    } on Object {
      // 默认 WS 指针读取失败不阻塞切换（loadMine 已完成壳重建）。
    }
  }

  Future<void> _joinByCode() async {
    final result = await showDialog<OrgJoinDialogResult>(
      context: context,
      builder: (ctx) => const _OrgJoinCodeDialog(),
    );
    if (result == null || !mounted) return;
    // preview 已持有目标企业事实（id+name）：先播种转场即时渲染，
    // 再刷新取 mine() 真源并切入（无 organization 投影依赖）。
    _cache.saveOrgs([
      Organization(id: result.organizationId, name: result.name),
    ]);
    await _refresh();
    if (!mounted) return;
    final fresh = _orgsWhere(result.organizationId);
    if (fresh != null) {
      await _switchTo(fresh);
    }
  }

  Organization? _orgsWhere(EntityId orgId) {
    for (final o in _orgs) {
      if (o.id == orgId) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentOrg;
    return Scaffold(
      appBar: AppBar(title: Text(t.organization.picker.title)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && _orgs.isEmpty,
          error: _error,
          empty: !_loading && _error == null && _orgs.isEmpty,
          emptyText: t.organization.picker.emptyHint,
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              for (final o in _orgs)
                ListTile(
                  key: ValueKey('org-picker-tile-${o.id}'),
                  leading: Icon(
                    CupertinoIcons.building_2_fill,
                    color: o.isArchived
                        ? Theme.of(context).disabledColor
                        : null,
                  ),
                  title: Text(
                    o.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${orgRoleLabel(o.memberRole.isEmpty ? 'member' : o.memberRole)}'
                    '${o.isArchived ? ' · ${orgStatusLabel(o.status)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: o.id == current?.id
                      ? Icon(
                          CupertinoIcons.check_mark,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => _switchTo(o),
                ),
              // 底部常驻『加入企业』入口（Slack「Add workspaces」同构）。
              ListTile(
                key: const ValueKey('org-picker-join-entry'),
                leading: const Icon(
                  CupertinoIcons.person_crop_circle_badge_plus,
                ),
                title: Text(t.organization.picker.joinEnterprise),
                onTap: _joinByCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 加入企业对话框出站结果：preview 阶段拿到的目标企业事实
/// （join 成功后页面据此播种缓存并切换，不依赖 join 响应的投影）。
class OrgJoinDialogResult {
  final EntityId organizationId;
  final String name;

  const OrgJoinDialogResult({required this.organizationId, required this.name});
}

/// 企业邀请码对话框（GZAPP-J11 收敛版）：**单码输入 / 扫码** →
/// preview「确认加入 XX 企业」→ code-only join。用户不再输入企业 ID。
/// 错误态（981/982/透传）页内展示；扫码扫到非邀请码留在扫码页继续扫。
class _OrgJoinCodeDialog extends StatefulWidget {
  const _OrgJoinCodeDialog();

  @override
  State<_OrgJoinCodeDialog> createState() => _OrgJoinCodeDialogState();
}

enum _OrgJoinStage { input, confirm }

class _OrgJoinCodeDialogState extends State<_OrgJoinCodeDialog> {
  final OrganizationApi _api = OrganizationApi();
  final TextEditingController _codeCtrl = TextEditingController();
  _OrgJoinStage _stage = _OrgJoinStage.input;
  bool _submitting = false;
  String? _error;
  OrgInvitePreview? _preview;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// 扫码 → 拿到邀请码后自动 preview（用户无需再点一次提交）。
  Future<void> _scanAndPreview() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const OrgJoinScannerPage()),
    );
    if (code == null || !mounted || code.isEmpty) return;
    _codeCtrl.text = code;
    await _previewByCode(code);
  }

  /// input 态提交：凭码预览目标企业（981/982 在此暴露，不进 confirm）。
  Future<void> _previewByCode(String rawCode) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final preview = await _api.previewByCode(rawCode.trim().toUpperCase());
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _preview = preview;
        _stage = _OrgJoinStage.confirm;
      });
    } on OrganizationApiException catch (e) {
      _showJoinError(e);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  /// confirm 态提交：code-only join（免 orgId），成功回传目标企业事实。
  Future<void> _join() async {
    final preview = _preview;
    if (preview == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.joinByCodeOnly(_codeCtrl.text.trim().toUpperCase());
      if (!mounted) return;
      Navigator.of(context).pop(
        OrgJoinDialogResult(
          organizationId: preview.organizationId,
          name: preview.name,
        ),
      );
    } on OrganizationApiException catch (e) {
      _showJoinError(e);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  void _showJoinError(OrganizationApiException e) {
    if (!mounted) return;
    final t = context.t;
    setState(() {
      _submitting = false;
      // join 阶段的 981/982（码在 preview 后被撤销/过期）：回输入态。
      _stage = _OrgJoinStage.input;
      _preview = null;
      _error = e.isInviteInvalid
          ? t.organization.picker.joinInvalidCode
          : e.isInviteExpired
          ? t.organization.picker.joinExpiredCode
          : t.organization.picker.joinFailedWith(msg: e.message, code: e.code);
    });
  }

  Future<void> _submit() async {
    if (_stage == _OrgJoinStage.input) {
      await _previewByCode(_codeCtrl.text);
      return;
    }
    await _join();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final isConfirm = _stage == _OrgJoinStage.confirm;
    return AlertDialog(
      title: Text(
        isConfirm
            ? t.organization.picker.joinConfirmTitle
            : t.organization.picker.joinEnterprise,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isConfirm) ...[
            OutlinedButton.icon(
              key: const ValueKey('org-join-scan-entry'),
              onPressed: _submitting ? null : _scanAndPreview,
              icon: const Icon(CupertinoIcons.qrcode_viewfinder),
              label: Text(t.organization.picker.joinScanQr),
            ),
            AppSpacing.verticalMedium,
            TextField(
              key: const ValueKey('org-join-code-field'),
              controller: _codeCtrl,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: t.organization.picker.joinCodeLabel,
                hintText: t.organization.picker.joinCodeOnlyHint,
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
          ] else ...[
            Text(
              key: const ValueKey('org-join-org-name'),
              t.organization.picker.joinConfirmWith(name: _preview?.name ?? ''),
              style: theme.textTheme.titleMedium,
            ),
            AppSpacing.verticalMedium,
            TextButton(
              key: const ValueKey('org-join-back'),
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                      _stage = _OrgJoinStage.input;
                      _preview = null;
                    }),
              child: Text(t.organization.picker.joinBack),
            ),
          ],
          if (_error != null)
            Text(
              _error!,
              key: const ValueKey('org-join-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.buttonCancel),
        ),
        FilledButton(
          key: const ValueKey('org-join-submit'),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isConfirm
                      ? t.organization.picker.joinConfirmSubmit
                      : t.organization.picker.joinSubmit,
                ),
        ),
      ],
    );
  }
}
