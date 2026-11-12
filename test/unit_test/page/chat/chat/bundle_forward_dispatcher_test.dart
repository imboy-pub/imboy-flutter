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

/// 记录型附件转发 fake（按脚本顺序返回 payload，缺省新 uri payload）。
class _RecordingForwarder implements BundleAttachmentForwarder {
  // ignore: prefer_initializing_formals
  _RecordingForwarder({List<Map<String, dynamic>> script = const []})
    : _script = List<Map<String, dynamic>>.of(script);

  final List<Map<String, dynamic>> _script;
  var _calls = 0;
  final List<BundleAttachmentForwardRequest> requests =
      <BundleAttachmentForwardRequest>[];

  @override
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  ) async {
    requests.add(request);
    final index = _calls++;
    if (index < _script.length) return _script[index];
    return <String, dynamic>{
      'uri': 'obj/new-key',
      'file_hash256': 'cafebabe',
      'size': 3,
    };
  }
}

/// 抛普通 Exception 的转发 fake（附件下载/上传等基础设施失败形态）。
class _ThrowingForwarder implements BundleAttachmentForwarder {
  const _ThrowingForwarder();

  @override
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  ) async {
    throw Exception('attachment upload failed');
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

    test('源行缺失 → 整体放弃（sourceMissing），无部分 bundle', () async {
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
        HistoryBundleBuildErrorCode.sourceMissing,
        reason: 'W5 G4-7：源行缺失与目标标识缺失语义分离，专用稳定码',
      );
      expect(inserted, isEmpty);
    });

    test(
      'W5 G4-1：burn_read_at 为字符串形态 → rejectedBurnAfterRead（焚毁闸 §4.4）',
      () async {
        final rows = <String, MessageModel>{
          'm1': _sourceRow(
            'm1',
            1000,
            payload: <String, dynamic>{
              'text': 'burn-me',
              // 字符串形态的已读时刻：仅按 int 解析会落 0 绕过焚毁闸。
              'burn_read_at': '1731000000000',
            },
          ),
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
          HistoryBundleBuildErrorCode.rejectedBurnAfterRead,
          reason: '字符串 burn_read_at 必须经 ChatBurnService 宽松解析命中焚毁闸',
        );
        expect(inserted, isEmpty, reason: '无半转发状态');
      },
    );

    test('W5 G4-2：空 targets → invalidTarget 稳定码返回（不抛 StateError）', () async {
      var fetcherCalls = 0;
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async {
          fetcherCalls++;
          return null;
        },
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(<ConversationModel>[], [
        _uiMessage('m1'),
      ], sourceChatType: 'C2C');

      expect(report.successCount, 0);
      expect(report.allSuccess, isFalse);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.invalidTarget,
        reason: '与 validateBatch 空目标同语义的稳定码',
      );
      expect(fetcherCalls, 0, reason: '入口防御在阶段 1 之前短路');
      expect(inserted, isEmpty);
    });

    test('S1-L3：>9 目标 → invalidTarget 整体拒绝（9 目标闸纵深防御）', () async {
      var fetcherCalls = 0;
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async {
          fetcherCalls++;
          return _sourceRow('m1', 1000);
        },
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );
      final tenTargets = [
        for (var i = 0; i < 10; i++) _target(i + 1, '20000$i'),
      ];

      final report = await dispatcher.sendToTargets(tenTargets, [
        _uiMessage('m1'),
      ], sourceChatType: 'C2C');

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.invalidTarget,
        reason: '与 G4-2 空 targets 同风格的入口稳定码拒绝',
      );
      expect(fetcherCalls, 0, reason: '目标数闸在源行快照之前短路');
      expect(inserted, isEmpty, reason: '零构建零重传（资源不放大）');
    });

    test('S1-L3：9 目标（上限内）→ 全部逐目标成功', () async {
      final rows = <String, MessageModel>{'m1': _sourceRow('m1', 1000)};
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );
      final nineTargets = [
        for (var i = 0; i < 9; i++) _target(i + 1, '20000$i'),
      ];

      final report = await dispatcher.sendToTargets(nineTargets, [
        _uiMessage('m1'),
      ], sourceChatType: 'C2C');

      expect(report.allSuccess, isTrue);
      expect(report.successCount, 9);
      expect(inserted, hasLength(9), reason: '上限内逐目标独立构建不受影响');
    });

    test('S1-L5：forwarderName 进顶层 sender_name（详情页来源行数据源）', () async {
      final rows = <String, MessageModel>{'m1': _sourceRow('m1', 1000)};
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
        forwarderName: '李四',
      );

      expect(report.allSuccess, isTrue);
      expect(
        inserted.single.payloadMap['sender_name'],
        '李四',
        reason: '合同顶层预留键：转发者展示名仅供详情页来源行展示',
      );
    });

    test('S1-M1 写回兜底：附件写回产物深度超限 → sendFailed 整目标失败零落库', () async {
      // 理论不可达（构建期深度闸已拒深树源行），防御写回通路自身：
      // forwarder 产物若为深树（>maxDepth），sanitizeAttachmentWriteback
      // 不得让 depthExceeded 产物静默进入 bundle JSON。
      Map<String, dynamic> deep = <String, dynamic>{'leaf': true};
      for (var i = 0; i < 20; i++) {
        deep = <String, dynamic>{'nested': deep};
      }
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'file',
          payload: <String, dynamic>{'uri': 'obj/old-key'},
        ),
      };
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(script: [deep]),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.sendFailed,
        reason: '深度超限写回按稳定码整目标失败（不静默不落库）',
      );
      expect(inserted, isEmpty);
    });

    test(
      'W5 G4-3：阶段 1 fetcher 抛 Exception → sendFailed 归一，不产生未处理异步错误',
      () async {
        final inserted = <MessageModel>[];
        final dispatcher = BundleForwardDispatcher(
          messageFetcher: (id, chatType) async => throw Exception('db locked'),
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
          HistoryBundleBuildErrorCode.sendFailed,
          reason: 'DB 异常与 F4 附件基础设施失败同口径归一',
        );
        expect(inserted, isEmpty);
      },
    );

    test('W5 G4-3：阶段 2 probe 构建抛 Exception → sendFailed 归一，零落库', () async {
      final rows = <String, MessageModel>{'m1': _sourceRow('m1', 1000)};
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
        bundleBuilder: (uk3, sources, {title, senderName}) =>
            throw Exception('probe exploded'),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.sendFailed,
        reason: 'probe 构建异常不得穿透 sendToTargets（未处理异步错误）',
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
        targetEncryptedResolver: (chatType, peerId) async => true,
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

    test(
      'A4 CRITICAL：sealed 源 + 明文目标 → rejected_plaintext_target，零落库',
      () async {
        final rows = <String, MessageModel>{
          'm1': _sourceRow(
            'm1',
            1000,
            msgType: 'file',
            payload: <String, dynamic>{
              'uri': 'obj/old-key',
              'attachment_descriptor': <String, dynamic>{'k': 'v'},
            },
          ),
        };
        var resolverCalls = 0;
        final forwarder = _RecordingForwarder();
        final inserted = <MessageModel>[];
        final dispatcher = BundleForwardDispatcher(
          messageFetcher: (id, chatType) async => rows[id],
          messageInserter: (model, chatType) async => inserted.add(model),
          forwarderUidResolver: () => _uid,
          attachmentForwarder: forwarder,
          targetEncryptedResolver: (chatType, peerId) async {
            resolverCalls++;
            return false;
          },
        );

        final report = await dispatcher.sendToTargets(
          [_target(1, '1000000056')],
          [_uiMessage('m1')],
          sourceChatType: 'C2C',
        );

        expect(report.successCount, 0);
        expect(
          report.failures.single.errorCode,
          HistoryBundleBuildErrorCode.rejectedPlaintextTarget,
        );
        expect(resolverCalls, 1);
        expect(forwarder.requests, isEmpty, reason: '重封装不得开始');
        expect(inserted, isEmpty, reason: '无半转发状态');
      },
    );

    test('A4 CRITICAL：plain 源 + 明文目标不受闸影响（回归锚）', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'file',
          payload: <String, dynamic>{'uri': 'obj/old-key'},
        ),
      };
      final forwarder = _RecordingForwarder();
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: forwarder,
        targetEncryptedResolver: (chatType, peerId) async => false,
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      expect(forwarder.requests, hasLength(1));
      expect(inserted, hasLength(1));
    });

    test('A4 HIGH：写回产物经 sanitizer（junk 清理）且目标绑定 descriptor 保留', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'file',
          payload: <String, dynamic>{
            'uri': 'obj/old-key',
            'attachment_descriptor': <String, dynamic>{'k': 'v'},
          },
        ),
      };
      final forwarder = _RecordingForwarder(
        script: <Map<String, dynamic>>[
          // adapter 产物：新 descriptor（目标绑定）+ 源残留 junk 键
          <String, dynamic>{
            'uri': 'obj/new-key',
            'file_hash256': 'cafebabe',
            'attachment_descriptor': <String, dynamic>{'new': 'key'},
            'from_id': '1000000056',
            'burn_read_at': 999,
            'e2ee_stale': <String, dynamic>{},
          },
        ],
      );
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: forwarder,
        targetEncryptedResolver: (chatType, peerId) async => true,
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      final entryPayload =
          (inserted.single.payloadMap['entries'] as List).first as Map;
      final wp = entryPayload['payload'] as Map;
      expect(wp['uri'], 'obj/new-key');
      expect(wp['attachment_descriptor'], <String, dynamic>{
        'new': 'key',
      }, reason: '目标绑定新 descriptor 是接收侧开封合法机制（§4.5 禁止源密钥）');
      expect(wp.containsKey('from_id'), isFalse);
      expect(wp.containsKey('burn_read_at'), isFalse);
      expect(wp.containsKey('e2ee_stale'), isFalse);
    });

    test('A4 HIGH：imageMulti 写回逐图净化，每图 descriptor 保留', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'imageMulti',
          payload: <String, dynamic>{
            'images': [
              <String, dynamic>{
                'uri': 'obj/old-1',
                'attachment_descriptor': <String, dynamic>{'k': 1},
              },
              <String, dynamic>{'uri': 'obj/old-2', 'peer_id': 'leak'},
            ],
          },
        ),
      };
      final forwarder = _RecordingForwarder(
        script: <Map<String, dynamic>>[
          <String, dynamic>{
            'images': [
              <String, dynamic>{
                'uri': 'obj/new-1',
                'attachment_descriptor': <String, dynamic>{'new': 1},
                'from_id': 'junk',
              },
              <String, dynamic>{
                'uri': 'obj/new-2',
                'attachment_descriptor': <String, dynamic>{'new': 2},
              },
            ],
            'total': 2,
          },
        ],
      );
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: forwarder,
        targetEncryptedResolver: (chatType, peerId) async => true,
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      final wp =
          ((inserted.single.payloadMap['entries'] as List).first
                  as Map)['payload']
              as Map;
      final images = wp['images'] as List;
      expect((images[0] as Map)['attachment_descriptor'], {'new': 1});
      expect((images[0] as Map).containsKey('from_id'), isFalse);
      expect((images[1] as Map)['attachment_descriptor'], {'new': 2});
      expect((images[1] as Map)['uri'], 'obj/new-2');
    });

    test('W5 G4-5：images[] 非 Map 元素取净化后版本（不透传原引用/未净化内容）', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'imageMulti',
          payload: <String, dynamic>{
            'images': [
              <String, dynamic>{'uri': 'obj/old-1'},
            ],
          },
        ),
      };
      // adapter 产物：images 混入非 Map 元素（嵌套 list 夹带禁止键 + 标量）。
      final adapterPayload = <String, dynamic>{
        'images': [
          <String, dynamic>{'uri': 'obj/new-1'},
          <dynamic>[
            <String, dynamic>{'peer_id': 'leak', 'text': 'x'},
          ],
          'plain-scalar',
        ],
        'total': 3,
      };
      final forwarder = _RecordingForwarder(script: [adapterPayload]);
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: forwarder,
        targetEncryptedResolver: (chatType, peerId) async => true,
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      final wp =
          ((inserted.single.payloadMap['entries'] as List).first
                  as Map)['payload']
              as Map;
      final images = wp['images'] as List;
      expect(images, hasLength(3));
      // Map 元素照常净化 + descriptor 回填路径。
      expect((images[0] as Map)['uri'], 'obj/new-1');
      // 非 Map 的嵌套 list 元素：必须走 sanitizer 净化（禁止键被清），
      // 不得原引用透传。
      final nested = (images[1] as List).single as Map;
      expect(nested.containsKey('peer_id'), isFalse, reason: '禁止键被清理');
      expect(nested['text'], 'x');
      expect(
        identical(images[1], (adapterPayload['images'] as List)[1]),
        isFalse,
        reason: '非 Map 元素也不得与 adapter 产物共享可变引用',
      );
      // 标量元素保留。
      expect(images[2], 'plain-scalar');
    });

    test('F2：C2C 源 → C2G 目标：scope/resolver/落库按目标 C2G，fetch 仍走源表', () async {
      final fetchChatTypes = <String>[];
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'file',
          payload: <String, dynamic>{
            'uri': 'obj/old-key',
            'attachment_descriptor': <String, dynamic>{'k': 'v'},
          },
        ),
      };
      final resolverCalls = <({String chatType, String peerId})>[];
      final forwarder = _RecordingForwarder();
      final insertChatTypes = <String>[];
      final inserted = <MessageModel>[];
      const gid = '2000000071';
      final groupTarget = ConversationModel(
        id: 9,
        peerId: gid,
        avatar: '',
        title: 'g',
        subtitle: '',
        type: 'C2G',
        msgType: 'text',
        unreadNum: 0,
      );
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async {
          fetchChatTypes.add(chatType);
          return rows[id];
        },
        messageInserter: (model, chatType) async {
          insertChatTypes.add(chatType);
          inserted.add(model);
        },
        forwarderUidResolver: () => _uid,
        attachmentForwarder: forwarder,
        targetEncryptedResolver: (chatType, peerId) async {
          resolverCalls.add((chatType: chatType, peerId: peerId));
          return true;
        },
      );

      final report = await dispatcher.sendToTargets(
        [groupTarget],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.allSuccess, isTrue);
      // 源消息 DB 行 fetch 仍按**源** chatType（fetch 表按源）
      expect(fetchChatTypes, everyElement('C2C'));
      // resolver 收到**目标**派生 chatType + 目标 peerId（与单条转发同口径）
      expect(resolverCalls, hasLength(1));
      expect(resolverCalls.single.chatType, 'C2G');
      expect(resolverCalls.single.peerId, gid);
      expect(
        resolverCalls.map((r) => r.chatType),
        isNot(contains('C2C')),
        reason: '跨类型目标不得把源 chatType 灌进加密判定',
      );
      // 上传 scope 按目标 C2G：scope=group、绑定=gid（deriveUploadScope）
      expect(forwarder.requests, hasLength(1));
      expect(forwarder.requests.single.targetScope, 'group');
      expect(forwarder.requests.single.targetConversationUk3, gid);
      // 落库：model.type=C2G 且插表走 msg_c2g（chatType=C2G）
      expect(inserted.single.type, 'C2G');
      expect(insertChatTypes, everyElement('C2G'));
    });

    test(
      'F4：非 Bundle 异常（附件上传失败）→ bundle_send_failed，不误标 payloadTooLarge',
      () async {
        final rows = <String, MessageModel>{
          // 明文附件源（无 descriptor）：不触发加密判定，异常来自转发适配器
          'm1': _sourceRow(
            'm1',
            1000,
            msgType: 'file',
            payload: <String, dynamic>{'uri': 'obj/old-key'},
          ),
        };
        final inserted = <MessageModel>[];
        final dispatcher = BundleForwardDispatcher(
          messageFetcher: (id, chatType) async => rows[id],
          messageInserter: (model, chatType) async => inserted.add(model),
          forwarderUidResolver: () => _uid,
          attachmentForwarder: const _ThrowingForwarder(),
          targetEncryptedResolver: (chatType, peerId) async => true,
        );

        final report = await dispatcher.sendToTargets(
          [_target(1, '1000000056')],
          [_uiMessage('m1')],
          sourceChatType: 'C2C',
        );

        expect(report.successCount, 0);
        expect(
          report.failures.single.errorCode,
          HistoryBundleBuildErrorCode.sendFailed,
          reason:
              '基础设施失败须归一专用稳定码（含 resolver 的 '
              'policy_not_initialized 等非 bundle 异常）',
        );
        expect(
          report.failures.single.errorCode,
          isNot(HistoryBundleBuildErrorCode.payloadTooLarge),
          reason: '尺寸语义不得被借用为泛化失败码（F4 误标本体）',
        );
        expect(inserted, isEmpty, reason: '失败目标零落库（无半转发状态）');
      },
    );

    test('F4 负向：BundleForwardException 保留原码（不被归一覆盖）', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'file',
          payload: <String, dynamic>{
            'uri': 'obj/old-key',
            'attachment_descriptor': <String, dynamic>{'k': 'v'},
          },
        ),
      };
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
        targetEncryptedResolver: (chatType, peerId) async => false,
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.rejectedPlaintextTarget,
        reason: '策略性拒绝的原码语义优先于基础设施归一码',
      );
      expect(
        report.failures.single.errorCode,
        isNot(HistoryBundleBuildErrorCode.sendFailed),
      );
      expect(inserted, isEmpty);
    });
  });
}
