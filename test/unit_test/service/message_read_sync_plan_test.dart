// Q04-F05：message_read_sync 已读同步 c2c→c2g 泛化测试
//
// 行为合同（Q04-contract.md v1）：
// - I1 送达 ACK 永不清未读（本文件只覆盖已读事件链路）
// - I2 已读游标单调；重复/逆序事件不回退（计划层原样保留 id 集合，
//   单调性由 ConversationProvider._setLastReadAutoId 保证）
// - App 端合同 1：_handleMessageReadSync 不再固定 C2C，按事件实际会话类型分发
//
// 分两层：
// - 纯函数层：MessageReadSyncPlan.build 的 payload 解析与会话类型决策
//   （注入 lookupConversationType，不触 DB）
// - 集成层：switchS2C('message_read_sync') 全链路（fixture DB + 测试容器），
//   断言消息 status / 会话 unread_num / 已读游标 payload.last_read_auto_id
//
// 集成层环境要点（均为生产代码的既有测试口子，非行为变更）：
// - toTypeMessage → ContactRepo.findByUid 本地无联系人时会远程同步
//   （ContactApi.syncByUid）：HttpClient 拦截器发现「已登录但 token 空」
//   会走 quitLogin（清 storage/关库）毁掉 fixture 环境。因此注入
//   未过期伪 JWT（FlutterSecureStorage.setMockInitialValues）+ 短路
//   HTTP（HttpClient.adapterForTest）双保险。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_read_sync_plan.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _ownerUid = 995011;
const _c2cPeer = 2001;
const _c2gGid = 3001;

// 会话 uk3 与生产同源（ConversationModel.uk3 getter 一致）
final _c2cUk3 = ConversationUk3Generator.generateSmart(
  type: 'C2C',
  currentUserId: '$_ownerUid',
  peerId: '$_c2cPeer',
);
final _c2gUk3 = ConversationUk3Generator.generateSmart(
  type: 'C2G',
  currentUserId: '$_ownerUid',
  peerId: '$_c2gGid',
);

void main() {
  group('MessageReadSyncPlan.build - payload 解析（纯函数）', () {
    test('服务端群已读事件按 gid 与 conversation_type 解析', () async {
      final plan = await MessageReadSyncPlan.build({
        'conversation_type': 'c2g',
        'gid': _c2gGid,
        'read_seq': 2,
        'msg_ids': ['c2g_msg_1', 'c2g_msg_2'],
        'read_at': 1790931169469,
      });
      expect(plan, isNotNull);
      expect(plan!.conversationType, MessageFlowType.c2g);
      expect(plan.peer, '$_c2gGid');
      expect(plan.msgIds, ['c2g_msg_1', 'c2g_msg_2']);
    });

    test('群事件优先使用服务端 gid，不被旧 peer/type 覆盖', () async {
      final plan = await MessageReadSyncPlan.build({
        'conversation_type': 'c2g',
        'gid': _c2gGid,
        'peer': '$_c2cPeer',
        'type': 'C2C',
        'msg_ids': ['c2g_msg_1'],
      });
      expect(plan!.conversationType, MessageFlowType.c2g);
      expect(plan.peer, '$_c2gGid');
    });

    test('无明确群类型时不能把 gid 误当 C2C peer', () async {
      final plan = await MessageReadSyncPlan.build({
        'gid': _c2gGid,
        'msg_ids': ['c2g_msg_1'],
      }, lookupConversationType: (_) async => MessageFlowType.c2c);
      expect(plan, isNull);
    });

    test('c2c 回归：旧单值格式 msg_id+peer 解析为单条计划', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_id': 'm1',
        'peer': '$_c2cPeer',
        'read_at': 1,
      }, lookupConversationType: (_) async => MessageFlowType.c2c);
      expect(plan, isNotNull);
      expect(plan!.conversationType, MessageFlowType.c2c);
      expect(plan.peer, '$_c2cPeer');
      expect(plan.msgIds, ['m1']);
    });

    test('现役批量格式：msg_ids 优先，msg_id（回执自身 Xid）不混入', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_id': 'receipt_xid',
        'msg_ids': ['m1', 'm2'],
        'peer': '$_c2cPeer',
        'read_at': 2,
      }, lookupConversationType: (_) async => MessageFlowType.c2c);
      expect(plan!.msgIds, ['m1', 'm2']);
      expect(plan.msgIds.contains('receipt_xid'), isFalse);
    });

    test('msg_ids 为空列表时回落单值 msg_id（旧契约兼容）', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_id': 'm9',
        'msg_ids': <dynamic>[],
        'peer': '$_c2cPeer',
      }, lookupConversationType: (_) async => MessageFlowType.c2c);
      expect(plan!.msgIds, ['m9']);
    });

    test('c2g 分发：本地仅有 C2G 会话时按 C2G 命中', () async {
      String? lookedUp;
      final plan = await MessageReadSyncPlan.build(
        {
          'msg_ids': ['g1', 'g2'],
          'peer': '$_c2gGid',
        },
        lookupConversationType: (peer) async {
          lookedUp = peer;
          return MessageFlowType.c2g;
        },
      );
      expect(plan!.conversationType, MessageFlowType.c2g);
      expect(plan.peer, '$_c2gGid');
      expect(lookedUp, '$_c2gGid');
    });

    test('显式 type 字段优先于本地查找', () async {
      var lookupCalled = false;
      final plan = await MessageReadSyncPlan.build(
        {
          'msg_ids': ['g1'],
          'peer': '$_c2gGid',
          'type': 'C2G',
        },
        lookupConversationType: (_) async {
          lookupCalled = true;
          return MessageFlowType.c2c;
        },
      );
      expect(plan!.conversationType, MessageFlowType.c2g);
      expect(lookupCalled, isFalse);
    });

    test('显式 type 大小写不敏感（c2g → C2G）', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_id': 'g1',
        'peer': '$_c2gGid',
        'type': 'c2g',
      }, lookupConversationType: (_) async => null);
      expect(plan!.conversationType, MessageFlowType.c2g);
    });

    test('未知显式 type（如 CHANNEL）忽略并回落本地查找', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_id': 'm1',
        'peer': '$_c2cPeer',
        'type': 'CHANNEL',
      }, lookupConversationType: (_) async => MessageFlowType.c2c);
      expect(plan!.conversationType, MessageFlowType.c2c);
    });

    test('缺少 peer 返回 null（无效负载不误标记会话）', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_id': 'm1',
        'read_at': 3,
      }, lookupConversationType: (_) async => MessageFlowType.c2c);
      expect(plan, isNull);
    });

    test('msg_id 与 msg_ids 均缺失/为空返回 null', () async {
      expect(
        await MessageReadSyncPlan.build({
          'peer': '$_c2cPeer',
        }, lookupConversationType: (_) async => MessageFlowType.c2c),
        isNull,
      );
      expect(
        await MessageReadSyncPlan.build({
          'msg_ids': <dynamic>['', '  '],
          'peer': '$_c2cPeer',
        }, lookupConversationType: (_) async => MessageFlowType.c2c),
        isNull,
      );
    });

    test('无显式 type 且本地无会话返回 null', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_id': 'm1',
        'peer': '9999',
      }, lookupConversationType: (_) async => null);
      expect(plan, isNull);
    });

    test('msg_ids 非字符串元素统一字符串化', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_ids': <dynamic>[101, '102'],
        'peer': '$_c2gGid',
        'type': 'C2G',
      }, lookupConversationType: (_) async => null);
      expect(plan!.msgIds, ['101', '102']);
    });

    test('I2：重复/逆序 msg_ids 原样保留（单调性由下游游标保证）', () async {
      final plan = await MessageReadSyncPlan.build({
        'msg_ids': ['m2', 'm1', 'm2'],
        'peer': '$_c2gGid',
        'type': 'C2G',
      }, lookupConversationType: (_) async => null);
      // 计划层不去重不排序——去重/单调交由 _setLastReadAutoId 的
      // MAX(auto_id)+只推进语义兜底（合同 I2）。
      expect(plan!.msgIds, ['m2', 'm1', 'm2']);
    });
  });

  group('switchS2C(message_read_sync) - 全链路（fixture DB）', () {
    late Database db;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // 事件链中的消息状态广播可能触发附带 API 请求：HttpClient 拦截器发现
      // 「已登录但 token 空」会直接 quitLogin（清 storage、关库）毁掉 fixture
      // 环境。注入未过期伪 JWT + 短路 HTTP 双保险（见文件头说明）。
      FlutterSecureStorage.setMockInitialValues({
        'secure_token': _fakeJwt,
        'secure_refresh_token': _fakeJwt,
      });
      HttpClient.adapterForTest = _NoNetworkAdapter();
      addTearDown(() => HttpClient.adapterForTest = null);
      // 顺序必须与 pending_read_queue_test 一致：先 mock 登录态再 setDbForTest，
      // 否则 _openUid 采样到空 uid，db getter 判定失配后重走真库初始化。
      SharedPreferences.setMockInitialValues({Keys.currentUid: '$_ownerUid'});
      await StorageService.init();
      db = await openFixtureDatabaseAtVersion(version: 32);
      SqliteService.setDbForTest(db);

      // c2c 会话：2 条未读（auto_id 1/2，delivered）
      await db.insert('conversation', {
        'user_id': _ownerUid,
        'peer_id': _c2cPeer,
        'type': 'C2C',
        'unread_num': 2,
        'last_time': 1790931169467,
      });
      await _insertMsg(db, 'msg_c2c', 'c2c_msg_1', _c2cUk3, 1);
      await _insertMsg(db, 'msg_c2c', 'c2c_msg_2', _c2cUk3, 2);

      // c2g 会话：2 条未读（auto_id 1/2，delivered）
      await db.insert('conversation', {
        'user_id': _ownerUid,
        'peer_id': _c2gGid,
        'type': 'C2G',
        'unread_num': 2,
        'last_time': 1790931169468,
      });
      await _insertMsg(db, 'msg_c2g', 'c2g_msg_1', _c2gUk3, 1);
      await _insertMsg(db, 'msg_c2g', 'c2g_msg_2', _c2gUk3, 2);

      final container = ProviderContainer(
        overrides: [
          workspaceApiProvider.overrideWithValue(_NoopApi()),
          voicePlaybackServiceProvider.overrideWith(_Voice.new),
        ],
      );
      // chatProvider / conversationProvider 都是 autoDispose：markAsRead
      // 存在 async gap，无 listener 会在执行中途被销毁（Ref used after
      // disposed / UnmountedRefException，游标推进失败）。
      final keepAlive = container.listen(chatProvider, (_, _) {});
      final keepAliveConv = container.listen(conversationProvider, (_, _) {});
      MessageService.setProviderContainer(container);
      addTearDown(() async {
        keepAlive.close();
        keepAliveConv.close();
        container.dispose();
        // chatProvider 拉起会启动 MessageRetry 周期扫描（单例），
        // 不清理会带着已关闭的库跨测试继续跑。
        MessageRetry.instance.dispose();
        SqliteService.setDbForTest(null);
        await db.close();
      });
    });

    test('c2g 已读事件：批量 msg_ids 更新消息状态、清未读、推进游标', () async {
      await MessageS2CService.switchS2C({
        'id': '',
        'type': 'S2C',
        'action': 'message_read_sync',
        'from': 'server',
        'to': '$_ownerUid',
        'payload': {
          'msg_id': 'receipt_g',
          'msg_ids': ['c2g_msg_1', 'c2g_msg_2'],
          'gid': _c2gGid,
          'conversation_type': 'c2g',
          'read_seq': 2,
          'read_at': 1790931169469,
        },
        'server_ts': 1790931169470,
      });

      // 消息状态 → seen（另一设备已读，本设备同步）
      expect(
        await _msgStatus(db, 'msg_c2g', 'c2g_msg_1'),
        IMBoyMessageStatus.seen,
      );
      expect(
        await _msgStatus(db, 'msg_c2g', 'c2g_msg_2'),
        IMBoyMessageStatus.seen,
      );
      // c2c 会话不受影响（分发正确，不串扰）
      expect(
        await _msgStatus(db, 'msg_c2c', 'c2c_msg_1'),
        IMBoyMessageStatus.delivered,
      );

      // 会话未读清零 + 游标推进到 MAX(auto_id)=2
      final c2gRow = await _conversationRow(db, 'C2G', _c2gGid);
      expect(c2gRow['unread_num'], 0);
      expect(_lastReadAutoId(c2gRow), 2);

      // c2c 会话未读不动、游标未被触碰（payload 为空 → 无游标）
      final c2cRow = await _conversationRow(db, 'C2C', _c2cPeer);
      expect(c2cRow['unread_num'], 2);
      expect(_lastReadAutoId(c2cRow), isNull);
    });

    test('c2g 已读事件（旧单值格式）：单条消息正确同步', () async {
      await MessageS2CService.switchS2C({
        'id': '',
        'type': 'S2C',
        'action': 'message_read_sync',
        'from': 'server',
        'to': '$_ownerUid',
        'payload': {
          'msg_id': 'c2g_msg_1',
          'peer': '$_c2gGid',
          'read_at': 1790931169471,
        },
        'server_ts': 1790931169472,
      });

      expect(
        await _msgStatus(db, 'msg_c2g', 'c2g_msg_1'),
        IMBoyMessageStatus.seen,
      );
      expect(
        await _msgStatus(db, 'msg_c2g', 'c2g_msg_2'),
        IMBoyMessageStatus.delivered,
      );
      final row = await _conversationRow(db, 'C2G', _c2gGid);
      expect(row['unread_num'], 1);
      expect(_lastReadAutoId(row), 1);
    });

    test('c2c 回归：单值格式仍按 C2C 处理', () async {
      await MessageS2CService.switchS2C({
        'id': '',
        'type': 'S2C',
        'action': 'message_read_sync',
        'from': 'server',
        'to': '$_ownerUid',
        'payload': {
          'msg_id': 'c2c_msg_1',
          'peer': '$_c2cPeer',
          'read_at': 1790931169473,
        },
        'server_ts': 1790931169474,
      });

      expect(
        await _msgStatus(db, 'msg_c2c', 'c2c_msg_1'),
        IMBoyMessageStatus.seen,
      );
      expect(
        await _msgStatus(db, 'msg_c2g', 'c2g_msg_1'),
        IMBoyMessageStatus.delivered,
      );
      final row = await _conversationRow(db, 'C2C', _c2cPeer);
      expect(row['unread_num'], 1);
      expect(_lastReadAutoId(row), 1);
    });

    test('c2c 回归：现役批量格式 msg_ids 逐条生效', () async {
      await MessageS2CService.switchS2C({
        'id': '',
        'type': 'S2C',
        'action': 'message_read_sync',
        'from': 'server',
        'to': '$_ownerUid',
        'payload': {
          'msg_id': 'receipt_c',
          'msg_ids': ['c2c_msg_1', 'c2c_msg_2'],
          'peer': '$_c2cPeer',
          'read_at': 1790931169475,
        },
        'server_ts': 1790931169476,
      });

      expect(
        await _msgStatus(db, 'msg_c2c', 'c2c_msg_1'),
        IMBoyMessageStatus.seen,
      );
      expect(
        await _msgStatus(db, 'msg_c2c', 'c2c_msg_2'),
        IMBoyMessageStatus.seen,
      );
      final row = await _conversationRow(db, 'C2C', _c2cPeer);
      expect(row['unread_num'], 0);
      expect(_lastReadAutoId(row), 2);
    });

    test(
      'inverse and repeated read events preserve newer unread message',
      () async {
        await _insertMsg(db, 'msg_c2g', 'c2g_msg_3', _c2gUk3, 3);
        await db.update(
          'conversation',
          {'unread_num': 3},
          where: 'type = ? AND peer_id = ?',
          whereArgs: ['C2G', _c2gGid],
        );
        var eventIndex = 0;
        for (final seq in [2, 1, 2, 1]) {
          eventIndex++;
          await MessageS2CService.switchS2C({
            'id': 'ordered_receipt_$eventIndex',
            'type': 'S2C',
            'action': 'message_read_sync',
            'from': 'server',
            'to': '$_ownerUid',
            'payload': {
              'msg_id': 'receipt_$seq',
              'gid': _c2gGid,
              'conversation_type': 'c2g',
              'read_seq': seq,
              'msg_ids': seq == 2 ? ['c2g_msg_1', 'c2g_msg_2'] : ['c2g_msg_1'],
              'read_at': 1790931169469,
            },
            'server_ts': 1790931169470 + eventIndex,
          });
          final row = await _conversationRow(db, 'C2G', _c2gGid);
          expect(row['unread_num'], 1, reason: 'seq=$seq must retain N+1');
          expect(_lastReadAutoId(row), 2, reason: 'seq=$seq cannot regress');
          expect(
            await _msgStatus(db, 'msg_c2g', 'c2g_msg_3'),
            IMBoyMessageStatus.delivered,
          );
          expect(
            (await _conversationRow(db, 'C2C', _c2cPeer))['unread_num'],
            2,
          );
        }
      },
    );

    test(
      'read events ignore duplicate, missing, authored and foreign IDs',
      () async {
        await _insertMsg(db, 'msg_c2g', 'authored', _c2gUk3, 3);
        await db.update(
          'msg_c2g',
          {'is_author': 1},
          where: 'id = ?',
          whereArgs: ['authored'],
        );
        await _insertMsg(db, 'msg_c2g', 'foreign', 'another-conversation', 4);
        await _insertMsg(db, 'msg_c2g', 'revoked', _c2gUk3, 5);
        await db.update(
          'msg_c2g',
          {'status': IMBoyMessageStatus.peerRevoked},
          where: 'id = ?',
          whereArgs: ['revoked'],
        );
        await MessageS2CService.switchS2C({
          'id': 'scoped_receipt',
          'type': 'S2C',
          'action': 'message_read_sync',
          'from': 'server',
          'to': '$_ownerUid',
          'payload': {
            'gid': _c2gGid,
            'conversation_type': 'c2g',
            'msg_ids': [
              'c2g_msg_1',
              'c2g_msg_1',
              'authored',
              'foreign',
              'missing',
              'revoked',
            ],
          },
          'server_ts': 1790931169490,
        });
        final row = await _conversationRow(db, 'C2G', _c2gGid);
        expect(row['unread_num'], 1);
        expect(_lastReadAutoId(row), 1);
        expect(
          await _msgStatus(db, 'msg_c2g', 'c2g_msg_2'),
          IMBoyMessageStatus.delivered,
        );
        expect(
          await _msgStatus(db, 'msg_c2g', 'foreign'),
          IMBoyMessageStatus.delivered,
        );
        expect(
          await _msgStatus(db, 'msg_c2g', 'revoked'),
          IMBoyMessageStatus.peerRevoked,
        );
        expect((await _conversationRow(db, 'C2C', _c2cPeer))['unread_num'], 2);
      },
    );

    test('peer 无本地会话：事件安全跳过（不误建会话、不抛异常）', () async {
      await MessageS2CService.switchS2C({
        'id': '',
        'type': 'S2C',
        'action': 'message_read_sync',
        'from': 'server',
        'to': '$_ownerUid',
        'payload': {
          'msg_id': 'ghost',
          'peer': '8888',
          'read_at': 1790931169477,
        },
        'server_ts': 1790931169478,
      });

      final rows = await db.query('conversation');
      expect(rows, hasLength(2), reason: '不得为未知 peer 新建会话');
    });
  });
}

Future<void> _insertMsg(
  Database db,
  String table,
  String msgId,
  String uk3,
  int autoId,
) async {
  await db.insert(table, {
    'auto_id': autoId,
    'id': msgId,
    'msg_type': 'text',
    'from_id': 12345,
    'to_id': _ownerUid,
    'conversation_uk3': uk3,
    'payload': '{}',
    'created_at': 1790931100000 + autoId,
    'status': IMBoyMessageStatus.delivered,
    'is_author': 0,
    'type': table == 'msg_c2c' ? 'C2C' : 'C2G',
    'action': '',
  });
}

Future<int?> _msgStatus(Database db, String table, String msgId) async {
  final rows = await db.query(
    table,
    columns: ['status'],
    where: 'id = ?',
    whereArgs: [msgId],
  );
  return rows.isEmpty ? null : rows.first['status'] as int?;
}

Future<Map<String, Object?>> _conversationRow(
  Database db,
  String type,
  int peerId,
) async {
  final rows = await db.query(
    'conversation',
    where: 'type = ? AND user_id = ? AND peer_id = ?',
    whereArgs: [type, _ownerUid, peerId],
  );
  expect(rows, hasLength(1));
  return rows.first;
}

int? _lastReadAutoId(Map<String, Object?> row) {
  final raw = row['payload'];
  if (raw is String && raw.isNotEmpty) {
    // payload 为 JSON 字符串（ConversationRepo.updateById 序列化）
    // 简单解析 last_read_auto_id
    final match = RegExp(r'"last_read_auto_id":(\d+)').firstMatch(raw);
    if (match != null) return int.parse(match.group(1)!);
  }
  return null;
}

class _Voice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

class _NoopApi extends WorkspaceApi {}

/// 短路所有 HTTP 请求：返回 200 空响应体，不触网络。
class _NoNetworkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

/// exp=9999999999 的未过期伪 JWT（base64url 段拼接），
/// 供 HttpClient 拦截器 tokenExpired 检查放行。
String get _fakeJwt {
  const header = '{"alg":"HS256","typ":"JWT"}';
  const claims = '{"exp":9999999999}';
  String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  return '${b64(header)}.${b64(claims)}.test-signature';
}
