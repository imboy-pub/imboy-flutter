import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/page/group/group_detail/add_member_page.dart';
import 'package:imboy/page/group/group_detail/add_member_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// 添加成员页 widget 流程测试（group 域 F00 add_member_page）。
///
/// 覆盖（对应 fn:group:add_member_page 判定行；校准注记登记用，
/// 格验收仍以正式设备格为准）：
///   流程A 列表加载与渲染（:001）：好友从本地库渲染，已是成员行带
///         「已是成员」标注。
///   流程B 勾选切换与已选人数（:004/:006）：点非成员行出现「已选」徽标
///         与 "(1)" 提示；再点取消后两者消失。
///   流程C 成员行禁选（:005）：点成员行不产生已选（onTap 置空）。
///   流程D 完成按钮门禁（:008）：未选时完成按钮不可点；选中后可点
///         （Spy joinGroup 拦截真实提交）。
///   流程E 无联系人空态（:010）：清空两表后渲染 NoDataView。
///
/// 数据隔离：sqflite_common_ffi 内存库（migration fixture v32）+
/// SqliteService.setDbForTest。**seed 必须在 setUpAll（普通 async zone）
/// 完成**：testWidgets 的 FakeAsync zone 里 await 真实 IO 会永久挂起
/// （ffi 查询本身是同步调用、Future 经 microtask 完成，故页内
/// loadData 的查询在 pump 间可落定）；流程E 在用例首行清表同为
/// 同步 ffi 操作，FakeAsync 安全。
/// 登录态经 StorageService 注入（flutter_test_config 已消费
/// setMockInitialValues，须直接写已绑定实例）。
/// 网络隔离：contactProvider 由 Spy 覆写（页面 loadData 在本地库为空时
/// 会触发服务端同步）；joinGroup 由 Spy 拦截。
/// 运行：flutter test test/unit_test/page/group/add_member_widget_flow_test.dart

class _HostPage extends StatelessWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('host'));
}

class SpyContactNotifier extends ContactNotifier {
  int loadDataCalls = 0;

  @override
  ContactState build() => ContactState();

  @override
  Future<void> loadData() async {
    loadDataCalls++;
  }
}

class SpyAddMemberNotifier extends AddMemberNotifier {
  SpyAddMemberNotifier({this.joinResult = true});

  final bool joinResult;
  int joinCalls = 0;
  String? lastGroupId;
  List<int> lastMemberIds = <int>[];

  @override
  AddMemberState build() => const AddMemberState();

  @override
  Future<bool> joinGroup(String groupId, items) async {
    joinCalls++;
    lastGroupId = groupId;
    lastMemberIds = items.map((e) => e.peerId).toList();
    return joinResult;
  }
}

const _me = '990001';

Future<void> _insertContact(Database db, int peerId, String nickname) async {
  await db.insert('contact', {
    'user_id': _me,
    'peer_id': peerId,
    'nickname': nickname,
    'avatar': '',
    'gender': 1,
    'account': '$peerId',
    'status': 1,
    'remark': '',
    'tag': '',
    'region': '',
    'sign': '',
    'source': 'test',
    'updated_at': 1790000000000,
    'is_friend': 1,
    'category_id': '',
    'is_from': 1,
    'account_type': 'normal',
  });
}

Future<void> _insertMemberRow(Database db) async {
  await db.insert('group_member', {
    'id': 1,
    'group_id': 7001,
    'user_id': 8001,
    'nickname': '成员甲',
    'avatar': '',
    'sign': '',
    'account': '8001',
    'invite_code': '',
    'alias': '',
    'role': 2,
    'created_at': 1790000000000,
    'updated_at': 1790000000000,
  });
}

Future<void> _resetLoginState() async {
  await StorageService.setMap(Keys.currentUser, {
    'uid': _me,
    'account': '50008',
    'nickname': '当前用户',
    'avatar': '',
    'sign': '',
    'gender': 1,
    'mobile': '13800000001',
    'email': '',
  });
  await StorageService.to.setString(Keys.currentUid, _me);
}

Future<void> _openPage(WidgetTester tester) async {
  await _resetLoginState();

  final spyAdd = SpyAddMemberNotifier();
  final spyContact = SpyContactNotifier();

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          addMemberProvider.overrideWith(() => spyAdd),
          contactProvider.overrideWith(() => spyContact),
        ],
        child: MaterialApp(builder: AppLoading.init(), home: const _HostPage()),
      ),
    ),
  );
  await tester.pump();

  final ctx = tester.element(find.byType(_HostPage));
  unawaited(
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => const AddMemberPage(groupId: '7001'),
      ),
    ),
  );
  // postFrameCallback 触发 loadData（Repo 直读 SQLite）；查询是同步 ffi
  // 调用、Future 经 microtask 完成，pump 即可驱齐。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

CupertinoButton _doneButton(WidgetTester tester) =>
    tester.widget<CupertinoButton>(
      find
          .ancestor(
            of: find.textContaining(t.common.buttonAccomplish),
            matching: find.byType(CupertinoButton),
          )
          .first,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    // 普通 async zone：真实 IO 只允许发生在这里。
    // 登录态必须先于 setDbForTest 注入：setDbForTest 以当时 currentUid 记录
    // _openUid，若此刻未登录（uid 空），页面查询时 uid 漂移会绕过注入句柄、
    // 落到真实用户路径库上查空。
    await _resetLoginState();
    // databaseFactoryFfiNoIsolate：默认 ffi 工厂经 isolate 执行 SQL，isolate
    // 回包是真实 IO，testWidgets 的 FakeAsync zone 永远等不到（页面会永远
    // 转圈）；no-isolate 工厂在当前 isolate 同步执行、Future 经 microtask
    // 完成，pump 可驱齐。seed/自检在普通 zone 同样适用。
    databaseFactory = databaseFactoryFfiNoIsolate;
    db = await openFixtureDatabaseAtVersion(version: 32);
    await _insertContact(db, 8001, '成员甲');
    await _insertContact(db, 8002, '好友乙');
    await _insertMemberRow(db);
    SqliteService.setDbForTest(db);
    // 自检：注入句柄 + 登录态就位后，Repo 查询应能读到 seed 数据
    final friendCheck = await ContactRepo().findFriend();
    // ignore: avoid_print
    print(
      '[seed-check] findFriend=${friendCheck.length} '
      'uid=${UserRepoLocal.to.currentUid}',
    );
  });

  tearDownAll(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  testWidgets('流程A 列表加载与渲染：好友行渲染、成员行带已是成员标注', (tester) async {
    await _openPage(tester);

    expect(find.text('好友乙'), findsOneWidget, reason: '好友应从本地库渲染');
    expect(find.text('成员甲'), findsOneWidget);
    expect(
      find.text(t.chat.alreadyMember),
      findsOneWidget,
      reason: '群成员行应带「已是成员」标注',
    );
  });

  testWidgets('流程B 勾选切换与已选人数提示', (tester) async {
    await _openPage(tester);

    await tester.tap(find.text('好友乙'));
    await tester.pump();
    expect(
      find.text(t.main.selected),
      findsOneWidget,
      reason: '选中后行内应出现「已选」徽标',
    );
    // 行内徽标"已选 (1)" + 完成按钮"完成(1)" 两处都带人数
    expect(
      find.textContaining('(1)'),
      findsExactly(2),
      reason: '已选徽标与完成按钮均应带 (1) 已选人数提示',
    );

    await tester.tap(find.text('好友乙'));
    await tester.pump();
    expect(find.text(t.main.selected), findsNothing, reason: '再点应取消选中');
    expect(find.textContaining('(1)'), findsNothing);
  });

  testWidgets('流程C 成员行禁选：点成员行不产生已选', (tester) async {
    await _openPage(tester);

    await tester.tap(find.text('成员甲'), warnIfMissed: false);
    await tester.pump();
    expect(
      find.text(t.main.selected),
      findsNothing,
      reason: '成员行 onTap 为 null，不应被选中',
    );
    expect(find.textContaining('(1)'), findsNothing);
  });

  testWidgets('流程D 完成按钮门禁：未选禁用、选中可点且提交被拦截', (tester) async {
    final spyAdd = SpyAddMemberNotifier();
    // 本用例需要拿 Spy 断言，单独开 ProviderScope
    await _resetLoginState();
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            addMemberProvider.overrideWith(() => spyAdd),
            contactProvider.overrideWith(SpyContactNotifier.new),
          ],
          child: MaterialApp(
            builder: AppLoading.init(),
            home: const _HostPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    final ctx = tester.element(find.byType(_HostPage));
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => const AddMemberPage(groupId: '7001'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_doneButton(tester).onPressed, isNull, reason: '未选中时完成按钮应禁用');

    await tester.tap(find.text('好友乙'));
    await tester.pump();
    expect(_doneButton(tester).onPressed, isNotNull, reason: '选中后完成按钮应可点');

    await tester.tap(find.textContaining(t.common.buttonAccomplish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(spyAdd.joinCalls, 1, reason: '提交应走 joinGroup（Spy 拦截）');
    expect(spyAdd.lastGroupId, '7001');
  });

  testWidgets('流程F 加载结束转圈消停：终态无活动指示器且列表已渲染', (tester) async {
    await _openPage(tester);

    expect(
      find.byType(CupertinoActivityIndicator),
      findsNothing,
      reason:
          'loadData 完成后转圈应结束（首帧转圈由 setLoading(true) 先于'
          '查询的结构保证；no-isolate 下查询经 microtask 落定，FakeAsync'
          '捕捉不到转圈时序窗，此处断言终态）',
    );
    expect(find.text('好友乙'), findsOneWidget, reason: '加载完成即渲染列表');
  });

  testWidgets('流程G 列表剔除功能入口占位：仅渲染真实好友', (tester) async {
    await _openPage(tester);

    // findFriend 只读 contact 表（is_friend=1、当前 uid），天然不含
    // contactList 内存混入的功能入口占位（朋友圈/找附近的人/AI 助手广场等）。
    expect(find.text('朋友圈'), findsNothing, reason: '功能入口占位不应出现');
    expect(find.textContaining('AI '), findsNothing, reason: '入口占位不应出现');
    expect(find.text('好友乙'), findsOneWidget);
    expect(find.text('成员甲'), findsOneWidget);
  });

  testWidgets('流程H 点左上角关闭退出选人页', (tester) async {
    await _openPage(tester);

    await tester.tap(find.byTooltip(t.common.buttonCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AddMemberPage), findsNothing, reason: '关闭后应退出选人页');
    expect(find.text('host'), findsOneWidget, reason: '应回到宿主页');
  });

  testWidgets('流程I 提交添加成员入群：名单与群号入 Spy，成功后 pop 回宿主', (tester) async {
    final spyAdd = SpyAddMemberNotifier();
    await _resetLoginState();
    // 成员甲(8001)在 group_member 表属成员行不可选（onTap null，流程C 已钉）。
    // 补 seed 非成员好友丙须在 push 之前：页面列表只在 initState 拉一次，
    // 打开后插库不会回填 state。
    await db.insert('contact', {
      'user_id': _me,
      'peer_id': 8003,
      'nickname': '好友丙',
      'avatar': '',
      'gender': 1,
      'account': '8003',
      'status': 1,
      'remark': '',
      'tag': '',
      'region': '',
      'sign': '',
      'source': 'test',
      'updated_at': 1790000000000,
      'is_friend': 1,
      'category_id': '',
      'is_from': 1,
      'account_type': 'normal',
    });
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            addMemberProvider.overrideWith(() => spyAdd),
            contactProvider.overrideWith(SpyContactNotifier.new),
          ],
          child: MaterialApp(
            builder: AppLoading.init(),
            home: const _HostPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    final ctx = tester.element(find.byType(_HostPage));
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => const AddMemberPage(groupId: '7001'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 选中非成员好友乙/丙（8001 是成员行不可选），提交
    await tester.tap(find.text('好友乙'));
    await tester.pump();
    await tester.tap(find.text('好友丙'));
    await tester.pump();
    await tester.tap(find.textContaining(t.common.buttonAccomplish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(spyAdd.joinCalls, 1, reason: '提交应走 joinGroup');
    expect(spyAdd.lastGroupId, '7001', reason: '群号应随提交传入');
    expect(spyAdd.lastMemberIds.toSet(), {
      8002,
      8003,
    }, reason: '选中名单应完整入参（成员行 8001 不可选）');
    // pop 转场 300ms：多 pump 数帧等动画走完再断言离树
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(AddMemberPage),
      findsNothing,
      reason: 'joinGroup 成功后应 pop 回宿主页',
    );
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('流程E 无联系人空态', (tester) async {
    // 同步 ffi 清表：FakeAsync 内 microtask 可落定
    await db.delete('contact');
    await db.delete('group_member');

    await _openPage(tester);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(t.common.noData), findsOneWidget, reason: '空库应渲染「暂无数据」空态');
  });
}
