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
/// - 切换为**两阶段原子切换**（ENT-APP-04，镜像 HumanDirectoryBrowserPage
///   的 prepare/commit 语义）：
///   Phase 1 预载——detail() 校验当前账号仍可访问目标企业（被移出/归档
///   清理 → 403/404 在此暴露）+ loadMine 预载新壳；任一步失败时未触碰
///   任何本地状态（指针/缓存/壳原样），只置错误态可重试；
///   Phase 2 提交——G11 缓存失效清单（① OrganizationCache.invalidateOrg
///   上一企业 ② 五个 wsId family provider 显式失效 ③ CurrentOrganizationStore
///   指针切换，store 先持久化后内存）；失败尝试恢复旧指针。补偿保存失败
///   则按实际保存指针对齐壳，显示重试错误。成功后落位目标企业工作区。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/modules/organization/presentation/org_join_scanner_page.dart';

import 'space_picker_views.dart';

class OrganizationPickerPage extends ConsumerStatefulWidget {
  const OrganizationPickerPage({
    super.key,
    this.accountKey,
    this.autoJoin = false,
    this.joinCode,
  });

  /// 缓存/指针账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

  /// 进入即自动打开「加入企业」邀请码对话框（计划 §5.1：正常入口点「加入企业」
  /// 应当一步到达加入动作，而不是先落到选择器再让用户找第二次）。
  final bool autoJoin;

  /// 预填的邀请码（通用扫一扫识别 `imboy://org/join?c=CODE` 后带入）：
  /// autoJoin 打开的对话框跳过输入/扫码，直接 preview 进「确认加入」态。
  final String? joinCode;

  @override
  ConsumerState<OrganizationPickerPage> createState() =>
      _OrganizationPickerPageState();
}

class _OrganizationPickerPageState
    extends ConsumerState<OrganizationPickerPage> {
  final OrganizationApi _api = OrganizationApi();

  List<Organization> _orgs = const [];
  bool _loading = false;
  int _refreshGeneration = 0;
  final int _sessionGeneration = UserRepoLocal.to.sessionGeneration;

  bool get _sessionCurrent =>
      !UserRepoLocal.to.isClearingSession &&
      UserRepoLocal.to.isCurrentSession(_sessionGeneration);
  int _accountEpoch = 0;
  String? _error;

  /// 两阶段切换状态（ENT-APP-04）：进行中门（重复点击不重入）+ 页内
  /// 错误态（不弹走、列表保留，可再点目标行重试）。
  bool _switching = false;
  String? _switchError;

  /// 正在切换的目标（[_kPersonalTarget] 或企业 id）：行内 spinner 与
  /// 「真实正在切换的项」的唯一真源；null=无进行中切换。
  Object? _switchingTarget;

  /// 个人模式切换目标哨兵（企业 id 均为 TSID 字符串，不与哨兵冲突）。
  static const Object _kPersonalTarget = '__personal__';

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
        if (mounted && _sessionCurrent && _accountKey.isNotEmpty) {
          _joinByCode(widget.joinCode);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant OrganizationPickerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountKey == widget.accountKey) return;
    ++_accountEpoch;
    _orgs = const [];
    _switchError = null;
    _refresh();
  }

  bool _acceptRefresh(String account, int generation) =>
      mounted &&
      _sessionCurrent &&
      account == _accountKey &&
      generation == _refreshGeneration;

  Future<void> _refresh() async {
    if (!_sessionCurrent || _accountKey.isEmpty) return;
    final account = _accountKey;
    final generation = ++_refreshGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final organizations = await _api.allMine();
      if (!_acceptRefresh(account, generation)) return;
      _cache.replaceMineOrgs(organizations);
      setState(() {
        _orgs = organizations;
      });
    } on OrganizationApiException catch (e) {
      if (!_acceptRefresh(account, generation)) return;
      setState(() {
        _error = _apiErrorText(e);
      });
    } on Object {
      if (!_acceptRefresh(account, generation)) return;
      setState(() {
        _error = t.common.settingFailedPleaseTryAgain;
      });
    } finally {
      if (_acceptRefresh(account, generation)) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 两阶段原子切换（ENT-APP-04；语义见文件头）。任一阶段失败 → 页内
  /// 错误态 + 恢复旧状态；补偿失败按实际指针对齐，不把失败报告为成功。
  bool _acceptSwitch(String account, int epoch) =>
      mounted &&
      _sessionCurrent &&
      account == _accountKey &&
      epoch == _accountEpoch;

  Future<void> _switchTo(Organization org) async {
    if (_switching || !_sessionCurrent || _accountKey.isEmpty) return;
    final account = _accountKey;
    final epoch = _accountEpoch;
    final prev = _currentOrg;
    final previousShell = ref.read(workspaceShellProvider);
    var committing = false;
    setState(() {
      _switching = true;
      _switchError = null;
      _switchingTarget = org.id;
    });
    try {
      final fresh = await _prepareTarget(org, account, epoch);
      if (!_acceptSwitch(account, epoch)) return;
      committing = true;
      await _commitTarget(fresh, prev, account, epoch);
    } on Object catch (e) {
      if (!_acceptSwitch(account, epoch)) return;
      final recoveryError = committing
          ? await _rollbackSwitch(prev, org, previousShell, account, epoch)
          : null;
      if (!_acceptSwitch(account, epoch)) return;
      setState(() {
        _switching = false;
        _switchingTarget = null;
        _switchError = _switchErrorText(
          recoveryError ?? e,
          recovered: committing && recoveryError == null,
        );
      });
      return;
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
          _switchingTarget = null;
        });
      }
    }
    if (!_acceptSwitch(account, epoch)) return;
    setState(() {
      _switching = false;
      _switchingTarget = null;
    });
    _leave();
  }

  Future<Organization> _prepareTarget(
    Organization org,
    String account,
    int epoch,
  ) async {
    final fresh = await _api.detail(org.id);
    if (!_acceptSwitch(account, epoch)) {
      throw StateError('Organization account changed');
    }
    await ref
        .read(workspaceShellProvider.notifier)
        .loadMine(keepListOnFailure: true);
    if (!_acceptSwitch(account, epoch)) {
      throw StateError('Organization account changed');
    }
    final error = ref.read(workspaceShellProvider).error;
    if (error != null && error.isNotEmpty) throw StateError(error);
    return fresh;
  }

  Future<void> _commitTarget(
    Organization fresh,
    Organization? prev,
    String account,
    int epoch,
  ) async {
    if (!_acceptSwitch(account, epoch)) return;
    if (prev != null) _cache.invalidateOrg(prev.id);
    ref.invalidate(workspaceOverviewProvider);
    ref.invalidate(workspaceChannelsProvider);
    ref.invalidate(workspaceGroupsProvider);
    ref.invalidate(workspaceMembersProvider);
    ref.invalidate(workspaceProjectsProvider);
    await _currentStore.set(fresh);
    if (!_acceptSwitch(account, epoch)) {
      throw StateError('Organization account changed');
    }
    await _landDefaultWorkspace(fresh, account, epoch);
    if (!_acceptSwitch(account, epoch)) {
      throw StateError('Organization account changed');
    }
    await ref
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
  }

  /// Phase 2 失败补偿：指针恢复 prev（[CurrentOrganizationStore.restore]
  /// 支持 null=清空指针；与 set 同序「先持久化后内存」）；目标企业的
  /// 缓存播种一并丢弃。补偿保存失败时按实际指针对齐壳，并返回失败供重试。
  Future<Object?> _rollbackSwitch(
    Organization? prev,
    Organization failed,
    WorkspaceShellState previousShell,
    String account,
    int epoch,
  ) async {
    if (!_acceptSwitch(account, epoch)) return null;
    Object? recoveryError;
    try {
      await _currentStore.restore(prev);
    } on Object catch (e) {
      recoveryError = e;
    }
    if (!_acceptSwitch(account, epoch)) return recoveryError;
    _cache.invalidateOrg(failed.id);
    final pointed = _currentStore.value;
    final snapshot = recoveryError == null
        ? previousShell
        : ref.read(workspaceShellProvider);
    final shell = ref.read(workspaceShellProvider.notifier);
    await shell.selectOrganization(
      pointed?.id ?? '',
      () async => snapshot.organizationId == pointed?.id
          ? snapshot.currentWorkspaceId
          : '',
    );
    if (!_acceptSwitch(account, epoch)) return recoveryError;
    return recoveryError;
  }

  /// 失败原因文案（列表读取与切换共用）：403→无权限、API message 为
  /// 服务端人话文案原样展示、其余回落通用重试文案；任何分支都不得
  /// 拼接 `code=` 等原始技术值（vocabulary 红线 / T07 验收）。
  String _apiErrorText(Object e) {
    if (e is OrganizationApiException) {
      if (e.code == 403) return t.common.noPermission;
      final msg = e.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    return t.common.settingFailedPleaseTryAgain;
  }

  /// 切换失败页内文案：回滚成功=完整句「切换失败，已恢复原选择」
  /// （vocabulary 冻结文案）；否则「切换失败：<原因>」。
  String _switchErrorText(Object e, {required bool recovered}) {
    if (recovered) return t.organization.picker.switchFailedRecovered;
    return '${t.organization.picker.switchFailed}：${_apiErrorText(e)}';
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

  Future<void> _selectPersonal() async {
    if (_switching || !_sessionCurrent || _accountKey.isEmpty) return;
    final account = _accountKey;
    final epoch = _accountEpoch;
    setState(() {
      _switching = true;
      _switchingTarget = _kPersonalTarget;
    });
    try {
      await ref
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.personal);
    } on Object {
      if (_acceptSwitch(account, epoch)) {
        setState(() {
          _switchError = t.common.settingFailedPleaseTryAgain;
        });
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
          _switchingTarget = null;
        });
      }
    }
    if (_acceptSwitch(account, epoch)) _leave();
  }

  Future<void> _landDefaultWorkspace(
    Organization org,
    String account,
    int epoch,
  ) async {
    await ref.read(workspaceShellProvider.notifier).selectOrganization(
      org.id,
      () async {
        final dw = await _api.defaultWorkspace(org.id);
        if (!_acceptSwitch(account, epoch)) {
          throw StateError('Organization account changed');
        }
        return dw.defaultWorkspaceId;
      },
    );
  }

  Future<void> _joinByCode([String? initialCode]) async {
    if (!_sessionCurrent || _accountKey.isEmpty) return;
    final account = _accountKey;
    final epoch = _accountEpoch;
    final result = await showDialog<OrgJoinDialogResult>(
      context: context,
      builder: (ctx) => _OrgJoinCodeDialog(
        isCurrentAccount: () => _acceptSwitch(account, epoch),
        initialCode: initialCode,
      ),
    );
    if (result == null || !_acceptSwitch(account, epoch)) return;
    // preview 已持有目标企业事实（id+name）：先播种转场即时渲染，
    // 再刷新取 mine() 真源并切入（无 organization 投影依赖）。
    _cache.saveOrgs([
      Organization(id: result.organizationId, name: result.name),
    ]);
    await _refresh();
    if (!_acceptSwitch(account, epoch)) return;
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
    // 当前勾选唯一真源：体验模式（personal/workspace）与指针共同决定，
    // 个人模式勾「个人模式」行、企业模式勾当前企业行，二者互斥。
    final experience = ref.watch(productExperienceProvider);
    const switchingSpinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    Widget checkMark() => Icon(
      CupertinoIcons.check_mark,
      color: Theme.of(context).colorScheme.primary,
    );
    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      appBar: AppBar(title: Text(t.organization.experienceUi.switchSpace)),
      body: Column(
        children: [
          SpacePickerSection(
            children: [
              ListTile(
                key: const ValueKey('org-picker-personal-entry'),
                leading: const Icon(CupertinoIcons.person_circle),
                title: Text(t.organization.experienceUi.personalSpace),
                trailing: _switchingTarget == _kPersonalTarget
                    ? switchingSpinner
                    : experience == ProductExperience.personal
                    ? checkMark()
                    : null,
                onTap: _switching ? null : _selectPersonal,
              ),
            ],
          ),
          if (_switchError != null)
            ListTile(
              key: const ValueKey('org-picker-switch-error'),
              leading: Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                _switchError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _switching ? switchingSpinner : null,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: OrgStateView(
                loading: _loading && _orgs.isEmpty,
                error: _error,
                empty: !_loading && _error == null && _orgs.isEmpty,
                emptyText: t.organization.picker.emptyHint,
                onRetry: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.small,
                  ),
                  children: [
                    SpacePickerSection(
                      header: Text(
                        t.organization.experienceUi.enterpriseSpaces,
                      ),
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
                            subtitle: orgListSubtitle(context, o),
                            // 目标行行内 spinner=「真实正在切换的项」；勾选仅在
                            // 企业模式且为当前企业时出现（语义唯一），切换完成
                            // 前绝不提前亮勾。
                            trailing: _switching && _switchingTarget == o.id
                                ? switchingSpinner
                                : o.id == current?.id &&
                                      experience == ProductExperience.workspace
                                ? checkMark()
                                : null,
                            // 切换进行中禁点（防重复提交产生竞态切换）。
                            onTap: _switching ? null : () => _switchTo(o),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SpacePickerActions(
            onJoin: _joinByCode,
            onCreate: () => context.push(kOrganizationHomePath),
          ),
        ],
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
  const _OrgJoinCodeDialog({required this.isCurrentAccount, this.initialCode});

  final bool Function() isCurrentAccount;

  /// 外部入口（通用扫一扫 deep link）预填的邀请码：非空时挂载后
  /// 自动 preview，直接进「确认加入 XX 企业」态。
  final String? initialCode;

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

  bool get _isCurrent => mounted && widget.isCurrentAccount();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode;
    if (initial != null && initial.trim().isNotEmpty) {
      _codeCtrl.text = initial.trim().toUpperCase();
      // 首帧后自动 preview：对话框刚挂载，避免 build 期间 setState。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isCurrent) _previewByCode(initial);
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// 扫码 → 拿到邀请码后自动 preview（用户无需再点一次提交）。
  Future<void> _scanAndPreview() async {
    if (!_isCurrent) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const OrgJoinScannerPage()),
    );
    if (code == null || !_isCurrent || code.isEmpty) return;
    _codeCtrl.text = code;
    await _previewByCode(code);
  }

  /// input 态提交：凭码预览目标企业（981/982 在此暴露，不进 confirm）。
  Future<void> _previewByCode(String rawCode) async {
    if (_submitting || !_isCurrent) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final preview = await _api.previewByCode(rawCode.trim().toUpperCase());
      if (!_isCurrent) return;
      setState(() {
        _submitting = false;
        _preview = preview;
        _stage = _OrgJoinStage.confirm;
      });
    } on OrganizationApiException catch (e) {
      _showJoinError(e);
    } on Object catch (e) {
      if (!_isCurrent) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  /// confirm 态提交：code-only join（免 orgId），成功回传目标企业事实。
  Future<void> _join() async {
    final preview = _preview;
    if (preview == null || _submitting || !_isCurrent) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.joinByCodeOnly(_codeCtrl.text.trim().toUpperCase());
      if (!mounted || !widget.isCurrentAccount()) return;
      Navigator.of(context).pop(
        OrgJoinDialogResult(
          organizationId: preview.organizationId,
          name: preview.name,
        ),
      );
    } on OrganizationApiException catch (e) {
      _showJoinError(e);
    } on Object catch (e) {
      if (!_isCurrent) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  void _showJoinError(OrganizationApiException e) {
    if (!_isCurrent) return;
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
          : t.organization.picker.joinFailed(msg: e.message);
    });
  }

  /// preview.role → 加入身份展示名（member/admin 之外一律回落普通成员，
  /// 兜底语义与模型解析一致）。
  String _joinRoleLabel(String role) {
    final t = context.t;
    return switch (role) {
      'admin' => t.organization.picker.joinRoleAdmin,
      _ => t.organization.picker.joinRoleMember,
    };
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
              t.organization.picker.joinConfirmWithRole(
                name: _preview?.name ?? '',
                role: _joinRoleLabel(_preview?.role ?? 'member'),
              ),
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
