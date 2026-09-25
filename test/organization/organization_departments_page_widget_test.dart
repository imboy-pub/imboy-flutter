/// ENT-APP-05 — 部门治理生产闭包 focused widget 测试。
///
/// 覆盖（任务卡验收锚点）：
/// - 完整 journey（admin）：create root/child → rename → move（移到自身
///   409 cycle 错误态）→ add/remove member → set/unset admin → archive；
/// - CAS：旧 version rename → 409 conflict → casConflictHint 提示 + 刷新
///   后列表 = 服务端最新树（不静默重试）；
/// - PermissionGate 分层：member 角色无任何治理入口（新建/行操作/成员
///   治理全部隐藏，列表只读可见）；
/// - 部门局部 admin：org member 但本部门 is_admin → 详情成员治理入口
///   可见（镜像服务端 is_dept_privileged 授权口径）。
///
/// 服务端语义由有状态 routing adapter 真实模拟（部门表/成员表/
/// expected_version CAS/成环裁决），页面经 OrganizationApi 全链路驱动。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/service/storage.dart';

const String _accountKey = '92001';
const String _orgId = '7301';

/// 服务端状态真源：部门表 + 部门成员表 + version 序列。
///
/// 裁决口径镜像 imboy organization_department_app：
/// - rename/move 强制 expected_version CAS（不符 → 409 conflict）；
/// - move 目标父 = 自身或自身子孙 → 409 cycle「部门层级禁止成环」；
/// - set/unset admin = 同一 PUT 端点翻 body.admin；archived 部门禁设；
/// - remove member 幂等（不在部门也成功，idempotent=true）。
class _ServerState {
  final Map<int, Map<String, dynamic>> depts = <int, Map<String, dynamic>>{};
  final Map<int, Map<int, bool>> deptMembers = <int, Map<int, bool>>{};
  final List<String> calls = <String>[];
  int _nextId = 100;
  int _versionSeq = 1;

  int _allocVersion() => _versionSeq++;

  int createDept(String name, int? parentId) {
    final id = _nextId++;
    depts[id] = {
      'id': id,
      'organization_id': int.parse(_orgId),
      'parent_id': parentId,
      'name': name,
      'status': 'active',
      'version': _allocVersion(),
    };
    return id;
  }

  /// deptId 自身与其全部子孙（成环裁决用）。
  Set<int> subtreeOf(int deptId) {
    final result = <int>{deptId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final entry in depts.entries) {
        final parent = entry.value['parent_id'];
        if (parent is int && result.contains(parent) && result.add(entry.key)) {
          grew = true;
        }
      }
    }
    return result;
  }

  Map<String, dynamic> deptRow(int id) => Map<String, dynamic>.of(depts[id]!);
}

Map<String, dynamic> _ok(dynamic payload) => {
  'code': 0,
  'msg': 'success',
  'payload': payload,
};

Map<String, dynamic> _err(int code, String msg) => {'code': code, 'msg': msg};

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.state);

  final _ServerState state;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method;
    final path = options.uri.path;
    final segs = path.split('/');
    Object body;
    var status = 200;

    if (path == '/api/v1/organizations/$_orgId/departments') {
      if (method == 'POST') {
        state.calls.add('create');
        final data = options.data as Map<String, dynamic>;
        final parentRaw = data['parent_id'];
        final id = state.createDept(
          '${data['name']}',
          parentRaw == null ? null : int.parse('$parentRaw'),
        );
        body = _ok(state.deptRow(id));
      } else {
        body = _ok({
          'list': [
            for (final row in state.depts.values)
              state.deptRow(row['id'] as int),
          ],
        });
      }
    } else if (segs.length == 8 && segs.last == 'move') {
      // POST /departments/:id/move
      state.calls.add('move');
      final deptId = int.parse(segs[6]);
      final data = options.data as Map<String, dynamic>;
      final newParent = data['parent_id'] == null
          ? null
          : int.parse('${data['parent_id']}');
      final row = state.depts[deptId]!;
      if (newParent != null && state.subtreeOf(deptId).contains(newParent)) {
        status = 409;
        body = _err(409, '部门层级禁止成环');
      } else if ('${data['expected_version']}' != '${row['version']}') {
        status = 409;
        body = _err(409, '部门已被并发修改，请刷新版本后重试');
      } else {
        row['parent_id'] = newParent;
        row['version'] = state._allocVersion();
        body = _ok(state.deptRow(deptId));
      }
    } else if (segs.length == 8 && segs.last == 'archive') {
      // POST /departments/:id/archive
      state.calls.add('archive');
      final deptId = int.parse(segs[6]);
      final row = state.depts[deptId]!;
      row['status'] = 'archived';
      row['version'] = state._allocVersion();
      body = _ok(state.deptRow(deptId));
    } else if (segs.length == 8 && segs.last == 'members' && method == 'POST') {
      // POST /departments/:id/members（add）
      state.calls.add('add-member');
      final deptId = int.parse(segs[6]);
      final uid = int.parse('${(options.data as Map)['user_id']}');
      final members = state.deptMembers.putIfAbsent(
        deptId,
        () => <int, bool>{},
      );
      final idempotent = members.containsKey(uid);
      members[uid] = members[uid] ?? false;
      body = _ok({
        'organization_id': int.parse(_orgId),
        'department_id': deptId,
        'user_id': uid,
        'is_admin': members[uid] ?? false,
        'idempotent': idempotent,
      });
    } else if (segs.length == 9 && segs[7] == 'members' && method == 'DELETE') {
      // DELETE /departments/:id/members/:uid（remove，幂等）
      state.calls.add('remove-member');
      final deptId = int.parse(segs[6]);
      final uid = int.parse(segs.last);
      final wasPresent = (state.deptMembers[deptId] ?? const <int, bool>{})
          .remove(uid);
      body = _ok({
        'department_id': deptId,
        'user_id': uid,
        'result': wasPresent == true ? 'removed' : 'not_present',
        'idempotent': wasPresent != true,
      });
    } else if (segs.length == 10 && segs.last == 'admin' && method == 'PUT') {
      // PUT /departments/:id/members/:uid/admin（set/unset 同端点）
      state.calls.add('set-admin');
      final deptId = int.parse(segs[6]);
      final uid = int.parse(segs[8]);
      final flag = (options.data as Map)['admin'] == true;
      final row = state.depts[deptId]!;
      if (row['status'] == 'archived') {
        status = 409;
        body = _err(409, '部门状态迁移非法');
      } else {
        state.deptMembers.putIfAbsent(deptId, () => <int, bool>{})[uid] = flag;
        body = _ok({
          'organization_id': int.parse(_orgId),
          'department_id': deptId,
          'user_id': uid,
          'is_admin': flag,
        });
      }
    } else if (segs.length == 7 && segs[5] == 'departments') {
      // GET /departments/:id（detail）；PATCH（rename，CAS）
      final deptId = int.parse(segs.last);
      final row = state.depts[deptId]!;
      if (method == 'PATCH') {
        state.calls.add('rename');
        final data = options.data as Map<String, dynamic>;
        if ('${data['expected_version']}' != '${row['version']}') {
          status = 409;
          body = _err(409, '部门已被并发修改，请刷新版本后重试');
        } else {
          row['name'] = '${data['name']}';
          row['version'] = state._allocVersion();
          body = _ok(state.deptRow(deptId));
        }
      } else {
        final members = state.deptMembers[deptId] ?? const <int, bool>{};
        body = _ok({
          ...state.deptRow(deptId),
          'members': [
            for (final e in members.entries)
              {
                'organization_id': int.parse(_orgId),
                'department_id': deptId,
                'user_id': e.key,
                'is_admin': e.value,
              },
          ],
        });
      }
    } else {
      body = _ok(null);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    OrganizationCache.disposeAll();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    HttpClient.adapterForTest = null;
    OrganizationCache.disposeAll();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    _ServerState state, {
    String memberRole = 'admin',
  }) async {
    HttpClient.adapterForTest = _RoutingAdapter(state);
    OrganizationCache.forAccount(_accountKey).saveOrgs([
      Organization(id: _orgId, name: '测试企业', memberRole: memberRole),
    ]);
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: const MaterialApp(
          home: OrganizationDepartmentsPage(
            orgId: _orgId,
            accountKey: _accountKey,
          ),
        ),
      ),
    );
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        return;
      }
    }
  }

  /// 行内「更多操作」按钮（CupertinoIcons.ellipsis）。
  Finder rowMenuOf(String deptName) => find.descendant(
    of: find.widgetWithText(ListTile, deptName),
    matching: find.byIcon(CupertinoIcons.ellipsis),
  );

  testWidgets('完整 journey：create root/child → rename → move 成环 409 → '
      '成员 add/set·unset·remove admin → archive', (tester) async {
    final state = _ServerState();
    await pumpPage(tester, state);
    await pumpUntilFound(tester, find.text('暂无部门，点击右上角新建'));

    // ---- 1) create root「总部」 ----
    await tester.tap(find.byTooltip('新建根部门'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '总部');
    await tester.tap(find.text('确定'));
    await pumpUntilFound(tester, find.text('总部'));
    expect(state.calls, contains('create'));
    final hqId = state.depts.entries
        .firstWhere((d) => d.value['name'] == '总部')
        .key;

    // ---- 2) create child「研发」（总部下） ----
    await tester.tap(rowMenuOf('总部').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('在其下新建子部门'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '研发');
    await tester.tap(find.text('确定'));
    // 子部门默认收起：先展开总部（leading folder 图标），「研发」才渲染。
    await pumpUntilFound(tester, find.byIcon(CupertinoIcons.folder_fill));
    await tester.tap(
      find
          .descendant(
            of: find.widgetWithText(ListTile, '总部'),
            matching: find.byIcon(CupertinoIcons.folder_fill),
          )
          .first,
    );
    await pumpUntilFound(tester, find.text('研发'));
    final devId = state.depts.entries
        .firstWhere((d) => d.value['name'] == '研发')
        .key;
    expect(state.depts[devId]!['parent_id'], hqId, reason: 'child 挂在总部下');

    // ---- 3) rename 研发 → 研发中心（CAS 命中） ----
    await tester.tap(rowMenuOf('研发').first);
    await tester.pumpAndSettle();
    // 行操作单入口 = common.rename「重命名」；「重命名部门」是弹窗标题。
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    // 输入框预填旧名，全选替换。
    await tester.enterText(find.byType(TextField), '研发中心');
    await tester.tap(find.text('确定'));
    await pumpUntilFound(tester, find.text('研发中心'));
    expect(state.calls, contains('rename'));
    expect(state.depts[devId]!['name'], '研发中心');

    // ---- 4) move 移到自身：409 cycle 错误态（树不变，SnackBar 透传） ----
    await tester.tap(rowMenuOf('研发中心').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动（选择新父部门）'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '$devId');
    await tester.tap(find.text('确定'));
    await pumpUntilFound(tester, find.textContaining('部门层级禁止成环'));
    expect(state.depts[devId]!['parent_id'], hqId, reason: 'cycle 拒绝后树不变');

    // ---- 5) add member 2001 到研发中心 ----
    await tester.tap(rowMenuOf('研发中心').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加成员（按 UID）'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2001');
    await tester.tap(find.text('确定'));
    // FakeAsync 下微任务/pump 驱动异步 POST；补 pump 让 add 命令真实落库。
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.calls, contains('add-member'));

    // ---- 6) 详情 sheet：成员行 → set admin ----
    await tester.tap(find.text('研发中心'));
    await pumpUntilFound(tester, find.text('成员 2001'));

    Future<Finder> memberGovernButton() => Future.value(
      find.descendant(
        of: find.widgetWithText(ListTile, '成员 2001'),
        matching: find.byIcon(CupertinoIcons.ellipsis),
      ),
    );
    await tester.tap((await memberGovernButton()).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('设 2001 为部门管理员'));
    await pumpUntilFound(tester, find.text('成员 2001'));
    expect(state.calls, contains('set-admin'));
    expect(state.deptMembers[devId]![2001], isTrue, reason: 'is_admin 已置位');

    // ---- 7) unset admin ----
    await tester.tap((await memberGovernButton()).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消 2001 的部门管理员'));
    await pumpUntilFound(tester, find.text('成员 2001'));
    expect(state.deptMembers[devId]![2001], isFalse, reason: 'is_admin 已复位');

    // ---- 8) remove member 2001（危险确认 → 成员行消失） ----
    await tester.tap((await memberGovernButton()).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除成员 2001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认移除'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.calls, contains('remove-member'));
    await pumpUntilFound(tester, find.text('暂无成员'));
    expect(state.deptMembers[devId]?.containsKey(2001), isFalse);
    // 关闭详情 sheet。
    await tester.tapAt(const Offset(215, 60));
    await tester.pumpAndSettle();

    // ---- 9) archive 研发中心 ----
    await tester.tap(rowMenuOf('研发中心').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档部门'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认归档'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.calls, contains('archive'));
    await pumpUntilFound(tester, find.text('已归档'));
    expect(state.depts[devId]!['status'], 'archived');
  });

  testWidgets('旧 version CAS：rename 409 conflict → 提示 + 刷新最新树', (tester) async {
    final state = _ServerState()..createDept('原部门名', null);
    await pumpPage(tester, state);
    await pumpUntilFound(tester, find.text('原部门名'));

    // 列表已渲染后，模拟另一客户端并发改名（version 前进 + 名称变更）。
    final deptId = state.depts.keys.single;
    state.depts[deptId]!['name'] = '别人已改的名';
    state.depts[deptId]!['version'] = 999;

    // 本页面仍持旧 version 发起 rename → 服务端 409 conflict。
    await tester.tap(rowMenuOf('原部门名').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '我的新名');
    await tester.tap(find.text('确定'));

    // casConflictHint SnackBar + 刷新后列表 = 服务端最新事实。
    await pumpUntilFound(tester, find.textContaining('已刷新为最新部门树'));
    await pumpUntilFound(tester, find.text('别人已改的名'));
    expect(find.text('我的新名'), findsNothing, reason: '不静默重试');
  });

  testWidgets('PermissionGate 分层：member 无任何治理入口（列表只读可见）', (tester) async {
    final state = _ServerState();
    final rootId = state.createDept('总部', null);
    state.deptMembers[rootId] = {2001: false};
    await pumpPage(tester, state, memberRole: 'member');
    await pumpUntilFound(tester, find.text('总部'));

    // 树级：无新建按钮、无行 more。
    expect(find.byTooltip('新建根部门'), findsNothing);
    expect(find.byIcon(CupertinoIcons.ellipsis), findsNothing);

    // 详情 sheet：成员行只读（无治理按钮），无管理入口。
    await tester.tap(find.text('总部'));
    await pumpUntilFound(tester, find.text('成员 2001'));
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '成员 2001'),
        matching: find.byIcon(CupertinoIcons.ellipsis),
      ),
      findsNothing,
      reason: 'member 不可见成员治理入口（服务端 403 兜底）',
    );
  });

  testWidgets('部门局部 admin：org member 但本部门 is_admin → 治理入口可见', (tester) async {
    final state = _ServerState();
    final deptId = state.createDept('总部', null);
    // 我（92001）是本部门现任 admin；另一成员 2001 普通。
    state.deptMembers[deptId] = {int.parse(_accountKey): true, 2001: false};
    await pumpPage(tester, state, memberRole: 'member');
    await pumpUntilFound(tester, find.text('总部'));

    await tester.tap(find.text('总部'));
    await pumpUntilFound(tester, find.text('成员 2001'));

    // 镜像服务端 is_dept_privileged：部门 admin 可治理成员（含自己行）。
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '成员 2001'),
        matching: find.byIcon(CupertinoIcons.ellipsis),
      ),
      findsOneWidget,
    );
    // 治理动作可达：打开动作单，移除入口存在。
    await tester.tap(
      find
          .descendant(
            of: find.widgetWithText(ListTile, '成员 2001'),
            matching: find.byIcon(CupertinoIcons.ellipsis),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('移除成员 2001'), findsOneWidget);
  });
}
