import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';

import '../../helper/sqflite_test_helper.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 转发消息构造契约测试。
///
/// 钉住两个真机实测到的缺陷（2026-08-03，从群聊转发到单聊）：
///   1. 源消息 metadata 覆盖了目标会话的 peer_id / conversation_uk3，
///      发出的 payload 仍指向源群，消息归属错乱。
///   2. 顶层 msg_type 为空 → 服务端回 action=invalid_message，
///      消息显示「[无效消息类型]」并每 5~10s 无限重试。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '10001');
    await StorageService.to.setString(
      Keys.currentUser,
      '{"uid":"10001","nickname":"Fixture","account":"","email":"",'
      '"mobile":"","avatar":"","role":null,"gender":0,"region":"",'
      '"sign":"","setting":{}}',
    );
  });
  tearDown(() => SqliteService.setDbForTest(null));

  for (final outcome in ['success', 'false', 'throw']) {
    test(
      'sendMsg dispatch $outcome preserves one sending echo and returns actual result',
      () async {
        mockSqfliteSqlcipher();
        final db = _ForwardDb();
        SqliteService.setDbForTest(db);
        final order = <String>[];
        final echoes = <core.Message>[];
        final subscription = AppEventBus.on<DataWrapperEvent>().listen((event) {
          if (event.dataType == 'Message') {
            echoes.add(event.data as core.Message);
            order.add('echo');
          }
        });
        addTearDown(subscription.cancel);
        final notifier = SendToNotifier(
          networkService: _ForwardNetwork((model) async {
            await Future<void>.delayed(Duration.zero);
            order.add('dispatch');
            if (outcome == 'throw') throw StateError('dispatch failed');
            return outcome == 'success';
          }),
        );
        final ok = await notifier.sendMsg(
          ConversationModel(
            id: 1,
            peerId: '10002',
            avatar: '',
            title: 'target',
            subtitle: '',
            type: 'C2C',
            msgType: 'text',
            unreadNum: 0,
          ),
          const core.TextMessage(
            id: 'source',
            authorId: '10001',
            text: 'fixture',
          ),
          silent: true,
        );
        expect(ok, outcome == 'success');
        expect(db.rows, hasLength(1));
        expect(db.rows.single['status'], IMBoyMessageStatus.sending);
        expect(echoes, hasLength(1));
        expect(echoes.single.id, db.rows.single['id']);
        expect(echoes.single.status, core.MessageStatus.sending);
        expect(order, ['echo', 'dispatch']);
      },
    );
  }

  group('SendToNotifier.buildForwardPayload', () {
    test('目标会话的 peer_id / conversation_uk3 覆盖源消息 metadata', () {
      final payload = SendToNotifier.buildForwardPayload(
        // 源自群会话的 metadata
        sourceMetadata: {
          'peer_id': '104603643803863040',
          'conversation_uk3': 'C2G_50_104603643803863040',
          'msg_type': 'text',
        },
        text: 'group-msg-001',
        peerId: 1,
        conversationUk3: 'C2C_1_50',
      );

      expect(payload['peer_id'], 1, reason: '必须是目标会话的 peer，不是源群 gid');
      expect(payload['conversation_uk3'], 'C2C_1_50');
      expect(payload['text'], 'group-msg-001');
      // 与会话无关的元信息应保留
      expect(payload['msg_type'], 'text');
    });

    test('metadata 为 null 时也能构造出完整 payload', () {
      final payload = SendToNotifier.buildForwardPayload(
        sourceMetadata: null,
        text: 'hi',
        peerId: 7,
        conversationUk3: 'C2C_7_50',
      );

      expect(payload['text'], 'hi');
      expect(payload['peer_id'], 7);
      expect(payload['conversation_uk3'], 'C2C_7_50');
    });
  });

  group('SendToNotifier.resolveForwardMsgType', () {
    test('取源消息的 msg_type', () {
      expect(
        SendToNotifier.resolveForwardMsgType({'msg_type': 'image'}),
        'image',
      );
    });

    test('metadata 为 null → 兜底 text（顶层 msg_type 绝不能为空）', () {
      expect(SendToNotifier.resolveForwardMsgType(null), 'text');
    });

    test('msg_type 为空串 → 兜底 text', () {
      expect(SendToNotifier.resolveForwardMsgType({'msg_type': ''}), 'text');
    });

    test('msg_type 缺失 → 兜底 text', () {
      expect(SendToNotifier.resolveForwardMsgType({'text': 'hi'}), 'text');
    });

    test('历史别名 channel_message → 现役 channel_card（不传播废弃类型）', () {
      // 转发旧消息时若原样带出 channel_message，新会话里又是一条
      // 「不支持的消息类型」；这里必须换成已注册渲染器的现役类型。
      expect(
        SendToNotifier.resolveForwardMsgType({'msg_type': 'channel_message'}),
        'channel_card',
      );
    });
  });

  // FWDFIX：加密附件转发失败 → 用户可见文案映射（既有 i18n 机制）。
  group('SendToNotifier.forwardFailureToast（稳定错误码 → i18n 文案）', () {
    test('明文目标域拒绝 → 专属文案（不落兜底）', () {
      expect(
        SendToNotifier.forwardFailureToast(
          'attachment_forward_plaintext_target',
        ),
        t.common.e2eeErrForwardPlaintextTarget,
      );
    });

    test('源不可解密 / 认证解密失败 → 专属文案', () {
      expect(
        SendToNotifier.forwardFailureToast('attachment_forward_undecryptable'),
        t.common.e2eeErrForwardUndecryptable,
      );
      expect(
        SendToNotifier.forwardFailureToast('attachment_forward_open_failed'),
        t.common.e2eeErrForwardUndecryptable,
      );
    });

    test('基础设施失败（下载/上传）→ 既有通用 sendFailed', () {
      expect(
        SendToNotifier.forwardFailureToast('attachment_forward_fetch_failed'),
        t.common.sendFailed,
      );
      expect(
        SendToNotifier.forwardFailureToast('attachment_forward_upload_failed'),
        t.common.sendFailed,
      );
    });

    // A4FIX 复审 F1：合并转发（bundle_forward_dispatcher）的同一语义拒绝
    // 走 HistoryBundleBuildErrorCode.rejectedPlaintextTarget，须与单条转发
    // 复用同一专属文案（无新 i18n 键），策略性永久拒绝才可被用户辨识。
    test('合并转发明文目标拒绝（rejected_plaintext_target）→ 同一专属文案', () {
      expect(
        SendToNotifier.forwardFailureToast(
          HistoryBundleBuildErrorCode.rejectedPlaintextTarget,
        ),
        t.common.e2eeErrForwardPlaintextTarget,
      );
    });

    test('合并转发其余构建侧错误码 → 通用 sendFailed（不误配专属文案）', () {
      expect(
        SendToNotifier.forwardFailureToast(
          HistoryBundleBuildErrorCode.payloadTooLarge,
        ),
        t.common.sendFailed,
      );
      expect(
        SendToNotifier.forwardFailureToast(
          HistoryBundleBuildErrorCode.rejectedStatusSending,
        ),
        t.common.sendFailed,
      );
      // W5 G4-7：源行缺失专用码同样落通用文案（默认分支覆盖，无需新键）。
      expect(
        SendToNotifier.forwardFailureToast(
          HistoryBundleBuildErrorCode.sourceMissing,
        ),
        t.common.sendFailed,
      );
    });
  });
}

class _ForwardNetwork extends ChatNetworkService {
  _ForwardNetwork(this.dispatch);
  final Future<bool> Function(MessageModel) dispatch;
  @override
  Future<bool> sendWsMsg(MessageModel model) => dispatch(model);
}

class _ForwardDb extends Fake implements Database, Transaction {
  final rows = <Map<String, Object?>>[];
  @override
  bool get isOpen => true;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) => action(this);
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => sql.startsWith('SELECT COUNT(*)')
      ? [
          {'count': 0},
        ]
      : [];
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => [];
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    rows.add(Map<String, Object?>.from(values));
    return rows.length;
  }
}
