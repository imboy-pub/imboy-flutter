/// Central Wiring 合并转发编排与按钮动作策略测试（chat_history_bundle_v1）。
///
/// 覆盖：
/// 1. `bundleActionAllowedFor` / `exportActionAllowedFor`：flag 门控 +
///    类型矩阵 + 状态/焚毁/E2EE 失败 + 条数上限（计划 §12.5）。
/// 2. `BundleForwardDispatcher.sendToTargets`：目标串行、每目标独立构建、
///    禁止字段不入 payload、源行缺失整体放弃、准入预检失败零落库、
///    192KiB 客户端软边（W3-L F-4）、附件任务绑定（新 message id /
///    目标 scope / 转发者 uid，W2-G 调用契约）。
///
/// 全部经注入 fake（fetcher/inserter/forwarder）脱离 SQLite 与网络。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/modules/messaging/application/history_bundle/bundle_attachment_forwarder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart'
    as domain_msg;
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
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

MessageSelectionTraits _traits(
  String? msgType, {
  domain_msg.MessageStatus status = domain_msg.MessageStatus.sent,
  bool e2eeFailed = false,
  int burnReadAt = 0,
}) => MessageSelectionTraits(
  msgType: msgType,
  status: status,
  e2eeFailed: e2eeFailed,
  burnReadAt: burnReadAt,
);

/// 记录型附件转发 fake（返回改写后的新 uri payload）。
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
      'chat_export_share_v1': true,
    });
  });

  tearDown(() {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
  });

  group('bundleActionAllowedFor（§12.5 合并转发按钮策略）', () {
    test('flag 关闭 → 恒 false', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
      expect(
        bundleActionAllowedFor([_traits('text')]),
        isFalse,
        reason: 'rollout flag 默认关闭，关闭时按钮禁用（零 UI 变化语义）',
      );
    });

    test('text/image/voice/quote 可合并 → true；空集 → false', () {
      expect(bundleActionAllowedFor([_traits('text')]), isTrue);
      expect(bundleActionAllowedFor([_traits('image')]), isTrue);
      expect(bundleActionAllowedFor([_traits('voice')]), isTrue);
      expect(bundleActionAllowedFor([_traits('quote')]), isTrue);
      expect(bundleActionAllowedFor(<MessageSelectionTraits>[]), isFalse);
    });

    test('状态维度：sending/error/revoked → false', () {
      expect(
        bundleActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.sending),
        ]),
        isFalse,
      );
      expect(
        bundleActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.error),
        ]),
        isFalse,
      );
      expect(
        bundleActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.revoked),
        ]),
        isFalse,
      );
    });

    test('E2EE 失败占位 / 阅后即焚 → false（冻结合同 §4.4）', () {
      expect(
        bundleActionAllowedFor([_traits('text', e2eeFailed: true)]),
        isFalse,
      );
      expect(
        bundleActionAllowedFor([_traits('text', burnReadAt: 123)]),
        isFalse,
      );
    });

    test('不可合并类型 → false（WebRTC/红包/转账/系统/未知 fail-closed）', () {
      expect(bundleActionAllowedFor([_traits('webrtcAudio')]), isFalse);
      expect(bundleActionAllowedFor([_traits('redPacket')]), isFalse);
      expect(bundleActionAllowedFor([_traits('transfer')]), isFalse);
      expect(bundleActionAllowedFor([_traits('groupNotice')]), isFalse);
      expect(bundleActionAllowedFor([_traits(null)]), isFalse);
      expect(bundleActionAllowedFor([_traits('some_unknown_type')]), isFalse);
    });

    test('51 条 → false（1..50 上限）；50 条 → true', () {
      expect(
        bundleActionAllowedFor(List.generate(51, (_) => _traits('text'))),
        isFalse,
      );
      expect(
        bundleActionAllowedFor(List.generate(50, (_) => _traits('text'))),
        isTrue,
      );
    });
  });

  group('exportActionAllowedFor（§12.5 导出按钮策略）', () {
    test('flag 关闭 → 恒 false', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
      expect(exportActionAllowedFor([_traits('text')]), isFalse);
    });

    test('text 与 image（描述导出）→ true；红包/发送中/E2EE 失败 → false', () {
      expect(exportActionAllowedFor([_traits('text')]), isTrue);
      expect(exportActionAllowedFor([_traits('image')]), isTrue);
      expect(exportActionAllowedFor([_traits('redPacket')]), isFalse);
      expect(
        exportActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.sending),
        ]),
        isFalse,
      );
      expect(
        exportActionAllowedFor([_traits('text', e2eeFailed: true)]),
        isFalse,
      );
    });
  });

  group('BundleForwardDispatcher.sendToTargets', () {
    test('2 源 × 2 目标：目标串行、每目标独立构建、payload 干净、目标字段正确', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow('m1', 1000),
        'm2': _sourceRow('m2', 2000),
      };
      final inserted = <MessageModel>[];
      final targets = [_target(1, '1000000056'), _target(2, '1000000057')];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(targets, [
        _uiMessage('m1'),
        _uiMessage('m2'),
      ], sourceChatType: 'C2C');

      expect(report.allSuccess, isTrue);
      expect(report.successCount, 2);
      expect(inserted.length, 2);
      // 目标串行：插入顺序 = 目标传入顺序（§4.3 v1 目标间也串行）
      expect(inserted[0].toId, '1000000056');
      expect(inserted[1].toId, '1000000057');
      // 每目标独立新 message id
      expect(inserted[0].id, isNot(inserted[1].id));
      for (final row in inserted) {
        expect(row.msgType, 'chat_history_bundle');
        expect(row.status, IMBoyMessageStatus.sending);
        expect(row.isAuthor, 1);
        expect(row.fromId, _uid);
        final payload = row.payloadMap;
        expect(payload['bundle_version'], 1);
        final entries = payload['entries'] as List;
        expect(entries.length, 2);
        // 稳定排序：createdAt 从旧到新
        expect((entries[0] as Map)['payload']['text'], 'hello m1');
        expect((entries[1] as Map)['payload']['text'], 'hello m2');
        // 禁止字段（合同 §4.5）不入 payload 顶层
        expect(payload.containsKey('peer_id'), isFalse);
        expect(payload.containsKey('conversation_uk3'), isFalse);
        expect(payload.containsKey('sender_did'), isFalse);
        expect(payload.containsKey('burn_read_at'), isFalse);
      }
    });

    test('准入预检失败（sending 源）→ 零落库零转发，整体放弃', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow('m1', 1000),
        'm2': _sourceRow('m2', 2000, status: IMBoyMessageStatus.sending),
      };
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1'), _uiMessage('m2')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.rejectedStatusSending,
      );
      expect(inserted, isEmpty);
    });

    test('源行缺失 → 整体放弃（invalidTarget），无部分 bundle', () async {
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => null,
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.invalidTarget,
      );
      expect(inserted, isEmpty);
    });

    test('192KiB 客户端软边（W3-L F-4）：介于软边与 256KiB 之间先行失败', () async {
      final big = 'x' * (200 * 1024);
      final rows = <String, MessageModel>{
        'm1': _sourceRow('m1', 1000, payload: <String, dynamic>{'text': big}),
      };
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.payloadTooLarge,
      );
      expect(inserted, isEmpty);

      // 边界下量级仍可正常发送
      final smallRows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          payload: <String, dynamic>{'text': 'x' * 1024},
        ),
      };
      final okInserted = <MessageModel>[];
      final okDispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => smallRows[id],
        messageInserter: (model, chatType) async => okInserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );
      final ok = await okDispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );
      expect(ok.allSuccess, isTrue);
    });

    test('附件任务绑定：新 message id / 目标 scope / 转发者 uid（W2-G 契约）', () async {
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
      final forwarder = _RecordingForwarder();
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: forwarder,
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      expect(forwarder.requests, hasLength(1));
      final req = forwarder.requests.single;
      expect(req.task.sourceMsgType, 'file');
      expect(req.task.sourceMessageId, 'm1');
      expect(
        req.newMessageId,
        inserted.single.id,
        reason: '附件锚点与落库消息同 id（与单条转发同序）',
      );
      expect(req.targetScope, 'c2c');
      expect(
        req.targetConversationUk3,
        startsWith('c2c:'),
        reason: '重封装 targetConversationId 绑定与单条转发同真值（scopeRef）',
      );
      expect(req.forwarderUid, _uid);
      // withEntryPayload 写回：落库 payload 的 entry 使用适配器产物
      final entries = inserted.single.payloadMap['entries'] as List;
      expect((entries[0] as Map)['payload']['uri'], 'obj/new-key');
      expect((entries[0] as Map)['payload']['file_hash256'], 'cafebabe');
    });
  });
}
