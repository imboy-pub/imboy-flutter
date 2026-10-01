/// P0 企业入口状态（计划 §14.1）——ContactPage 顶部企业行的数据核。
///
/// 手写 Notifier（镜像 workspace_shell_provider 模式，不引入新 .g.dart）。
///
/// 语义边界：
/// - orgs 每次都从服务端 `mine()` 刷新（真源）；本地 OrganizationCache 只
///   作转场即时渲染的播种，**绝不当 membership 事实**（§14.3）；
/// - 当前企业 = CurrentOrganizationStore 指针 ∩ mine 列表；指针失效回落
///   列表首个 active（仅展示用，不写指针）；
/// - 网络失败 → error 态（可重试），**绝不伪装成无企业**（§14.1）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// OrganizationApi 提供者（测试 override 注入点）。
final Provider<OrganizationApi> organizationApiProvider =
    Provider<OrganizationApi>((ref) => OrganizationApi());

class OrganizationEntryState {
  /// 我所在的企业（mine() 真源；成功后非空保证为最新一轮）。
  final List<Organization> orgs;

  /// 至少一次成功拉取（区分「还没拉」与「确认没有企业」）。
  final bool loaded;

  final bool loading;
  final String? error;

  const OrganizationEntryState({
    this.orgs = const [],
    this.loaded = false,
    this.loading = false,
    this.error,
  });

  bool get hasOrganizations => orgs.isNotEmpty;

  OrganizationEntryState copyWith({
    List<Organization>? orgs,
    bool? loaded,
    bool? loading,
    bool clearError = false,
    String? error,
  }) => OrganizationEntryState(
    orgs: orgs ?? this.orgs,
    loaded: loaded ?? this.loaded,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class OrganizationEntryNotifier extends Notifier<OrganizationEntryState> {
  @override
  OrganizationEntryState build() => const OrganizationEntryState();

  /// 进入页 / 下拉刷新 / 错误重试共用入口。
  Future<void> fetch() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final organizations = await ref.read(organizationApiProvider).allMine();
      if (!ref.mounted) return;
      state = OrganizationEntryState(
        orgs: organizations,
        loaded: true,
        loading: false,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: e is OrganizationApiException
            ? '${e.message} (code=${e.code})'
            : '$e',
      );
    }
  }

  /// 播种缓存转场渲染（可选；服务端响应到达后覆盖写）。
  void seedFromCache(String accountKey) {
    if (state.loaded || accountKey.isEmpty) return;
    try {
      final cached = OrganizationCache.forAccount(accountKey).orgs;
      if (cached.isNotEmpty && !state.loaded) {
        state = state.copyWith(orgs: cached);
      }
    } on Object {
      // 缓存仅加速展示，失败静默。
    }
  }
}

final organizationEntryProvider =
    NotifierProvider<OrganizationEntryNotifier, OrganizationEntryState>(
      OrganizationEntryNotifier.new,
    );

/// 当前企业解析（指针非真源：不在 mine 列表 → 回落首个 active，仅供展示）。
Organization? resolveCurrentOrganization(
  OrganizationEntryState entry,
  Organization? pointer,
) {
  if (pointer != null) {
    for (final o in entry.orgs) {
      if (o.id == pointer.id) return o;
    }
  }
  for (final o in entry.orgs) {
    if (!o.isArchived) return o;
  }
  return entry.orgs.isEmpty ? null : entry.orgs.first;
}

/// 账号键（登录 UID；未登录/存储未初始化为空串——缓存/指针 scope 均
/// 要求非空，空串时入口卡降级为不渲染）。
String organizationAccountKey() {
  try {
    return UserRepoLocal.to.currentUid;
  } on Object {
    return '';
  }
}
