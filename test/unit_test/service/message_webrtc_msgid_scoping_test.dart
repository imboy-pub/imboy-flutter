import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart'
    show gTimer, p2pCallMsgId, p2pCallScreenOn, p2pEntry;
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message_webrtc.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart'
    show openFixtureDatabaseAtVersion;

/// CALL-11 / UX_SPEC §8：终态信令（busy/bye）按 msgId 判定归属。
/// 迟到的旧通话信令只收敛自己的记录，不得改写新一通的全局状态。
const String _currentUid = '1817128709888507904';
const String _peerUid = '1825989847768576000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late int generation;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _currentUid);

    // 生产真源 fixture：真实 msg_c2c/contact/FTS 形态。
    db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    // 消息富化会读取作者；缺少联系人会触发 HTTP 补全，并因合成会话
    // 没有 token 而登出关库。本套件只验证本地终态信令，提供完整本地数据。
    await db.insert('contact', {
      'user_id': int.parse(_currentUid),
      'peer_id': int.parse(_peerUid),
      'nickname': 'RTC fixture peer',
    });
    generation = UserRepoLocal.to.sessionGeneration;
    MessageWebrtc.instance.webrtcMsgFrom.clear();

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
    MessageWebrtc.instance.webrtcMsgFrom.clear();
    await SqliteService.to.close();
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

  /// handleWebRTC 返回时写库仍可能进行中；等待真实消息更新事件，
  /// 确保写库和消息富化都已完成后再断言、关闭 fixture。
  Future<void> handleTerminalSignal(
    String type,
    String msgId,
    int expected,
  ) async {
    final updated = Completer<Message>();
    final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
      event,
    ) {
      final message = event.data;
      if (event.dataType == 'Message' &&
          message is Message &&
          message.id == msgId &&
          !updated.isCompleted) {
        updated.complete(message);
      }
    });
    try {
      await MessageWebrtc.instance.handleWebRTC(type, {
        'id': msgId,
        'from': _peerUid,
        'payload': <String, dynamic>{},
      });
      final message = await updated.future.timeout(const Duration(seconds: 5));
      expect(message.metadata?['state'], expected);
      expect(await recordState(msgId), expected);
      expect(UserRepoLocal.to.currentUid, _currentUid);
      expect(UserRepoLocal.to.sessionGeneration, generation);
      expect(db.isOpen, isTrue);
    } finally {
      await subscription.cancel();
    }
  }

  test('本通 busy：按 msgId 收敛记录并复位全局通话状态', () async {
    const msgId = 'call-active-1';
    await insertCallRecord(msgId);
    p2pCallScreenOn = true;
    p2pCallMsgId = msgId;
    gTimer = Timer(const Duration(seconds: 60), () {});
    await handleTerminalSignal('WEBRTC_BUSY', msgId, 5);
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

    await handleTerminalSignal('WEBRTC_BUSY', oldMsgId, 5);
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

    await handleTerminalSignal('WEBRTC_BYE', oldMsgId, 3);
    expect(await recordState(newMsgId), 0);
    expect(p2pCallScreenOn, isTrue);
    expect(p2pCallMsgId, newMsgId);
  });

  test('无活动通话时到达的终态信令只收敛对应记录', () async {
    const msgId = 'call-orphan-1';
    await insertCallRecord(msgId);
    expect(p2pCallMsgId, isNull);

    await handleTerminalSignal('WEBRTC_BYE', msgId, 3);
    expect(p2pCallScreenOn, isFalse, reason: '无活动通话时不得置位全局状态');
  });
}
