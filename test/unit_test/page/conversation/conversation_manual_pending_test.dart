/// W09.a（channel-group-ux-v2.2 §6.7/J17.c）：人工待处理独立于真实未读。
///
/// J17.c 向量：标已读与设待处理分别——水位单调；人工标记不写
/// unread=1（不落库不改真实未读）；彼此不清除（标已读不清 pending）；
/// 显式目标 true/false；失败不假成功且目标不取反（J16.b 同款口径）。
/// 零真实网络：ConversationApi 注入 fake；SQLite 用合成 fixture。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
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
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          () => _TestConversationNotifier(api: api),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model(unread: 3);
    final ok = await notifier.setManualPending(model, true);

    expect(ok, isTrue);
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
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          () => _TestConversationNotifier(api: api),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model(unread: 0);
    expect(await notifier.setManualPending(model, true), isTrue);
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

  test('J17.d：冲突回读已达目标 → 成功；未达目标 → 冲突可见状态不变', () async {
    final api = _FakeConversationApi()
      ..conflictScript = (currentValue: true, currentVersion: 4);
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          () => _TestConversationNotifier(api: api),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model();
    // 服务端已是 true（desired 达成）→ 冲突回读后判成功。
    expect(await notifier.setManualPending(model, true), isTrue);
    expect(
      container.read(conversationProvider).manualPending[model.uk3],
      isTrue,
    );
    // 首写即带 expected_version（本地无版本 → 不带键/为 null）。
    expect(api.manualPendingCalls.single.expectedVersion, isNull);

    // 服务端值与 desired 不一致 → 冲突可见（false），本地不变、不取反。
    final api2 = _FakeConversationApi()
      ..conflictScript = (currentValue: false, currentVersion: 7);
    final container2 = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          () => _TestConversationNotifier(api: api2),
        ),
      ],
    );
    addTearDown(container2.dispose);
    final notifier2 = container2.read(conversationProvider.notifier);
    expect(await notifier2.setManualPending(_model(), true), isFalse);
    expect(
      container2
          .read(conversationProvider)
          .manualPending
          .containsKey(model.uk3),
      isFalse,
      reason: '冲突未达目标：不假成功、desired 不落本地',
    );
  });

  test('J16.b 口径：失败不假成功、目标不取反、状态不变', () async {
    final api = _FakeConversationApi()..manualPendingResult = false;
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          () => _TestConversationNotifier(api: api),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(conversationProvider.notifier);

    final model = _model();
    expect(await notifier.setManualPending(model, true), isFalse);
    expect(
      container.read(conversationProvider).manualPending.containsKey(model.uk3),
      isFalse,
      reason: '失败不得写本地状态（不假成功）',
    );
    // 服务端仍收到显式原目标（超时重试发原目标，非 toggle）。
    expect(api.manualPendingCalls.single.value, isTrue);
  });
}
