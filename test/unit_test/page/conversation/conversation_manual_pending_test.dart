/// W09.a（channel-group-ux-v2.2 §6.7/J17.c/J28.a）：人工待处理独立于真实未读。
///
/// J17.c 向量：标已读与设待处理分别——水位单调；人工标记不写
/// unread=1（不落库不改真实未读）；彼此不清除（标已读不清 pending）；
/// 显式目标 true/false；失败不假成功且目标不取反（J16.b 同款口径）。
/// J28.a：启动/恢复同步按当前账号范围整体替换；失败保留现状不清除；
/// 会话代次防护丢弃迟到响应。零真实网络：ConversationApi 注入 fake；
/// SQLite 用合成 fixture。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _FakeConversationApi extends ConversationApi {
  bool manualPendingResult = true;

  /// 冲突脚本：非 null 时返回 conflict（currentValue/currentVersion）。
  ({bool currentValue, int currentVersion})? conflictScript;
  final List<({String uk3, bool value, int? expectedVersion})>
  manualPendingCalls = [];

  /// manual_pending_list 脚本：null=请求失败/结果未知。
  List<Map<String, dynamic>>? manualPendingListScript;
  bool manualPendingListThrows = false;

  @override
  Future<ManualPendingWrite?> setManualPending({
    required String uk3,
    required bool value,
    int? expectedVersion,
  }) async {
    manualPendingCalls.add((
      uk3: uk3,
      value: value,
      expectedVersion: expectedVersion,
    ));
    if (!manualPendingResult) return null;
    final conflict = conflictScript;
    if (conflict != null) {
      return ManualPendingWrite.conflict(
        currentValue: conflict.currentValue,
        currentVersion: conflict.currentVersion,
      );
    }
    return ManualPendingWrite.applied(value: value, version: 1);
  }

  @override
  Future<List<Map<String, dynamic>>?> manualPendingList() async {
    if (manualPendingListThrows) throw Exception('synthetic-network');
    return manualPendingListScript;
  }
}

class _TestConversationNotifier extends ConversationNotifier {
  _TestConversationNotifier({required ConversationApi api})
    : super(conversationApi: api);
}

ConversationModel _model({int peerId = 2002, int unread = 0}) =>
    ConversationModel(
      id: 0,
      type: 'C2C',
      peerId: peerId,
      avatar: '',
      title: 'peer-$peerId',
      subtitle: '',
      msgType: 'text',
      unreadNum: unread,
      lastTime: DateTime.now().millisecondsSinceEpoch,
    );

ProviderContainer _container(ConversationApi api) {
  final container = ProviderContainer(
    overrides: [
      conversationProvider.overrideWith(
        () => _TestConversationNotifier(api: api),
      ),
    ],
  );
  return container;
}

Future<void> _injectUid() async {
  // 数字 uid：uk3 生成器按 C2C_小id_大id 数值排序，与后端行键一致。
  await StorageService.to.setString(Keys.currentUid, '1001');
  return;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  test('J17.c：设待处理不写 unreadNum、不改真实未读；显式目标到达服务端', () async {
    final api = _FakeConversationApi();
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model(unread: 3);
    final r = await notifier.setManualPending(model, true);

    expect(r.applied, isTrue);
    expect(api.manualPendingCalls.single.value, isTrue);
    // 本地 pending 投影置位。
    expect(
      container.read(conversationProvider).manualPending[model.uk3],
      isTrue,
    );
    // 真实未读零影响：不落库、不改内存 unreadNum。
    final rows = await db.query(
      ConversationRepo.tableName,
      where: '${ConversationRepo.peerId} = ?',
      whereArgs: [2002],
    );
    expect(rows, isEmpty, reason: '人工标记不得写会话行（unread=1 hack 移除）');
    expect(model.unreadNum, 3, reason: '水位单调：人工标记不改真实未读');
  });

  test('J17.c：标已读不清除人工待处理（彼此不清除）', () async {
    final api = _FakeConversationApi();
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model(unread: 0);
    expect((await notifier.setManualPending(model, true)).applied, isTrue);
    expect(
      container.read(conversationProvider).manualPending[model.uk3],
      isTrue,
    );

    // 标已读动作路径（清 remind/未读）不触碰 manualPending 状态。
    await notifier.setConversationRemind(model, 0);
    expect(
      container.read(conversationProvider).manualPending[model.uk3],
      isTrue,
      reason: '清未读后人工待处理独立保留（§5.2）',
    );
  });

  test('J17.c：显式取消（target=false）置服务端并清本地标记', () async {
    final api = _FakeConversationApi();
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model();
    expect((await notifier.setManualPending(model, true)).applied, isTrue);
    final r = await notifier.setManualPending(model, false);

    expect(r.applied, isTrue);
    expect(r.conflict, isFalse);
    expect(api.manualPendingCalls.last.value, isFalse);
    expect(
      container.read(conversationProvider).manualPending[model.uk3],
      isFalse,
      reason: '显式 false：本地标记跟随服务端目标值',
    );
  });

  test('J17.d：冲突回读已达目标 → 成功；未达目标 → 冲突可见并展示最新值', () async {
    final api = _FakeConversationApi()
      ..conflictScript = (currentValue: true, currentVersion: 4);
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model();
    // 服务端已是 true（desired 达成）→ 冲突回读后判成功。
    final r1 = await notifier.setManualPending(model, true);
    expect(r1.applied, isTrue);
    expect(r1.conflict, isTrue);
    expect(
      container.read(conversationProvider).manualPending[model.uk3],
      isTrue,
    );
    // 首写即带 expected_version（本地无版本 → 不带键/为 null）。
    expect(api.manualPendingCalls.single.expectedVersion, isNull);

    // 服务端值与 desired 不一致 → 冲突可见，本地展示服务端最新值，
    // 不自动取反或无限覆盖（J17.d）。
    final api2 = _FakeConversationApi()
      ..conflictScript = (currentValue: false, currentVersion: 7);
    final container2 = _container(api2);
    addTearDown(container2.dispose);
    final notifier2 = container2.read(conversationProvider.notifier);
    final r2 = await notifier2.setManualPending(_model(), true);
    expect(r2.applied, isFalse);
    expect(r2.conflict, isTrue);
    expect(r2.serverValue, isFalse);
    expect(
      container2.read(conversationProvider).manualPending[model.uk3],
      isFalse,
      reason: '冲突未达目标：展示服务端最新值（false），不假成功',
    );
  });

  test('J16.b 口径：失败不假成功、目标不取反、状态不变', () async {
    final api = _FakeConversationApi()..manualPendingResult = false;
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model();
    final r = await notifier.setManualPending(model, true);
    expect(r.applied, isFalse);
    expect(r.conflict, isFalse, reason: '请求失败≠冲突，调用方按失败呈现');
    expect(
      container.read(conversationProvider).manualPending.containsKey(model.uk3),
      isFalse,
      reason: '失败不得写本地状态（不假成功）',
    );
    // 服务端仍收到显式原目标（超时重试发原目标，非 toggle）。
    expect(api.manualPendingCalls.single.value, isTrue);
  });

  test('J28.a：同步成功按账号范围整体替换标记与版本；下次写带 expected_version', () async {
    await _injectUid();
    final api = _FakeConversationApi()
      ..manualPendingListScript = [
        {'uk3': 'C2C_1001_2002', 'value': true, 'version': 4},
        {'uk3': 'C2G_995011_8006', 'value': false, 'version': 2},
      ];
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    // 预置一个陈旧本地标记：同步必须整体替换（服务端权威）。
    final stale = _model(peerId: 3003);
    container.read(conversationProvider.notifier).state = container
        .read(conversationProvider)
        .copyWith(manualPending: {stale.uk3: true});

    await notifier.syncManualPendingFromServer();

    final st = container.read(conversationProvider).manualPending;
    expect(st['C2C_1001_2002'], isTrue);
    expect(st['C2G_995011_8006'], isFalse);
    expect(st.containsKey(stale.uk3), isFalse, reason: '服务端权威：整体替换不清残留');

    // 版本缓存随同步播种：下次写携带 expected_version=4。
    final model = _model(peerId: 2002);
    await notifier.setManualPending(model, false);
    expect(api.manualPendingCalls.single.expectedVersion, 4);
  });

  test('J28.a：同步失败/结果未知保留本地状态不清除（不误擦）', () async {
    await _injectUid();
    final api = _FakeConversationApi()..manualPendingListScript = null;
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model();
    expect((await notifier.setManualPending(model, true)).applied, isTrue);
    final before = container.read(conversationProvider).manualPending;

    await notifier.syncManualPendingFromServer();
    expect(
      container.read(conversationProvider).manualPending,
      before,
      reason: '失败/结果未知：保留现状，下次启动或重试再同步',
    );

    // 请求抛异常同口径。
    final api2 = _FakeConversationApi()..manualPendingListThrows = true;
    final container2 = _container(api2);
    addTearDown(container2.dispose);
    await container2
        .read(conversationProvider.notifier)
        .syncManualPendingFromServer();
    expect(container2.read(conversationProvider).manualPending, isEmpty);
  });

  test('J28.a：同步空列表=服务端真实无标记 → 清除本地标记', () async {
    await _injectUid();
    final api = _FakeConversationApi()
      ..manualPendingListScript = const <Map<String, dynamic>>[];
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model();
    expect((await notifier.setManualPending(model, true)).applied, isTrue);
    await notifier.syncManualPendingFromServer();
    expect(
      container.read(conversationProvider).manualPending.containsKey(model.uk3),
      isFalse,
      reason: '服务端确认空集合：本地标记清除（区别于失败保留）',
    );
  });

  testWidgets('可视标记：pending 渲染旗标（带读屏标签），取消后不渲染', (tester) async {
    final api = _FakeConversationApi();
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);
    final model = _model();
    expect((await notifier.setManualPending(model, true)).applied, isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ConversationItem(model: model, onTapAvatar: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(CupertinoIcons.flag_fill), findsOneWidget);

    // 显式取消 → 旗标消失（J17.c 显式 false 可达）。
    expect((await notifier.setManualPending(model, false)).applied, isTrue);
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.flag_fill), findsNothing);

    // 冲刷 _loadPeerAccountType 等异步收尾；fake 时钟需推进一次以触发
    // Riverpod autoDispose 的 0 时长 dispose 定时器（runAsync 不推进）。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  });
}
