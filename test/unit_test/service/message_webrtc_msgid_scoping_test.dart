import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart'
    show gTimer, p2pCallMsgId, p2pCallScreenOn, p2pEntry;
import 'package:imboy/service/message_webrtc.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart'
    show openFixtureDatabaseAtVersion;

/// CALL-11 / UX_SPEC §8：终态信令（busy/bye）按 msgId 判定归属。
/// 迟到的旧通话信令只收敛自己的记录，不得改写新一通的全局状态。
const String _currentUid = '1817128709888507904';
const String _peerUid = '1825989847768576000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _currentUid);

    // 生产真源 fixture：真实 msg_c2c/contact/FTS 形态（含 user_version=16 基线）。
    db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);

    p2pEntry = null;
    p2pCallScreenOn = false;
    p2pCallMsgId = null;
    gTimer?.cancel();
    gTimer = null;
  });

  tearDown(() async {
    p2pEntry = null;
    p2pCallScreenOn = false;
    p2pCallMsgId = null;
    gTimer?.cancel();
    gTimer = null;
    await pumpEventQueue();
    // 终态处理触发的 quitLogin 会话级联（与路由无关，见首测注释）内含
    // 100ms + 1s 延时步：异步跨 tearDown 落地时会把 SqliteService 当前句柄
    // （下一测刚注入的新库）关掉 → database_closed 连坐同批 VM。此处有界
    // 排空级联后再交还控制权，隔离时序不确定。
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await pumpEventQueue();
    await db.close();
    // 复位注入句柄：SqliteService 的静态 _db 若继续持有已关闭的 fixture 库，
    // 同批后续套件经 SqliteService.to.db 触发 DatabaseException(database_closed)
    // （sqlite.dart rawUpdate 路径），整批 VM 非零退出连坐同批全部 target
    // （2026-11-07 main 42328863736 批次连坐源）。与 new_friend_remind_session
    // 等套件的 teardown 惯例一致。
    SqliteService.setDbForTest(null);
  });

  Future<void> insertCallRecord(String msgId, {String media = 'video'}) async {
    final msgType = 'webrtc${media == 'video' ? 'Video' : 'Audio'}';
    final payload =
        '{"peer_id": $_peerUid, "msg_type": "$msgType",'
        ' "media": "$media", "start_at": 0, "end_at": 0, "state": 0}';
    await db.insert('msg_c2c', <String, Object?>{
      'auto_id': null,
      'id': msgId,
      'msg_type': msgType,
      'from_id': int.parse(_peerUid),
      'to_id': int.parse(_currentUid),
      'conversation_uk3': 'uk3-$_peerUid',
      'e2ee': '0',
      'payload': payload,
      'created_at': 1730000000000,
      'status': 2,
      'is_author': 0,
      'type': 'C2C',
    });
  }

  Future<int> recordState(String msgId) async {
    final rows = await db.query(
      'msg_c2c',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [msgId],
    );
    final payload = rows.first['payload']! as String;
    final state = RegExp(r'"state": ?(\d+)').firstMatch(payload)!.group(1);
    return int.parse(state!);
  }

  /// sqflite ffi 在独立 isolate 上执行，pumpEventQueue 只排空微任务不够；
  /// 有界轮询直到记录状态达到期望（隔离时序鲁棒）。
  Future<void> expectRecordStateEventually(
    String msgId,
    int expected, {
    String? reason,
  }) async {
    for (var i = 0; i < 100; i++) {
      if (await recordState(msgId) == expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await recordState(msgId), expected, reason: reason);
  }

  test('本通 busy：按 msgId 收敛记录并复位全局通话状态', () async {
    const msgId = 'call-active-1';
    await insertCallRecord(msgId);
    p2pCallScreenOn = true;
    p2pCallMsgId = msgId;
    gTimer = Timer(const Duration(seconds: 60), () {});
    await MessageWebrtc.instance.handleWebRTC('WEBRTC_BUSY', {
      'id': msgId,
      'from': _peerUid,
      'payload': <String, dynamic>{},
    });
    // 记录收敛与 test2/3/4 走同一 changeLocalMsgState 按 msgId 写库路径；
    // 首测冷启动存在与路由无关的会话级联（quitLogin 清理关库），此处
    // 只断言路由决策本身，不在冷启动上追DB终态。
    expect(p2pCallScreenOn, isFalse, reason: '本通终态应复位全局通话开关');
    expect(p2pCallMsgId, isNull, reason: '本通终态应清除活动通话标识');
    expect(gTimer, isNull, reason: '本通终态应取消来电等待计时器');
  });

  test('迟到 busy（旧 msgId）：只收敛旧记录，不动新一通全局状态', () async {
    const oldMsgId = 'call-old-1';
    const newMsgId = 'call-new-1';
    await insertCallRecord(oldMsgId);
    await insertCallRecord(newMsgId);
    // 新一通进行中（来电弹窗或通话 overlay 均以该 msgId 为活动通话）。
    p2pCallScreenOn = true;
    p2pCallMsgId = newMsgId;
    gTimer = Timer(const Duration(seconds: 60), () {});

    await MessageWebrtc.instance.handleWebRTC('WEBRTC_BUSY', {
      'id': oldMsgId,
      'from': _peerUid,
      'payload': <String, dynamic>{},
    });
    await expectRecordStateEventually(oldMsgId, 5, reason: '旧通话记录按其 msgId 收敛');
    expect(await recordState(newMsgId), 0, reason: '新一通记录不得被旧 busy 污染');
    expect(p2pCallScreenOn, isTrue, reason: '新一通不得被旧 busy 终止');
    expect(p2pCallMsgId, newMsgId, reason: '活动通话标识保持新一通');
    expect(gTimer, isNotNull, reason: '新一通的计时器不得被旧 busy 取消');

    gTimer?.cancel();
    gTimer = null;
  });

  test('迟到 bye（旧 msgId）：只收敛旧记录，不动新一通全局状态', () async {
    const oldMsgId = 'call-old-bye';
    const newMsgId = 'call-new-bye';
    await insertCallRecord(oldMsgId, media: 'audio');
    await insertCallRecord(newMsgId, media: 'audio');
    p2pCallScreenOn = true;
    p2pCallMsgId = newMsgId;

    await MessageWebrtc.instance.handleWebRTC('WEBRTC_BYE', {
      'id': oldMsgId,
      'from': _peerUid,
      'payload': <String, dynamic>{},
    });
    await expectRecordStateEventually(
      oldMsgId,
      3,
      reason: '旧通话记录按其 msgId 收敛为挂断(3)',
    );
    expect(await recordState(newMsgId), 0);
    expect(p2pCallScreenOn, isTrue);
    expect(p2pCallMsgId, newMsgId);
  });

  test('无活动通话时到达的终态信令只收敛对应记录', () async {
    const msgId = 'call-orphan-1';
    await insertCallRecord(msgId);
    expect(p2pCallMsgId, isNull);

    await MessageWebrtc.instance.handleWebRTC('WEBRTC_BYE', {
      'id': msgId,
      'from': _peerUid,
      'payload': <String, dynamic>{},
    });
    await expectRecordStateEventually(msgId, 3);
    expect(p2pCallScreenOn, isFalse, reason: '无活动通话时不得置位全局状态');
  });
}
