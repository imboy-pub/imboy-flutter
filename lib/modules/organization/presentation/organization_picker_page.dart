/// 企业选择器（GZAPP-04 G9，计划 §5.1）——「切换工作区」升级为
/// 「切换企业」，数据源必须是当前用户的 Organization membership
/// （GET /organizations/mine），禁止只换文案继续读 Workspace 列表。
///
/// 结构：
/// - 我的企业列表（mine() 真源；本地缓存只作转场即时渲染）
/// - 底部常驻『加入企业』入口（企业邀请码，GZAPP-01 契约
///   POST /organizations/:orgId/join_by_code——码按 org 发放，须携带
///   目标企业 ID；单码全局解析端点缺失，UI 以「企业 ID + 邀请码」双输入
///   兜底，缺口记录进 result.json，GZAPP-09 联调窗口再收敛）
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

class OrganizationPickerPage extends ConsumerStatefulWidget {
  const OrganizationPickerPage({super.key, this.accountKey});

  /// 缓存/指针账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

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
    final outcome = await showDialog<OrganizationJoinOutcome>(
      context: context,
      builder: (ctx) => const _OrgJoinCodeDialog(),
    );
    if (outcome == null || !mounted) return;
    final org = outcome.organization;
    if (org.id.isEmpty) {
      // 契约外响应（缺 organization 投影）：仅刷新列表，不盲切。
      await _refresh();
      return;
    }
    _cache.saveOrgs([org]);
    await _refresh();
    if (!mounted) return;
    final fresh = _orgsWhere(org.id);
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

/// 企业邀请码对话框：企业 ID + 8 位邀请码（GZAPP-01 契约需要 path orgId；
/// 单码全局解析端点缺失，双输入兜底）。错误态（981/982/透传）页内展示。
class _OrgJoinCodeDialog extends StatefulWidget {
  const _OrgJoinCodeDialog();

  @override
  State<_OrgJoinCodeDialog> createState() => _OrgJoinCodeDialogState();
}

class _OrgJoinCodeDialogState extends State<_OrgJoinCodeDialog> {
  final OrganizationApi _api = OrganizationApi();
  final TextEditingController _orgIdCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _orgIdCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final orgId = _orgIdCtrl.text.trim();
    final t = context.t;
    if (_submitting) return;
    if (orgId.isEmpty ||
        int.tryParse(orgId) == null ||
        int.tryParse(orgId)! <= 0) {
      setState(() {
        _error = t.organization.picker.joinOrgIdInvalid;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final outcome = await _api.joinByCode(orgId, code: _codeCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(outcome);
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.isInviteInvalid
            ? t.organization.picker.joinInvalidCode
            : e.isInviteExpired
            ? t.organization.picker.joinExpiredCode
            : t.organization.picker.joinFailedWith(
                msg: e.message,
                code: e.code,
              );
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(t.organization.picker.joinEnterprise),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('org-join-orgid-field'),
            controller: _orgIdCtrl,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: t.organization.picker.joinOrgIdLabel,
              hintText: t.organization.picker.joinOrgIdHint,
              border: const OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalSmall,
          TextField(
            key: const ValueKey('org-join-code-field'),
            controller: _codeCtrl,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            maxLength: 8,
            decoration: InputDecoration(
              labelText: t.organization.picker.joinCodeLabel,
              hintText: t.workspace.joinCodeHint,
              counterText: '',
              border: const OutlineInputBorder(),
            ),
          ),
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
              : Text(t.organization.picker.joinSubmit),
        ),
      ],
    );
  }
}
