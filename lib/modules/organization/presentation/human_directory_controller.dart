/// Human Directory 状态机（计划 §14.3 Flutter Request / Switch / Pagination
/// Contract 的唯一实现，P1 §14.2 页面的数据核）。
///
/// ## request_generation / request_key
/// - 页面内单调递增整数 `_generation`；每次 initial load、refresh、retry、
///   Organization 切换、path/query 变化都 `++_generation`。
/// - `request_key = account_id + organization_id + department/path + query`
///   （见 [HumanDirectoryRequest.requestKey]）。
/// - 每个在途请求捕获发起时的 `(generation, requestKey)`；**任何**响应 /
///   catch / 收尾写状态前必须 `_accept(gen, key)` 双匹配，否则整体丢弃——
///   旧请求即使后返回也写不进 data/error/loading/cursor；stale 请求的
///   收尾不得关闭最新请求的 loading（loading 属于当前 generation）。
///   取消请求只是性能优化，正确性唯一依据是 generation+key 匹配。
///
/// ## 两阶段 Organization 切换
/// [switchOrganization]：先执行 `prepare`（验 mine() membership 真源 +
/// 目标 Org 的 Workspace 壳加载，由页面注入实现），成功后才执行 `commit`
/// （CurrentOrganizationStore 指针 + 缓存失效，页面注入）；任一步失败保留
/// 旧 Org/Workspace 与已成功数据并给出可重试错误（[switchError]）——绝不
/// 留下「指针已切、列表仍旧」。commit 成功后本控制器整体 reconfigure 到
/// 目标 Org 根级（generation 递增，上一 Org 的列表/cursor/error 全弃）。
///
/// ## 分页
/// - 部门 / 成员 / 搜索各自维护 `items/cursor/loading/error/endReached`，
///   请求并发去重（loading 闸门），append 顺序服从服务端 cursor；
/// - 按 EntityId 去重（append 跳过已存在 ID）；
/// - cursor 请求 400（游标 malformed/tampered/foreign/expired）→ 清空对应
///   分页并从首页重试一次；再次失败只展示错误，绝不循环。
///
/// ## refresh / retry / 搜索
/// - 网络错误的 refresh/retry 保留已有成功数据；成功原子替换（不清空再填），
///   403/404 清空目录并作废在途同代请求；其余失败不变成 empty，initial 无数据时全屏
///   loading/error（[phase]）。
/// - 搜索：widget 层固定 300ms debounce 后调 [setQuery]；trim 后 <2 字符
///   不发请求；query 变化清空部门/成员/搜索三类分页状态并生成新
///   generation；搜索结果独立于目录分页，绝不合并。
///
/// 本类为纯 Dart ChangeNotifier（仅 foundation），可被单测直接驱动。
library;

import 'package:flutter/foundation.dart';

import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/human_directory_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';

/// 页面级请求身份：request_key 的四要素。
class HumanDirectoryRequest {
  final String accountKey;
  final EntityId organizationId;

  /// 当前部门层级；null = 企业根。
  final EntityId? departmentId;

  /// 已 trim 的生效 query；'' = 目录模式，>=2 字符 = 搜索模式。
  final String query;

  const HumanDirectoryRequest({
    required this.accountKey,
    required this.organizationId,
    this.departmentId,
    this.query = '',
  });

  HumanDirectoryRequest copyWith({
    EntityId? organizationId,
    EntityId? departmentId,
    bool clearDepartment = false,
    String? query,
  }) => HumanDirectoryRequest(
    accountKey: accountKey,
    organizationId: organizationId ?? this.organizationId,
    departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
    query: query ?? this.query,
  );

  /// §14.3：request_key = account_id + organization_id + department/path + query。
  String get requestKey =>
      '$accountKey|org:$organizationId|dept:${departmentId ?? 'root'}|q:$query';

  bool get isSearchMode => query.length >= 2;
}

/// 单节（部门/成员/搜索）分页状态。
class HumanDirectorySection<T> {
  final List<T> items;

  /// 服务端 opaque 游标；null = 末页。
  final String? cursor;
  final bool loading;
  final String? error;
  final bool endReached;

  /// cursor 400 的一次性首页重试已消耗（节内 per-generation，重置即复位）。
  final bool consumedCursorResetRetry;

  const HumanDirectorySection({
    this.items = const [],
    this.cursor,
    this.loading = false,
    this.error,
    this.endReached = false,
    this.consumedCursorResetRetry = false,
  });

  static HumanDirectorySection<T> empty<T>({
    bool consumedCursorResetRetry = false,
  }) => HumanDirectorySection<T>(
    consumedCursorResetRetry: consumedCursorResetRetry,
  );

  HumanDirectorySection<T> copyWith({
    List<T>? items,
    String? cursor,
    bool? loading,
    bool clearError = false,
    Object? error = _unset,
    bool? endReached,
    bool? consumedCursorResetRetry,
  }) => HumanDirectorySection<T>(
    items: items ?? this.items,
    cursor: cursor ?? this.cursor,
    loading: loading ?? this.loading,
    error: clearError
        ? null
        : (identical(error, _unset) ? this.error : error as String?),
    endReached: endReached ?? this.endReached,
    consumedCursorResetRetry:
        consumedCursorResetRetry ?? this.consumedCursorResetRetry,
  );

  static const _unset = Object();
}

/// 页面整体阶段：仅 initial 无数据时使用全屏 loading / error。
enum HumanDirectoryPhase { idle, loading, error, ready }

class HumanDirectoryController extends ChangeNotifier {
  HumanDirectoryController({required HumanDirectoryDataSource dataSource})
    : _source = dataSource;

  final HumanDirectoryDataSource _source;

  HumanDirectoryRequest? _identity;
  int _generation = 0;

  HumanDirectorySection<HumanDirectoryDepartment> _departments =
      HumanDirectorySection.empty();
  HumanDirectorySection<HumanDirectoryMember> _members =
      HumanDirectorySection.empty();
  HumanDirectorySection<HumanDirectorySearchItem> _search =
      HumanDirectorySection.empty();

  List<HumanDirectoryDepartment> _myDepartments = const [];

  /// 组织 active 成员总数（/me member_count；通讯录根页脚「共X人」）。
  /// /me 失败时保持 0 → 页脚不渲染（与「我的部门」捷径同 best-effort）。
  int _memberCount = 0;
  bool _meLoading = false;
  String? _meError;

  HumanDirectoryPhase _phase = HumanDirectoryPhase.idle;
  String? _pageError;
  bool _refreshing = false;

  bool _switching = false;
  Organization? _switchTarget;
  String? _switchError;

  // ---- 只读状态 ----

  HumanDirectoryRequest? get identity => _identity;
  int get generation => _generation;
  HumanDirectorySection<HumanDirectoryDepartment> get departments =>
      _departments;
  HumanDirectorySection<HumanDirectoryMember> get members => _members;
  HumanDirectorySection<HumanDirectorySearchItem> get search => _search;
  List<HumanDirectoryDepartment> get myDepartments => _myDepartments;

  /// 组织 active 成员总数（0 = 未知/未加载，调用方据此隐藏页脚）。
  int get memberCount => _memberCount;
  bool get meLoading => _meLoading;
  String? get meError => _meError;
  HumanDirectoryPhase get phase => _phase;
  String? get pageError => _pageError;
  bool get refreshing => _refreshing;
  bool get isSearchMode => _identity?.isSearchMode ?? false;
  bool get switching => _switching;
  Organization? get switchTarget => _switchTarget;
  String? get switchError => _switchError;

  /// generation + request_key 双匹配才允许写状态（§14.3）。
  bool _accept(int gen, String key) =>
      _identity != null &&
      _identity!.accountKey.isNotEmpty &&
      gen == _generation &&
      key == _identity!.requestKey;

  @override
  void dispose() {
    _generation++;
    _identity = null;
    super.dispose();
  }

  // ---- 生命周期入口 ----

  /// 首次配置 / didUpdateWidget（orgId、账号、path 变化）：身份不同则
  /// generation 递增并从首页重建；上一 Org/层级的列表、cursor、error 一律
  /// 不复用。身份相同则幂等 no-op。
  void configure({
    required String accountKey,
    required EntityId organizationId,
    EntityId? departmentId,
    String query = '',
  }) {
    final next = HumanDirectoryRequest(
      accountKey: accountKey,
      organizationId: organizationId,
      departmentId: departmentId,
      query: query,
    );
    if (_identity != null && _identity!.requestKey == next.requestKey) return;
    _identity = next;
    _reloadFromScratch();
  }

  /// 进入下一层部门（页面内部 path 变化）：generation 递增 + 从首页重建。
  void openDepartment(EntityId departmentId) {
    final id = _identity;
    if (id == null || departmentId.isEmpty) return;
    if (id.departmentId == departmentId) return;
    _identity = HumanDirectoryRequest(
      accountKey: id.accountKey,
      organizationId: id.organizationId,
      departmentId: departmentId,
      query: '',
    );
    _reloadFromScratch();
  }

  /// 返回企业根（面包屑「全部」/切换后落位共用）。
  void openRoot() {
    final id = _identity;
    if (id == null || id.departmentId == null) return;
    _identity = id.copyWith(clearDepartment: true, query: '');
    _reloadFromScratch();
  }

  /// 下拉刷新 / 全屏重试：保留已有成功数据；成功后各节原子替换；失败
  /// 普通错误不清空旧数据；403/404 撤下当前目录并显示错误。
  Future<void> refresh() async {
    final id = _identity;
    // A refresh must not invalidate an in-flight two-phase switch: its commit
    // owns the organization pointer until success or rollback completes.
    if (id == null || id.accountKey.isEmpty || _switching) return;
    final gen = ++_generation;
    final key = id.requestKey;
    final hasData =
        _departments.items.isNotEmpty ||
        _members.items.isNotEmpty ||
        _search.items.isNotEmpty;
    _pageError = null;
    if (hasData) {
      _refreshing = true;
    } else {
      _phase = HumanDirectoryPhase.loading;
    }
    _clearSwitchError();
    notifyListeners();
    if (id.isSearchMode) {
      await _fetchSearch(gen, key, cursor: null, append: false);
    } else {
      await Future.wait([
        _fetchDepartments(gen, key, cursor: null, append: false),
        _fetchMembers(gen, key, cursor: null, append: false),
        _fetchMe(gen, key),
      ]);
    }
  }

  /// 搜索入口（widget 层 300ms debounce 后调用原始输入）。
  /// trim 后与当前生效 query 相同 → no-op；<2 字符 → 目录模式（不发搜索
  /// 请求）；query 变化 → 清空三类分页状态 + 新 generation + 按模式重建。
  void setQuery(String raw) {
    final id = _identity;
    if (id == null) return;
    final q = raw.trim();
    if (q == id.query) return;
    _identity = id.copyWith(query: q);
    _reloadFromScratch();
  }

  /// 部门分页追加（滚动触底；loading/endReached/cursor 闸门 + 并发去重）。
  Future<void> loadMoreDepartments() async {
    final id = _identity;
    if (id == null || id.isSearchMode) return;
    final s = _departments;
    if (s.loading || s.endReached || s.cursor == null) return;
    await _fetchDepartments(
      _generation,
      id.requestKey,
      cursor: s.cursor,
      append: true,
    );
  }

  /// 成员分页追加（与部门 cursor 完全独立）。
  Future<void> loadMoreMembers() async {
    final id = _identity;
    if (id == null || id.isSearchMode) return;
    final s = _members;
    if (s.loading || s.endReached || s.cursor == null) return;
    await _fetchMembers(
      _generation,
      id.requestKey,
      cursor: s.cursor,
      append: true,
    );
  }

  /// 搜索结果分页追加（独立于目录两节）。
  Future<void> loadMoreSearch() async {
    final id = _identity;
    if (id == null || !id.isSearchMode) return;
    final s = _search;
    if (s.loading || s.endReached || s.cursor == null) return;
    await _fetchSearch(
      _generation,
      id.requestKey,
      cursor: s.cursor,
      append: true,
    );
  }

  /// 单节内联重试（保留本节与他节已有数据；不递增 generation——页面级
  /// retry 才递增，见 [refresh]）。
  Future<void> retrySection(HumanDirectorySectionKind kind) async {
    final id = _identity;
    if (id == null) return;
    final gen = _generation;
    final key = id.requestKey;
    switch (kind) {
      case HumanDirectorySectionKind.departments:
        if (!id.isSearchMode) {
          await _fetchDepartments(gen, key, cursor: null, append: false);
        }
      case HumanDirectorySectionKind.members:
        if (!id.isSearchMode) {
          await _fetchMembers(gen, key, cursor: null, append: false);
        }
      case HumanDirectorySectionKind.search:
        if (id.isSearchMode) {
          await _fetchSearch(gen, key, cursor: null, append: false);
        }
    }
  }

  /// 两阶段 Organization 切换（§14.3）：
  /// 1. `prepare`：验 mine() membership 真源 + 目标 Org 的 Workspace 壳
  ///    加载（页面注入；失败抛异常）；
  /// 2. `commit`：CurrentOrganizationStore 指针提交 + 缓存失效（页面注入；
  ///    支持 Future——store 持久化为先，失败抛出）。任一步失败：旧 Org/
  ///    数据原样保留（页面负责补偿回滚指针后 rethrow），[switchError] 可
  ///    重试；成功后整体 reconfigure 到目标 Org 根级。
  Future<void> switchOrganization(
    Organization target, {
    required Future<void> Function(Organization target) prepare,
    required Future<void> Function(Organization target) commit,
  }) async {
    final id = _identity;
    if (id == null || id.accountKey.isEmpty || _switching) return;
    final generation = _generation;
    final key = id.requestKey;
    if (id.organizationId == target.id) return;
    _switching = true;
    _switchTarget = target;
    _switchError = null;
    notifyListeners();
    try {
      await prepare(target);
      if (!_accept(generation, key)) return;
    } on Object catch (e) {
      if (!_accept(generation, key)) return;
      // Phase 1 失败：指针未提交、数据未动——完整 rollback。
      _switching = false;
      _switchError = _errorText(e);
      notifyListeners();
      return;
    }
    try {
      await commit(target);
      if (!_accept(generation, key)) return;
    } on Object catch (e) {
      if (!_accept(generation, key)) return;
      // Phase 2 失败（§14.3：任一步失败保留旧 Org/Workspace/已有数据）：
      // 回调方负责把指针/缓存补偿回旧值后 rethrow；控制器保持旧 Org
      // 身份与已有数据（不 reconfigure），回到可重试态——绝不半切换。
      _switching = false;
      _switchTarget = null;
      _switchError = _errorText(e);
      notifyListeners();
      return;
    }
    _switching = false;
    _switchTarget = null;
    notifyListeners();
    // Phase 2 已提交：切到目标 Org 根级从首页重建（generation 递增）。
    configure(
      accountKey: id.accountKey,
      organizationId: target.id,
      departmentId: null,
      query: '',
    );
  }

  void clearSwitchError() => _clearSwitchError();

  void _clearSwitchError() {
    if (_switchError != null) {
      _switchError = null;
      notifyListeners();
    }
  }

  // ---- 内部：身份变化后的首页重建 ----

  void _reloadFromScratch() {
    _generation++;
    _departments = HumanDirectorySection.empty();
    _members = HumanDirectorySection.empty();
    _search = HumanDirectorySection.empty();
    _myDepartments = const [];
    _memberCount = 0;
    _meError = null;
    _meLoading = false;
    _switching = false;
    _switchTarget = null;
    _switchError = null;
    _refreshing = false;
    _pageError = null;
    _phase = _identity!.accountKey.isEmpty
        ? HumanDirectoryPhase.idle
        : HumanDirectoryPhase.loading;
    notifyListeners();
    final gen = _generation;
    final key = _identity!.requestKey;
    if (_identity!.isSearchMode) {
      _fetchSearch(gen, key, cursor: null, append: false);
    } else {
      _fetchDepartments(gen, key, cursor: null, append: false);
      _fetchMembers(gen, key, cursor: null, append: false);
      _fetchMe(gen, key);
    }
  }

  // ---- 内部：三节抓取（每处 await 后先 _accept 再写状态） ----

  Future<void> _fetchDepartments(
    int gen,
    String key, {
    String? cursor,
    required bool append,
  }) async {
    if (!_accept(gen, key)) return;
    _departments = _departments.copyWith(loading: true, clearError: true);
    notifyListeners();
    final id = _identity!;
    HumanDirectoryPage<HumanDirectoryDepartment> page;
    try {
      page = await _source.directoryDepartments(
        organizationId: id.organizationId,
        parentId: id.departmentId,
        cursor: cursor,
      );
    } on Object catch (e) {
      if (!_accept(gen, key)) return; // stale：连 loading 都不写
      if (_rejectAccess(e)) return;
      if (_isCursorInvalid(e) &&
          cursor != null &&
          !_departments.consumedCursorResetRetry) {
        await _resetFromFirstPage(
          gen,
          key,
          HumanDirectorySectionKind.departments,
        );
        return;
      }
      _departments = _departments.copyWith(
        loading: false,
        error: _errorText(e),
      );
      notifyListeners();
      _settlePhase();
      return;
    }
    if (!_accept(gen, key)) return;
    _departments = _applyPage(_departments, page, append, (d) => d.id);
    notifyListeners();
    _settlePhase();
  }

  Future<void> _fetchMembers(
    int gen,
    String key, {
    String? cursor,
    required bool append,
  }) async {
    if (!_accept(gen, key)) return;
    _members = _members.copyWith(loading: true, clearError: true);
    notifyListeners();
    final id = _identity!;
    HumanDirectoryPage<HumanDirectoryMember> page;
    try {
      page = await _source.directoryMembers(
        organizationId: id.organizationId,
        departmentId: id.departmentId,
        cursor: cursor,
      );
    } on Object catch (e) {
      if (!_accept(gen, key)) return;
      if (_rejectAccess(e)) return;
      if (_isCursorInvalid(e) &&
          cursor != null &&
          !_members.consumedCursorResetRetry) {
        await _resetFromFirstPage(gen, key, HumanDirectorySectionKind.members);
        return;
      }
      _members = _members.copyWith(loading: false, error: _errorText(e));
      notifyListeners();
      _settlePhase();
      return;
    }
    if (!_accept(gen, key)) return;
    _members = _applyPage(_members, page, append, (m) => m.userId);
    notifyListeners();
    _settlePhase();
  }

  Future<void> _fetchSearch(
    int gen,
    String key, {
    String? cursor,
    required bool append,
  }) async {
    if (!_accept(gen, key)) return;
    _search = _search.copyWith(loading: true, clearError: true);
    notifyListeners();
    final id = _identity!;
    HumanDirectoryPage<HumanDirectorySearchItem> page;
    try {
      page = await _source.directorySearch(
        organizationId: id.organizationId,
        q: id.query,
        cursor: cursor,
      );
    } on Object catch (e) {
      if (!_accept(gen, key)) return;
      if (_rejectAccess(e)) return;
      if (_isCursorInvalid(e) &&
          cursor != null &&
          !_search.consumedCursorResetRetry) {
        await _resetFromFirstPage(gen, key, HumanDirectorySectionKind.search);
        return;
      }
      _search = _search.copyWith(loading: false, error: _errorText(e));
      notifyListeners();
      _settlePhase();
      return;
    }
    if (!_accept(gen, key)) return;
    _search = _applyPage(_search, page, append, (s) => s.dedupeKey);
    notifyListeners();
    _settlePhase();
  }

  Future<void> _fetchMe(int gen, String key) async {
    if (!_accept(gen, key)) return;
    _meLoading = true;
    _meError = null;
    notifyListeners();
    final id = _identity!;
    try {
      final me = await _source.directoryMe(organizationId: id.organizationId);
      if (!_accept(gen, key)) return;
      _myDepartments = me.list;
      _memberCount = me.memberCount;
    } on Object catch (e) {
      if (!_accept(gen, key)) return;
      if (_rejectAccess(e)) return;
      // Network failures in the shortcut are best-effort; access refusal is terminal.
      _meError = _errorText(e);
    }
    _meLoading = false;
    notifyListeners();
    _settlePhase();
  }

  /// cursor 400：清空对应分页（items/cursor/endReached + 一次性重试标记）
  /// 并从首页重试一次；首页再失败 → 节内 error，不循环。
  Future<void> _resetFromFirstPage(
    int gen,
    String key,
    HumanDirectorySectionKind kind,
  ) async {
    switch (kind) {
      case HumanDirectorySectionKind.departments:
        _departments = HumanDirectorySection.empty(
          consumedCursorResetRetry: true,
        );
      case HumanDirectorySectionKind.members:
        _members = HumanDirectorySection.empty(consumedCursorResetRetry: true);
      case HumanDirectorySectionKind.search:
        _search = HumanDirectorySection.empty(consumedCursorResetRetry: true);
    }
    notifyListeners();
    switch (kind) {
      case HumanDirectorySectionKind.departments:
        await _fetchDepartments(gen, key, cursor: null, append: false);
      case HumanDirectorySectionKind.members:
        await _fetchMembers(gen, key, cursor: null, append: false);
      case HumanDirectorySectionKind.search:
        await _fetchSearch(gen, key, cursor: null, append: false);
    }
  }

  /// 成功页落地：append 按 EntityId 去重保序；replace 原子整换（不清空
  /// 再填）。endReached = cursor == null（A4：末页 cursor=null）。
  /// consumedCursorResetRetry 在成功后保留（同 generation 内 cursor 400
  /// 的首页重试只允许一次，杜绝循环）。
  HumanDirectorySection<T> _applyPage<T>(
    HumanDirectorySection<T> section,
    HumanDirectoryPage<T> page,
    bool append,
    String Function(T) idOf,
  ) {
    final List<T> items;
    if (append) {
      final seen = section.items.map(idOf).toSet();
      items = [
        ...section.items,
        for (final row in page.list)
          if (seen.add(idOf(row))) row,
      ];
    } else {
      final seen = <String>{};
      items = [
        for (final row in page.list)
          if (seen.add(idOf(row))) row,
      ];
    }
    return HumanDirectorySection<T>(
      items: items,
      cursor: page.cursor,
      loading: false,
      error: null,
      endReached: page.cursor == null,
      consumedCursorResetRetry: section.consumedCursorResetRetry,
    );
  }

  /// 全部在途请求落定后收敛页面阶段：initial 无数据且两节皆败 → 全屏
  /// error；否则 ready（节内错误由各节内联展示）。
  void _settlePhase() {
    final anyLoading =
        _departments.loading ||
        _members.loading ||
        _search.loading ||
        _meLoading;
    if (anyLoading) return;
    _refreshing = false;
    if (_phase == HumanDirectoryPhase.loading) {
      final id = _identity;
      if (id != null && id.isSearchMode) {
        if (_search.items.isEmpty && _search.error != null) {
          _phase = HumanDirectoryPhase.error;
          _pageError = _search.error;
        } else {
          _phase = HumanDirectoryPhase.ready;
        }
      } else if (_departments.items.isEmpty &&
          _members.items.isEmpty &&
          _departments.error != null &&
          _members.error != null) {
        _phase = HumanDirectoryPhase.error;
        _pageError = _departments.error;
      } else {
        _phase = HumanDirectoryPhase.ready;
      }
    }
    notifyListeners();
  }

  /// 图形架构与成员列表共用撤权终态，防止切回列表展示旧数据。
  void rejectAccess(OrganizationApiException error) => _rejectAccess(error);

  /// Access refusal invalidates the entire generation, including sibling requests.
  bool _rejectAccess(Object error) {
    if (error is! OrganizationApiException ||
        (error.code != 403 && error.code != 404)) {
      return false;
    }
    _generation++;
    _departments = HumanDirectorySection.empty();
    _members = HumanDirectorySection.empty();
    _search = HumanDirectorySection.empty();
    _myDepartments = const [];
    _memberCount = 0;
    _meLoading = false;
    _meError = null;
    _refreshing = false;
    _switching = false;
    _switchTarget = null;
    _switchError = null;
    _pageError = _errorText(error);
    _phase = HumanDirectoryPhase.error;
    notifyListeners();
    return true;
  }

  bool _isCursorInvalid(Object e) =>
      e is OrganizationApiException && e.code == 400;

  String _errorText(Object e) =>
      e is OrganizationApiException ? e.message : '$e';
}

/// 节标识（内联重试 / cursor 400 复位共用）。
enum HumanDirectorySectionKind { departments, members, search }
