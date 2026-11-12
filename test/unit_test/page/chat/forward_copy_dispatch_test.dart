/// 转发副本出网派发契约测试（RUN_ID=chat-multi-20261111 产品缺陷修复）。
///
/// 缺陷（DEV-01 双轮设备证据）：转发/合并转发管线把副本落库（status=10）
/// 后只 fire `MessageSendRequestedEvent` —— 该事件全仓无消费者；
/// image/file/chat_history_bundle 副本只能靠重进会话页（`_pageMessages`
/// 补发）/ 重启扫描 / 重连扫描**偶然**出网，UI 却报成功。
///
/// 修复（方案 B 变体）：落库后立即经 `ChatNetworkService.sendWsMsg`
/// 现行出网链路主动派发（加密判定 / 策略门 / deep-seal 闸 / 上传认领 /
/// 重试闭环零旁路）。本文件钉住派发缝契约：
///   - 每个目标会话恰一次派发，且先落库后派发；
///   - 派发模型 msg_type=chat_history_bundle、status=sending(10)；
///   - 附件重上传产物（新远端 uri）随派发模型一起出网，源 uri 不残留。
///
/// 全部经注入 fake（fetcher/inserter/forwarder/wsDispatcher）脱离
/// SQLite 与网络。
library;

import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/modules/messaging/application/history_bundle/bundle_attachment_forwarder.dart';
import 'package:imboy/page/chat/chat/bundle_forward_dispatcher.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

const String _uid = '1000000051';

ConversationModel _target(int id, String peerId) => ConversationModel(
  id: id,
  peerId: peerId,
  avatar: '',
  title: 't$id',
  subtitle: '',
  type: 'C2C',
  msgType: 'text',
  unreadNum: 0,
);

MessageModel _sourceRow(
  String id,
  int createdAt, {
  Map<String, dynamic>? payload,
  int status = IMBoyMessageStatus.sent,
  String msgType = 'text',
}) => MessageModel(
  id,
  autoId: 0,
  type: 'C2C',
  status: status,
  fromId: '1000000056',
  toId: _uid,
  payload: payload ?? <String, dynamic>{'text': 'hello $id'},
  createdAt: createdAt,
  isAuthor: 0,
  conversationUk3: 'C2C_${_uid}_1000000056',
  msgType: msgType,
);

core.Message _uiMessage(String id) => core.TextMessage(
  id: id,
  authorId: '1000000056',
  text: 'hello $id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
);

/// 记录型附件转发 fake：返回带新远端 uri 的重上传产物。
class _RecordingForwarder implements BundleAttachmentForwarder {
  _RecordingForwarder();

  final List<BundleAttachmentForwardRequest> requests =
      <BundleAttachmentForwardRequest>[];

  @override
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  ) async {
    requests.add(request);
    return <String, dynamic>{
      'uri': 'obj/new-key',
      'file_hash256': 'cafebabe',
      'size': 3,
    };
  }
}

void main() {
  setUp(() {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
      'chat_multi_select_v1': true,
      'chat_history_bundle_v1': true,
    });
  });

  tearDown(() {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
  });

  group('BundleForwardDispatcher 副本出网派发（方案 B 变体）', () {
    test(
      '每目标恰一次派发：先落库后派发，msg_type=chat_history_bundle、status=sending',
      () async {
        final rows = <String, MessageModel>{
          'm1': _sourceRow('m1', 1000),
          'm2': _sourceRow('m2', 2000),
        };
        final events = <String>[];
        final dispatched = <MessageModel>[];
        final dispatcher = BundleForwardDispatcher(
          messageFetcher: (id, chatType) async => rows[id],
          messageInserter: (model, chatType) async {
            events.add('insert:${model.id}');
          },
          forwarderUidResolver: () => _uid,
          attachmentForwarder: _RecordingForwarder(),
          wsDispatcher: (model) async {
            events.add('dispatch:${model.id}');
            dispatched.add(model);
            return true;
          },
        );

        final report = await dispatcher.sendToTargets(
          [_target(1, '1000000056')],
          [_uiMessage('m1'), _uiMessage('m2')],
          sourceChatType: 'C2C',
        );

        expect(report.allSuccess, isTrue);
        expect(dispatched, hasLength(1), reason: '一个目标会话恰派发一次');
        final model = dispatched.single;
        expect(model.msgType, 'chat_history_bundle');
        expect(model.status, IMBoyMessageStatus.sending, reason: '副本以发送中状态出网');
        expect(events, [
          'insert:${model.id}',
          'dispatch:${model.id}',
        ], reason: '必须先落库、后派发；派发不允许缺席');
      },
    );

    test('file 源：重上传产物（新远端 uri）随派发模型出网，源 uri 不残留', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'file',
          payload: <String, dynamic>{
            'uri': 'obj/old-key',
            'attachment_descriptor': <String, dynamic>{'k': 'v'},
            'file_hash256': 'deadbeef',
          },
        ),
      };
      final dispatched = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async {},
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
        targetEncryptedResolver: (chatType, peerId) async => true,
        wsDispatcher: (model) async {
          dispatched.add(model);
          return true;
        },
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      expect(dispatched, hasLength(1));
      final encoded = jsonEncode(dispatched.single.payloadMap);
      expect(encoded, contains('obj/new-key'), reason: '新远端 uri 必须随副本出网');
      expect(
        encoded,
        isNot(contains('obj/old-key')),
        reason: '源 uri（原会话 scope）不得残留',
      );
    });

    test('2 目标 → 2 次派发（目标串行，message id 互不相同）', () async {
      final rows = <String, MessageModel>{'m1': _sourceRow('m1', 1000)};
      final dispatched = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async {},
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
        wsDispatcher: (model) async {
          dispatched.add(model);
          return true;
        },
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056'), _target(2, '1000000057')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      expect(dispatched, hasLength(2), reason: '每个目标会话各派发一条 bundle 副本');
      expect(
        dispatched[0].id,
        isNot(dispatched[1].id),
        reason: '每目标独立 message id（现有契约）',
      );
    });
  });
}
