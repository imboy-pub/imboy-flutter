/// Human Directory 状态机 oracle（计划 §14.3 Flutter Oracle 口径）。
///
/// 用可控延迟 fake transport（Completer 挂起/放行）证明：
/// - A 慢 B 快时 B 胜出；旧请求后到被丢弃（成功/失败路径都丢）；stale
///   收尾不得关闭最新请求的 loading；
/// - 切换失败 rollback（旧 Org/数据保留 + 可重试错误）、成功后整体重建；
/// - refresh 失败保留旧数据、成功原子替换、initial 失败才全屏错误；
/// - org / path / query 变化重置分页（上一上下文 cursor/error 不复用）；
/// - 重复 EntityId 去重；部门/成员 cursor 独立；cursor 400 清空重试一次
///   再失败展示错误不循环；trim <2 字符不发搜索请求；搜索独立分页。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/human_directory_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/human_directory_controller.dart';

HumanDirectoryDepartment _dept(
  String id, {
  String parent = '',
  int count = 0,
}) => HumanDirectoryDepartment(
  id: id,
  name: 'D$id',
  parentId: parent,
  memberCount: count,
);

HumanDirectoryMember _member(String id) =>
    HumanDirectoryMember(userId: id, displayName: 'M$id');

HumanDirectoryPage<T> _page<T>(
  List<T> list, {
  String? cursor,
  bool hasMore = false,
}) => HumanDirectoryPage<T>(list: list, cursor: cursor, hasMore: hasMore);

const orgA = '7001';
const orgB = '7002';
const deptX = '8001';

/// 可控延迟 fake：departments / search 每次调用入队 Completer 由测试放行
/// （可控延迟）；members / me 默认同步完成（避免无关挂起），可按用例覆写。
class FakeSource implements HumanDirectoryDataSource {
  final List<Completer<HumanDirectoryPage<HumanDirectoryDepartment>>>
  pendingDepartments = [];
  final List<Completer<HumanDirectoryPage<HumanDirectorySearchItem>>>
  pendingSearch = [];

  /// members / me 的可编程响应（默认空末页 / 空列表）。
  HumanDirectoryPage<HumanDirectoryMember> membersPage = _page(
    <HumanDirectoryMember>[],
  );
  Object? membersError;
  HumanDirectoryMe meResult = HumanDirectoryMe(
    organizationId: orgA,
    list: const [],
  );
  Object? meError;

  /// 参数记录（organizationId|parent/department/q|cursor）。
  final List<String> deptCalls = [];
  final List<String> memberCalls = [];
  final List<String> meCalls = [];
  final List<String> searchCalls = [];

  @override
  Future<HumanDirectoryPage<HumanDirectoryDepartment>> directoryDepartments({
    required String organizationId,
    String? parentId,
    String? cursor,
    int? limit,
  }) {
    deptCalls.add('$organizationId|p=${parentId ?? '-'}|c=${cursor ?? '-'}');
    final c = Completer<HumanDirectoryPage<HumanDirectoryDepartment>>();
    pendingDepartments.add(c);
    return c.future;
  }

  @override
  Future<HumanDirectoryPage<HumanDirectoryMember>> directoryMembers({
    required String organizationId,
    String? departmentId,
    String? cursor,
    int? limit,
  }) {
    memberCalls.add(
      '$organizationId|d=${departmentId ?? '-'}|c=${cursor ?? '-'}',
    );
    if (membersError != null) {
      return Future.error(membersError!);
    }
    return Future.value(membersPage);
  }

  @override
  Future<HumanDirectoryMe> directoryMe({required String organizationId}) {
    meCalls.add(organizationId);
    if (meError != null) {
      return Future.error(meError!);
    }
    return Future.value(meResult);
  }

  @override
  Future<HumanDirectoryPage<HumanDirectorySearchItem>> directorySearch({
    required String organizationId,
    required String q,
    String? cursor,
    int? limit,
  }) {
    searchCalls.add('$organizationId|q=$q|c=${cursor ?? '-'}');
    final c = Completer<HumanDirectoryPage<HumanDirectorySearchItem>>();
    pendingSearch.add(c);
    return c.future;
  }
}

/// boot：configure 触发首页三请求；dept 为 pending[0]。
HumanDirectoryController _boot(FakeSource src, {String org = orgA}) {
  final c = HumanDirectoryController(dataSource: src);
  c.configure(accountKey: 'u1', organizationId: org);
  return c;
}

/// 让微任务队列跑空（controller 的 async 落地无需真实时钟）。
Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('§14.3 request_generation / request_key', () {
    test('A 慢 B 快：B 胜出；A 后到被丢弃（成功与失败两条路径）', () async {
      final src = FakeSource();
      final c = _boot(src);
      final genA = c.generation;
      expect(src.deptCalls, hasLength(1)); // A
      final reqA = src.pendingDepartments.first;

      // B：refresh 生成新 generation。
      final refreshB = c.refresh();
      expect(c.generation, genA + 1);
      expect(src.deptCalls, hasLength(2)); // B
      final reqB = src.pendingDepartments[1];
      expect(c.departments.loading, isTrue);

      // B 先回：生效。
      reqB.complete(_page([_dept('b1')]));
      await refreshB;
      expect(c.departments.items.map((d) => d.id), ['b1']);
      expect(c.departments.loading, isFalse);

      // A 后到（成功）：整体丢弃。
      reqA.complete(_page([_dept('a1'), _dept('a2')]));
      await _tick();
      expect(c.departments.items.map((d) => d.id), ['b1']);
      expect(c.departments.error, isNull);

      // C：refresh 再起一代；A 代收尾已结束（其丢弃在上面证明），这里
      // 验证 C 在途期间不被任何 stale 干扰并正常落地。
      final refreshC = c.refresh();
      final reqC = src.pendingDepartments.last;
      expect(c.departments.loading, isTrue, reason: 'C 在途');
      reqC.complete(_page([_dept('c1')]));
      await refreshC;
      expect(c.departments.items.map((d) => d.id), ['c1']);
      expect(c.departments.error, isNull);
      expect(c.generation, genA + 2);
    });

    test('stale 收尾不得关闭最新请求的 loading', () async {
      final src = FakeSource();
      final c = _boot(src);
      final reqA = src.pendingDepartments.first;

      final refreshB = c.refresh(); // 不先 await：保持 B 在途
      final reqB = src.pendingDepartments.last;
      expect(c.departments.loading, isTrue);

      // 旧请求 A 结束（成功路径收尾）——B 的 loading 必须保持。
      reqA.complete(_page([_dept('stale')]));
      await _tick();
      expect(
        c.departments.loading,
        isTrue,
        reason: 'stale finally 不得关最新 loading',
      );
      expect(c.departments.items, isEmpty, reason: 'stale 成功响应不得写入数据');

      reqB.complete(_page([_dept('fresh')]));
      await refreshB;
      expect(c.departments.loading, isFalse);
      expect(c.departments.items.map((d) => d.id), ['fresh']);
    });
  });

  group('refresh / retry 数据保留', () {
    test('refresh 失败：保留旧数据，不清空、不变成 empty/全屏错误', () async {
      final src = FakeSource()
        ..membersPage = _page([_member('m1')], cursor: 'mc1', hasMore: true);
      final c = _boot(src);
      src.pendingDepartments.first.complete(
        _page([_dept('d1'), _dept('d2')], cursor: 'c1', hasMore: true),
      );
      await _tick();
      expect(c.phase, HumanDirectoryPhase.ready);

      src.membersError = const OrganizationApiException(500, 'members down');
      final f = c.refresh();
      src.pendingDepartments.last.completeError(
        const OrganizationApiException(500, 'dept down'),
      );
      await f;
      src.membersError = null;

      expect(c.departments.items.map((d) => d.id), [
        'd1',
        'd2',
      ], reason: '旧数据保留');
      expect(c.members.items.map((m) => m.userId), ['m1']);
      expect(c.departments.cursor, 'c1', reason: '失败不清空 cursor');
      expect(c.departments.error, isNotNull);
      expect(c.members.error, isNotNull);
      expect(c.refreshing, isFalse);
      expect(c.phase, HumanDirectoryPhase.ready, reason: '有数据不转全屏 error');
      expect(c.pageError, isNull);
    });

    test('refresh 成功：各节原子替换（不清空再填）', () async {
      final src = FakeSource()..membersPage = _page([_member('om')]);
      final c = _boot(src);
      src.pendingDepartments.first.complete(
        _page([_dept('old1'), _dept('old2')], cursor: 'c1', hasMore: true),
      );
      await _tick();

      src.membersPage = _page([_member('nm')]);
      final f = c.refresh();
      src.pendingDepartments.last.complete(_page([_dept('new1')]));
      await f;

      expect(c.departments.items.map((d) => d.id), ['new1']);
      expect(c.departments.cursor, isNull);
      expect(c.departments.endReached, isTrue);
      expect(c.members.items.map((m) => m.userId), ['nm']);
    });

    test('initial 全失败 → 全屏 error；retry（refresh）成功 → ready', () async {
      final src = FakeSource()
        ..membersError = const OrganizationApiException(403, 'forbidden')
        ..meError = const OrganizationApiException(403, 'forbidden');
      final c = _boot(src);
      src.pendingDepartments.first.completeError(
        const OrganizationApiException(403, 'forbidden'),
      );
      await _tick();
      expect(c.phase, HumanDirectoryPhase.error);
      expect(c.pageError, isNotNull);

      src.membersError = null;
      src.meError = null;
      final f = c.refresh();
      src.pendingDepartments.last.complete(_page([_dept('ok')]));
      await f;
      expect(c.phase, HumanDirectoryPhase.ready);
      expect(c.departments.items, hasLength(1));
    });
  });

  group('分页：去重 / 部门成员 cursor 独立 / cursor 400 一次性重试', () {
    test('append 按 EntityId 去重保序', () async {
      final src = FakeSource();
      final c = _boot(src);
      src.pendingDepartments.first.complete(
        _page([_dept('d1'), _dept('d2')], cursor: 'c1', hasMore: true),
      );
      await _tick();

      final f = c.loadMoreDepartments();
      // 第二页含重复 d2 + 新 d3。
      src.pendingDepartments.last.complete(
        _page([_dept('d2'), _dept('d3')], cursor: null),
      );
      await f;
      expect(c.departments.items.map((d) => d.id), ['d1', 'd2', 'd3']);
      expect(c.departments.endReached, isTrue);
    });

    test('部门与成员 cursor 完全独立：成员末页时 loadMoreMembers 不发请求', () async {
      final src = FakeSource()..membersPage = _page([_member('m1')]);
      final c = _boot(src);
      src.pendingDepartments.first.complete(
        _page([_dept('d1')], cursor: 'dept-c1', hasMore: true),
      );
      await _tick();
      final memberCallCount = src.memberCalls.length;

      await c.loadMoreMembers();
      expect(src.memberCalls, hasLength(memberCallCount), reason: '成员已末页，不再请求');

      final f = c.loadMoreDepartments();
      expect(src.deptCalls.last, '$orgA|p=-|c=dept-c1');
      src.pendingDepartments.last.complete(_page([_dept('d2')]));
      await f;
      expect(c.departments.items, hasLength(2));
      expect(src.memberCalls, hasLength(memberCallCount), reason: '部门翻页不影响成员');
    });

    test('cursor 400：清空对应分页并从首页重试一次；再失败展示错误不循环', () async {
      final src = FakeSource()..membersPage = _page([_member('m1')]);
      final c = _boot(src);
      src.pendingDepartments.first.complete(
        _page([_dept('d1')], cursor: 'stale-c', hasMore: true),
      );
      await _tick();
      final memberCallCount = src.memberCalls.length;

      final f = c.loadMoreDepartments(); // 不先 await：重试链在 fake 上挂起
      expect(src.deptCalls.last, '$orgA|p=-|c=stale-c');
      // append 撞 400 invalid_request。
      src.pendingDepartments.last.completeError(
        const OrganizationApiException(400, 'invalid request'),
      );
      await _tick(); // catch → 清空 → 自动首页重试已发出（同 generation）。

      expect(src.deptCalls, hasLength(3), reason: '首页 + 400 append + 自动首页重试');
      expect(src.deptCalls.last, '$orgA|p=-|c=-', reason: '重试从首页开始');
      expect(c.departments.items, isEmpty, reason: '游标失效即清空对应分页');
      expect(c.departments.loading, isTrue);

      // 重试再失败：只展示错误，不再第三次请求。
      src.pendingDepartments.last.completeError(
        const OrganizationApiException(500, 'still down'),
      );
      await f;
      expect(src.deptCalls, hasLength(3), reason: '不循环重试');
      expect(c.departments.error, isNotNull);
      expect(c.departments.loading, isFalse);
      expect(src.memberCalls, hasLength(memberCallCount), reason: '成员节不受牵连');
      expect(c.members.items.map((m) => m.userId), ['m1']);
    });

    test('cursor 400 首页重试成功：数据恢复且一次性标记已消耗', () async {
      final src = FakeSource();
      final c = _boot(src);
      src.pendingDepartments.first.complete(
        _page([_dept('d1')], cursor: 'stale-c', hasMore: true),
      );
      await _tick();

      final f = c.loadMoreDepartments(); // 不先 await：重试链在 fake 上挂起
      src.pendingDepartments.last.completeError(
        const OrganizationApiException(400, 'invalid request'),
      );
      await _tick();
      src.pendingDepartments.last.complete(
        _page([_dept('fresh1'), _dept('fresh2')], cursor: null),
      );
      await f;
      expect(c.departments.items.map((d) => d.id), ['fresh1', 'fresh2']);
      expect(c.departments.error, isNull);
      expect(c.departments.consumedCursorResetRetry, isTrue);
    });
  });

  group('org / path / query 变化重置', () {
    test(
      'openDepartment：path 变化 → generation 递增 + 从首页重建（不复用 cursor）',
      () async {
        final src = FakeSource();
        final c = _boot(src);
        final reqRoot = src.pendingDepartments.first; // 保持挂起
        final gen = c.generation;

        c.openDepartment(deptX);
        expect(c.generation, gen + 1);
        expect(c.departments.items, isEmpty);
        expect(c.departments.cursor, isNull);
        expect(c.departments.error, isNull, reason: '上一层级 error 不复用');
        expect(src.deptCalls.last, '$orgA|p=$deptX|c=-');
        expect(src.memberCalls.last, '$orgA|d=$deptX|c=-');
        final reqChild = src.pendingDepartments.last;

        // 旧层级（企业根）的挂起响应后到：丢弃。
        reqRoot.complete(
          _page([_dept('stale-root')], cursor: 'stale-c', hasMore: true),
        );
        await _tick();
        expect(c.departments.items, isEmpty);
        expect(c.departments.cursor, isNull);

        // 新层级（deptX）响应落地。
        reqChild.complete(_page([_dept('x1')]));
        await _tick();
        expect(c.departments.items.map((d) => d.id), ['x1']);
      },
    );

    test('query 变化：清空三类分页 + 新 generation；>=2 字符才发搜索请求', () async {
      final src = FakeSource()..membersPage = _page([_member('m1')]);
      final c = _boot(src);
      src.pendingDepartments.first.complete(_page([_dept('d1')]));
      await _tick();
      final gen = c.generation;
      final deptCallsAfterBoot = src.deptCalls.length;

      // 1 字符：不搜索、回目录模式（目录从首页重建）。
      c.setQuery('a');
      expect(c.generation, gen + 1);
      expect(c.isSearchMode, isFalse);
      expect(src.searchCalls, isEmpty, reason: 'trim 后 <2 字符不请求');
      expect(
        src.deptCalls,
        hasLength(deptCallsAfterBoot + 1),
        reason: '目录模式重建',
      );
      expect(c.departments.items, isEmpty, reason: '两类目录结果被清空');
      expect(c.members.items, isEmpty);

      // 2 字符：进入搜索模式；目录两节不再请求。
      c.setQuery('ab');
      expect(c.generation, gen + 2);
      expect(c.isSearchMode, isTrue);
      expect(src.searchCalls, hasLength(1));
      expect(src.searchCalls.last, '$orgA|q=ab|c=-');
      src.pendingSearch.last.complete(
        _page(
          [
            HumanDirectorySearchItem(
              type: 'department',
              department: _dept('s1'),
            ),
            HumanDirectorySearchItem(type: 'member', member: _member('s2')),
          ],
          cursor: 'sc1',
          hasMore: true,
        ),
      );
      await _tick();

      // 搜索翻页独立于目录分页。
      final f = c.loadMoreSearch();
      expect(src.searchCalls.last, '$orgA|q=ab|c=sc1');
      src.pendingSearch.last.complete(
        _page([
          HumanDirectorySearchItem(type: 'member', member: _member('s2')),
          HumanDirectorySearchItem(type: 'member', member: _member('s3')),
        ]),
      );
      await f;
      // 混排 append 去重（member:s2 重复）。
      expect(c.search.items, hasLength(3));
      expect(c.search.items.last.member?.userId, 's3');

      // 清空搜索：回目录模式，搜索结果清空。
      c.setQuery('');
      expect(c.isSearchMode, isFalse);
      expect(c.search.items, isEmpty);
      expect(
        src.deptCalls,
        hasLength(deptCallsAfterBoot + 2),
        reason: '目录从首页重建',
      );
    });
  });

  group('Organization 两阶段切换', () {
    test('prepare 失败：完整 rollback（旧 Org/数据保留 + 可重试错误）', () async {
      final src = FakeSource()..membersPage = _page([_member('m1')]);
      final c = _boot(src);
      src.pendingDepartments.first.complete(_page([_dept('d1')]));
      await _tick();
      final gen = c.generation;
      final keyBefore = c.identity!.requestKey;

      var committed = false;
      await c.switchOrganization(
        const Organization(id: orgB, name: 'B 企业'),
        prepare: (target) async => throw Exception('mine 校验失败'),
        commit: (target) async => committed = true,
      );

      expect(committed, isFalse, reason: 'Phase 1 失败绝不提交指针');
      expect(c.identity!.organizationId, orgA);
      expect(c.identity!.requestKey, keyBefore);
      expect(c.generation, gen, reason: 'rollback 不触发重建');
      expect(c.departments.items.map((d) => d.id), ['d1']);
      expect(c.members.items.map((m) => m.userId), ['m1']);
      expect(c.switchError, isNotNull);
      expect(c.switching, isFalse);

      // 可重试：第二次 prepare 成功 → commit + 整体切到 B 根级。
      await c.switchOrganization(
        const Organization(id: orgB, name: 'B 企业'),
        prepare: (target) async {},
        commit: (target) async => committed = true,
      );
      expect(committed, isTrue);
      expect(c.switchError, isNull);
      expect(c.identity!.organizationId, orgB);
      expect(c.identity!.departmentId, isNull, reason: '切后落根级');
      expect(c.generation, gen + 1);
      expect(src.deptCalls.last, '$orgB|p=-|c=-');
      expect(c.departments.items, isEmpty, reason: '上一 Org 列表不复用');
    });

    test('prepare 成功但 shell 加载失败：同样 rollback', () async {
      final src = FakeSource();
      final c = _boot(src);
      src.pendingDepartments.first.complete(_page([_dept('d1')]));
      await _tick();

      var committed = false;
      await c.switchOrganization(
        const Organization(id: orgB, name: 'B 企业'),
        prepare: (target) async =>
            throw Exception('workspace shell load failed'),
        commit: (target) async => committed = true,
      );
      expect(committed, isFalse);
      expect(c.identity!.organizationId, orgA);
      expect(c.departments.items, hasLength(1));
      expect(c.switchError, isNotNull);
    });

    test('commit 失败：rollback 到旧 Org（不 reconfigure、不卡死、可重试）', () async {
      final src = FakeSource()..membersPage = _page([_member('m1')]);
      final c = _boot(src);
      src.pendingDepartments.first.complete(_page([_dept('d1')]));
      await _tick();
      final gen = c.generation;
      final keyBefore = c.identity!.requestKey;

      var commitCalls = 0;
      await c.switchOrganization(
        const Organization(id: orgB, name: 'B 企业'),
        prepare: (target) async {},
        commit: (target) async {
          commitCalls++;
          // 模拟页面补偿后 rethrow（如 CurrentOrganizationStore 写失败）。
          throw Exception('store.set failed');
        },
      );

      expect(commitCalls, 1);
      expect(
        c.identity!.organizationId,
        orgA,
        reason: 'Phase 2 失败绝不 reconfigure 到目标 Org',
      );
      expect(c.identity!.requestKey, keyBefore);
      expect(c.generation, gen, reason: '不触发目录重建');
      expect(c.departments.items.map((d) => d.id), [
        'd1',
      ], reason: '旧 Org 已有数据保留');
      expect(c.members.items.map((m) => m.userId), ['m1']);
      expect(c.switchError, isNotNull);
      expect(c.switching, isFalse, reason: '失败后不卡 switching');
      expect(c.switchTarget, isNull);

      // 可重试：第二次 commit 放行 → 整体切到 B 根级。
      await c.switchOrganization(
        const Organization(id: orgB, name: 'B 企业'),
        prepare: (target) async {},
        commit: (target) async => commitCalls++,
      );
      expect(commitCalls, 2);
      expect(c.switchError, isNull);
      expect(c.identity!.organizationId, orgB);
      expect(c.identity!.departmentId, isNull);
      expect(c.generation, gen + 1);
      expect(src.deptCalls.last, '$orgB|p=-|c=-');
    });

    test('同一 Org 目标：no-op（不进切换流程）', () async {
      final src = FakeSource();
      final c = _boot(src);
      var prepareCalled = false;
      await c.switchOrganization(
        const Organization(id: orgA, name: 'A 企业'),
        prepare: (target) async => prepareCalled = true,
        commit: (target) async {},
      );
      expect(prepareCalled, isFalse);
      expect(c.switchError, isNull);
    });
  });

  group('didUpdateWidget 语义（configure 重入）', () {
    test('orgId 变化 → generation 递增 + 重建；相同身份 no-op', () async {
      final src = FakeSource();
      final c = _boot(src);
      src.pendingDepartments.first.complete(_page([_dept('a1')]));
      await _tick();
      final gen = c.generation;

      // 相同身份：no-op（常驻容器高频 rebuild 不重启加载）。
      c.configure(accountKey: 'u1', organizationId: orgA);
      expect(c.generation, gen);
      expect(src.deptCalls, hasLength(1));

      // 账号变化：身份不同 → 重建。
      c.configure(accountKey: 'u2', organizationId: orgA);
      expect(c.generation, gen + 1);
      expect(c.departments.items, isEmpty);
      expect(src.meCalls.last, orgA);
    });
  });

  group('/me 捷径 best-effort', () {
    test('me 失败不阻塞浏览：phase ready、捷径收起', () async {
      final src = FakeSource()
        ..membersPage = _page([_member('m1')])
        ..meError = const OrganizationApiException(500, 'me down');
      final c = _boot(src);
      src.pendingDepartments.first.complete(_page([_dept('d1')]));
      await _tick();
      expect(c.phase, HumanDirectoryPhase.ready);
      expect(c.myDepartments, isEmpty);
      expect(c.meError, isNotNull);
      expect(c.departments.items, hasLength(1));
    });

    test('me 成功：我的部门捷径可见', () async {
      final src = FakeSource()
        ..meResult = HumanDirectoryMe(
          organizationId: orgA,
          list: [_dept('mine1', count: 3)],
        );
      final c = _boot(src);
      src.pendingDepartments.first.complete(
        _page(<HumanDirectoryDepartment>[]),
      );
      await _tick();
      expect(c.myDepartments.map((d) => d.id), ['mine1']);
      expect(c.myDepartments.first.memberCount, 3);
    });
  });
}
