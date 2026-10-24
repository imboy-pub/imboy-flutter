/// 空间切换控制器（ENT-APP-04 两阶段原子切换的共享实现）。
///
/// 从 OrganizationPickerPage 提取，供企业选择器页与壳级抽屉共用：
/// - [switchToOrganization]：Phase 1 预载（detail 校验 + loadMine）→
///   Phase 2 提交（G11 缓存失效清单 + 指针切换 + 默认工作区落位 +
///   体验模式切 workspace）；任一阶段失败按实际指针对齐回滚。
/// - [selectPersonal]：仅切换体验模式为 personal。
///
/// 调用方契约：
/// - [ref] 用调用方的 WidgetRef（页面/抽屉均持有）；
/// - [isAlive] 闭包承担「页面未 unmount + 会话仍当前 + 账号/epoch 未变」
///   守卫（picker 页保留 didUpdateWidget 换账号重建语义）；
/// - [accountKey] 为空时须显式传入 cache/store（`forAccount('')` 对空账号
///   fail-closed 抛出）；无账号场景应由调用方直接不构造控制器；
/// - 切换成功后壳 key 含 (orgId, wsId) 自动销毁重建，调用方无需收尾；
///   aborted 结果静默处理（守卫已失效，界面即将/已经不存在）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';

/// 切换结果：aborted=守卫失效静默中止；failed 时 [SpaceSwitchOutcome.message]
/// 为可直接展示的完整错误文案。
enum SpaceSwitchStatus { success, aborted, failed }

class SpaceSwitchOutcome {
  const SpaceSwitchOutcome(this.status, [this.message]);

  final SpaceSwitchStatus status;
  final String? message;

  bool get isSuccess => status == SpaceSwitchStatus.success;
}

/// 内部控制流哨兵：守卫失效时中止，不作为失败上报。
class _SwitchAborted implements Exception {
  const _SwitchAborted();
}

class OrganizationSwitchController {
  OrganizationSwitchController({
    required this.ref,
    required this.accountKey,
    required this.isAlive,
    OrganizationApi? api,
    OrganizationCache? cache,
    CurrentOrganizationStore? store,
  }) : api = api ?? OrganizationApi(),
       cache = cache ?? OrganizationCache.forAccount(accountKey),
       store = store ?? CurrentOrganizationStore.forAccount(accountKey);

  final WidgetRef ref;
  final String accountKey;

  /// 每次触碰共享状态前的存活守卫（mounted + 会话/账号/epoch 仍当前）。
  final bool Function() isAlive;

  final OrganizationApi api;
  final OrganizationCache cache;
  final CurrentOrganizationStore store;

  bool _switching = false;

  static const SpaceSwitchOutcome _aborted = SpaceSwitchOutcome(
    SpaceSwitchStatus.aborted,
  );

  /// 切换进行中（防重复提交产生竞态切换）。
  bool get switching => _switching;

  /// 两阶段原子切换到目标企业；语义与错误文案与原 picker 页一致。
  Future<SpaceSwitchOutcome> switchToOrganization(Organization org) async {
    if (_switching || accountKey.isEmpty || !isAlive()) return _aborted;
    final prev = _pointedOrgIn(cache.orgs);
    final previousShell = ref.read(workspaceShellProvider);
    var committing = false;
    _switching = true;
    try {
      final fresh = await _prepareTarget(org);
      committing = true;
      await _commitTarget(fresh, prev);
    } on _SwitchAborted {
      return _aborted;
    } on Object catch (e) {
      if (!isAlive()) return _aborted;
      final recoveryError = committing
          ? await _rollbackSwitch(prev, org, previousShell)
          : null;
      if (!isAlive()) return _aborted;
      return SpaceSwitchOutcome(
        SpaceSwitchStatus.failed,
        switchErrorText(e, recovered: committing && recoveryError == null),
      );
    } finally {
      _switching = false;
    }
    // try 之外不能用 _guard()：这里抛出不会被上面的 on _SwitchAborted 捕获。
    if (!isAlive()) return _aborted;
    return const SpaceSwitchOutcome(SpaceSwitchStatus.success);
  }

  /// 切回个人空间：仅切体验模式，不动企业指针。
  Future<SpaceSwitchOutcome> selectPersonal() async {
    if (_switching || accountKey.isEmpty || !isAlive()) return _aborted;
    _switching = true;
    try {
      await ref
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.personal);
      _guard();
    } on _SwitchAborted {
      return _aborted;
    } on Object {
      if (!isAlive()) return _aborted;
      return SpaceSwitchOutcome(
        SpaceSwitchStatus.failed,
        t.common.settingFailedPleaseTryAgain,
      );
    } finally {
      _switching = false;
    }
    return const SpaceSwitchOutcome(SpaceSwitchStatus.success);
  }

  /// Phase 1 预载：detail 校验当前账号仍可访问目标企业（被移出/归档清理
  /// → 403/404 在此暴露）+ loadMine 预载新壳；失败未触碰任何本地状态。
  Future<Organization> _prepareTarget(Organization org) async {
    final fresh = await api.detail(org.id);
    _guard();
    await ref
        .read(workspaceShellProvider.notifier)
        .loadMine(keepListOnFailure: true);
    _guard();
    final error = ref.read(workspaceShellProvider).error;
    if (error != null && error.isNotEmpty) throw StateError(error);
    return fresh;
  }

  /// Phase 2 提交：G11 缓存失效清单（① 上一企业 ② 五个 wsId family
  /// provider ③ 指针先持久化后内存）+ 默认工作区落位 + 体验模式。
  Future<void> _commitTarget(Organization fresh, Organization? prev) async {
    _guard();
    if (prev != null) cache.invalidateOrg(prev.id);
    ref.invalidate(workspaceOverviewProvider);
    ref.invalidate(workspaceChannelsProvider);
    ref.invalidate(workspaceGroupsProvider);
    ref.invalidate(workspaceMembersProvider);
    ref.invalidate(workspaceProjectsProvider);
    await store.set(fresh);
    _guard();
    await _landDefaultWorkspace(fresh);
    _guard();
    await ref
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
  }

  /// Phase 2 失败补偿：指针恢复 prev（支持 null=清空指针）；目标企业缓存
  /// 播种一并丢弃；补偿保存失败时按实际指针对齐壳，并返回失败供重试。
  Future<Object?> _rollbackSwitch(
    Organization? prev,
    Organization failed,
    WorkspaceShellState previousShell,
  ) async {
    if (!isAlive()) return null;
    Object? recoveryError;
    try {
      await store.restore(prev);
    } on Object catch (e) {
      recoveryError = e;
    }
    if (!isAlive()) return recoveryError;
    cache.invalidateOrg(failed.id);
    final pointed = store.value;
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
    return recoveryError;
  }

  Future<void> _landDefaultWorkspace(Organization org) async {
    await ref.read(workspaceShellProvider.notifier).selectOrganization(
      org.id,
      () async {
        final dw = await api.defaultWorkspace(org.id);
        _guard();
        return dw.defaultWorkspaceId;
      },
    );
  }

  void _guard() {
    if (!isAlive()) throw const _SwitchAborted();
  }

  /// 指针非真源：不在 mine 列表（被移出/归档清理）→ 视为无当前企业。
  Organization? _pointedOrgIn(List<Organization> orgs) {
    final pointed = store.value;
    if (pointed == null) return null;
    for (final o in orgs) {
      if (o.id == pointed.id) return o;
    }
    return null;
  }

  /// 失败原因文案（列表读取与切换共用）：403→无权限、API message 为
  /// 服务端人话文案原样展示、其余回落通用重试文案；任何分支都不得
  /// 拼接 `code=` 等原始技术值（vocabulary 红线 / T07 验收）。
  static String apiErrorText(Object e) {
    if (e is OrganizationApiException) {
      if (e.code == 403) return t.common.noPermission;
      final msg = e.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    return t.common.settingFailedPleaseTryAgain;
  }

  /// 切换失败文案：回滚成功=完整句「切换失败，已恢复原选择」
  /// （vocabulary 冻结文案）；否则「切换失败：<原因>」。
  static String switchErrorText(Object e, {required bool recovered}) {
    if (recovered) return t.organization.picker.switchFailedRecovered;
    return '${t.organization.picker.switchFailed}：${apiErrorText(e)}';
  }
}
