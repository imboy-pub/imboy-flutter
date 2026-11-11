/// 类型矩阵全表验收测试（§4.4「合并转发」列）：可合并类型逐一生成 entry
/// 形态钉死；不可合并类型整体拒绝 + 稳定错误码；一条违规即整体失败。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

HistoryBundleSourceMessage _msg(
  String? type, {
  String id = 'src_1',
  int sentAtMs = 1760000000000,
  MessageStatus status = MessageStatus.sent,
  Map<String, dynamic> payload = const <String, dynamic>{},
  String? senderName,
  bool e2eeFailed = false,
  int burnReadAtMs = 0,
}) {
  return HistoryBundleSourceMessage(
    msgType: type,
    sourceMessageId: id,
    sourceChatType: 'C2C',
    sourceFromUid: '1001',
    sourceToUid: '2002',
    senderName: senderName,
    sentAtMs: sentAtMs,
    payload: payload,
    status: status,
    e2eeFailedPlaceholder: e2eeFailed,
    burnReadAtMs: burnReadAtMs,
  );
}

HistoryBundleBuildSuccess _ok(Object result) =>
    (result as HistoryBundleBuildSuccessResult).success;

HistoryBundleBuildFailure _fail(Object result) =>
    (result as HistoryBundleBuildFailureResult).failure;

void main() {
  const target = 'C2C_9001_9002';

  test('msg_type 输出常量：本地定义 chat_history_bundle（W3-I 才注册类型体系）', () {
    expect(HistoryBundleContract.msgType, 'chat_history_bundle');
  });

  group('可合并类型（§4.4 合并转发列）', () {
    test('text：全量快照 + 递归清理', () {
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(
          MessageType.text,
          payload: <String, dynamic>{
            'msg_type': 'text',
            'text': 'hello',
            'peer_id': '42', // 埋雷：builder 层 sanitizer 纵深清理
          },
        ),
      ]);
      final success = _ok(r);
      final json = success.bundle.toJson();
      final entry = (json['entries'] as List).single;
      expect(entry['msg_type'], 'text');
      expect(entry['payload'], <String, dynamic>{
        'msg_type': 'text',
        'text': 'hello',
      });
      expect(success.sanitizedFieldCount, 1);
      expect(success.attachmentTasks, isEmpty);
    });

    test('text：正文键回退 content（历史数据）', () {
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(
          MessageType.text,
          payload: <String, dynamic>{'content': 'legacy body'},
        ),
      ]);
      final entry = _ok(r).bundle.entries.single;
      expect(entry.payload['text'], 'legacy body');
    });

    test('location：安全字段快照（title/address/latitude/longitude）', () {
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(
          MessageType.location,
          payload: <String, dynamic>{
            'title': '总部',
            'address': '北京市朝阳区',
            'latitude': '39.9',
            'longitude': '116.4',
            'conversation_uk3': 'SECRET', // 非白名单键不进入 pick
          },
        ),
      ]);
      final entry = _ok(r).bundle.entries.single;
      expect(entry.msgType, 'location');
      expect(entry.payload, <String, dynamic>{
        'title': '总部',
        'address': '北京市朝阳区',
        'latitude': '39.9',
        'longitude': '116.4',
      });
    });

    test('expression：可见文本快照', () {
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(
          MessageType.expression,
          payload: <String, dynamic>{'text': '[微笑]', 'sender_did': 'd1'},
        ),
      ]);
      final entry = _ok(r).bundle.entries.single;
      expect(entry.msgType, 'expression');
      expect(entry.payload, <String, dynamic>{'text': '[微笑]'});
    });

    test('quote：扁平化可见文本（正文 + 被引用文本，丢弃引用结构）', () {
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(
          MessageType.quote,
          payload: <String, dynamic>{
            'text': '回复正文',
            'quote_text': '被引用的内容',
            'quote_msg_id': 'M0', // 引用结构 id 不进快照
            'peer_id': '42',
          },
        ),
      ]);
      final entry = _ok(r).bundle.entries.single;
      expect(entry.msgType, 'quote');
      expect(entry.payload, <String, dynamic>{
        'text': '回复正文',
        'quote_text': '被引用的内容',
      });
    });

    test('quote：正文缺失时被引用文本仍在', () {
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(
          MessageType.quote,
          payload: <String, dynamic>{'quote_text': '只有被引用'},
        ),
      ]);
      final entry = _ok(r).bundle.entries.single;
      expect(entry.payload['text'], '');
      expect(entry.payload['quote_text'], '只有被引用');
    });
  });

  group('附件类型：占位快照 + 转发任务（对象引用剥离）', () {
    test('image：占位仅显示字段，任务携带完整源 payload', () {
      final payload = <String, dynamic>{
        'name': 'a.png',
        'size': 123,
        'width': 10,
        'height': 20,
        'uri': 'https://s3/presigned-src', // 源 scope 引用：不入 bundle
        'file_hash256': 'hash-src',
        'attachment_descriptor': <String, dynamic>{'k': 'secret'},
      };
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(MessageType.image, id: 'MSG-IMG-1', payload: payload),
      ]);
      final success = _ok(r);
      final entry = success.bundle.entries.single;
      expect(entry.msgType, 'image');
      expect(entry.payload, <String, dynamic>{
        'name': 'a.png',
        'size': 123,
        'width': 10,
        'height': 20,
      });
      final task = success.attachmentTasks.single;
      expect(task.entryIndex, 0);
      expect(task.sourceMsgType, 'image');
      expect(task.sourceMessageId, 'MSG-IMG-1');
      expect(task.sourcePayload['uri'], 'https://s3/presigned-src');
      expect(task.sourcePayload['attachment_descriptor'], isNotNull);
    });

    test('imageMulti：逐图占位 + total，单任务', () {
      final payload = <String, dynamic>{
        'total': 2,
        'images': <dynamic>[
          <String, dynamic>{'name': '1.png', 'size': 1, 'uri': 'u1'},
          <String, dynamic>{
            'name': '2.png',
            'size': 2,
            'width': 5,
            'height': 6,
            'file_hash256': 'h2',
          },
        ],
      };
      final r = HistoryBundleBuilder.buildForTarget(target, [
        _msg(MessageType.imageMulti, payload: payload),
      ]);
      final success = _ok(r);
      final entry = success.bundle.entries.single;
      expect(entry.msgType, 'imageMulti');
      expect(entry.payload, <String, dynamic>{
        'total': 2,
        'images': <dynamic>[
          <String, dynamic>{'name': '1.png', 'size': 1},
          <String, dynamic>{
            'name': '2.png',
            'size': 2,
            'width': 5,
            'height': 6,
          },
        ],
      });
      expect(success.attachmentTasks, hasLength(1));
      expect(success.attachmentTasks.single.sourceMsgType, 'imageMulti');
    });

    test('voice 与 audio（归一为 voice）：占位 + 任务', () {
      for (final type in <String>[MessageType.voice, MessageType.audio]) {
        final r = HistoryBundleBuilder.buildForTarget(target, [
          _msg(
            type,
            payload: <String, dynamic>{
              'name': 'v.amr',
              'size': 999,
              'duration_ms': 2500,
              'uri': 's3://voice',
            },
          ),
        ]);
        final success = _ok(r);
        final entry = success.bundle.entries.single;
        expect(entry.msgType, 'voice', reason: '$type 归一为 voice');
        expect(entry.payload, <String, dynamic>{
          'name': 'v.amr',
          'size': 999,
          'duration_ms': 2500,
        });
        expect(success.attachmentTasks.single.sourceMsgType, 'voice');
      }
    });

    test('video 与 file：占位 + 任务', () {
      final video = _ok(
        HistoryBundleBuilder.buildForTarget(target, [
          _msg(
            MessageType.video,
            payload: <String, dynamic>{
              'name': 'v.mp4',
              'size': 5,
              'width': 640,
              'height': 480,
              'duration_ms': 9000,
              'uri': 's3://video',
            },
          ),
        ]),
      );
      expect(video.bundle.entries.single.payload, <String, dynamic>{
        'name': 'v.mp4',
        'size': 5,
        'width': 640,
        'height': 480,
        'duration_ms': 9000,
      });

      final file = _ok(
        HistoryBundleBuilder.buildForTarget(target, [
          _msg(
            MessageType.file,
            payload: <String, dynamic>{
              'filename': 'doc.pdf',
              'size': 77,
              'uri': 's3://file',
            },
          ),
        ]),
      );
      expect(file.bundle.entries.single.msgType, 'file');
      expect(file.bundle.entries.single.payload, <String, dynamic>{
        'filename': 'doc.pdf',
        'size': 77,
      });
      expect(file.attachmentTasks.single.sourceMsgType, 'file');
    });
  });

  group('不可合并类型：整体拒绝 + 稳定错误码', () {
    void rejectCase(
      String label,
      HistoryBundleSourceMessage bad, {
      required String expectedCode,
    }) {
      test(label, () {
        final r = HistoryBundleBuilder.buildForTarget(target, [
          _msg(MessageType.text, payload: <String, dynamic>{'text': 'ok'}),
          bad,
        ]);
        expect(r, isA<HistoryBundleBuildFailureResult>());
        final failure = _fail(r);
        expect(failure.errorCode, expectedCode);
        expect(failure.messageIndex, 1);
      });
    }

    rejectCase(
      '系统/控制（S2C action 落库值）',
      _msg(S2CAction.groupMemberJoin),
      expectedCode: HistoryBundleBuildErrorCode.rejectedSystemOrControl,
    );
    rejectCase(
      '撤回占位字面量 revoked',
      _msg('revoked'),
      expectedCode: HistoryBundleBuildErrorCode.rejectedSystemOrControl,
    );
    rejectCase(
      'WebRTC 音频',
      _msg(MessageType.webrtcAudio),
      expectedCode: HistoryBundleBuildErrorCode.rejectedWebrtc,
    );
    rejectCase(
      'WebRTC 视频（含下划线历史脏数据归一）',
      _msg('webrtc_video'),
      expectedCode: HistoryBundleBuildErrorCode.rejectedWebrtc,
    );
    rejectCase(
      'E2EE 解密失败占位',
      _msg(MessageType.text, e2eeFailed: true),
      expectedCode: HistoryBundleBuildErrorCode.rejectedE2eeFailed,
    );
    rejectCase(
      '发送中',
      _msg(MessageType.text, status: MessageStatus.sending),
      expectedCode: HistoryBundleBuildErrorCode.rejectedStatusSending,
    );
    rejectCase(
      '发送失败',
      _msg(MessageType.image, status: MessageStatus.error),
      expectedCode: HistoryBundleBuildErrorCode.rejectedStatusFailed,
    );
    rejectCase(
      '已撤回',
      _msg(MessageType.text, status: MessageStatus.revoked),
      expectedCode: HistoryBundleBuildErrorCode.rejectedRevoked,
    );
    rejectCase(
      '阅后即焚',
      _msg(
        MessageType.text,
        payload: <String, dynamic>{'text': 'x', 'burn_read_at': 1760000000001},
        burnReadAtMs: 1760000000001,
      ),
      expectedCode: HistoryBundleBuildErrorCode.rejectedBurnAfterRead,
    );
    rejectCase(
      '红包',
      _msg(MessageType.redPacket),
      expectedCode: HistoryBundleBuildErrorCode.rejectedPayment,
    );
    rejectCase(
      '转账',
      _msg(MessageType.transfer),
      expectedCode: HistoryBundleBuildErrorCode.rejectedPayment,
    );
    rejectCase(
      '业务卡片 businessActionCard',
      _msg(MessageType.businessActionCard),
      expectedCode: HistoryBundleBuildErrorCode.rejectedBusinessCard,
    );
    rejectCase(
      '业务卡片 visitCard',
      _msg(MessageType.visitCard),
      expectedCode: HistoryBundleBuildErrorCode.rejectedBusinessCard,
    );
    rejectCase(
      '业务卡片 legacyChannelMessage（归一 channelCard）',
      _msg(MessageType.legacyChannelMessage),
      expectedCode: HistoryBundleBuildErrorCode.rejectedBusinessCard,
    );
    rejectCase(
      'textStream（不在合并转发白名单）',
      _msg(MessageType.textStream),
      expectedCode: HistoryBundleBuildErrorCode.rejectedUnsupportedType,
    );
    rejectCase(
      'custom / 未知新类型（fail-closed）',
      _msg('future_cool_type'),
      expectedCode: HistoryBundleBuildErrorCode.rejectedUnsupportedType,
    );
    rejectCase(
      'msgType 为 null（系统行）',
      _msg(null),
      expectedCode: HistoryBundleBuildErrorCode.rejectedUnsupportedType,
    );
  });

  test('准入优先级：E2EE 失败占位高于发送中', () {
    final r = HistoryBundleBuilder.buildForTarget(target, [
      _msg(MessageType.text, status: MessageStatus.sending, e2eeFailed: true),
    ]);
    expect(_fail(r).errorCode, HistoryBundleBuildErrorCode.rejectedE2eeFailed);
  });

  test('sender_name / sent_at 元数据写入条目', () {
    final r = HistoryBundleBuilder.buildForTarget(target, [
      _msg(
        MessageType.text,
        senderName: '张三',
        sentAtMs: 1760000099999,
        payload: <String, dynamic>{'text': 'hi'},
      ),
    ]);
    final json = _ok(r).bundle.toJson();
    final entry = (json['entries'] as List).single;
    expect(entry['sender_name'], '张三');
    expect(entry['sent_at'], 1760000099999);
  });

  test('目标会话为空串：invalidTarget', () {
    final r = HistoryBundleBuilder.buildForTarget('  ', [
      _msg(MessageType.text, payload: <String, dynamic>{'text': 'x'}),
    ]);
    expect(_fail(r).errorCode, HistoryBundleBuildErrorCode.invalidTarget);
  });

  test('bundle JSON 不含目标会话标识与源消息 id（目标无关信息隔离）', () {
    final r = HistoryBundleBuilder.buildForTarget(target, [
      _msg(
        MessageType.text,
        id: 'SECRET_SRC_ID',
        payload: <String, dynamic>{'text': 'body'},
      ),
    ]);
    final encoded = _ok(r).bundle.toJson().toString();
    expect(encoded.contains(target), isFalse);
    expect(encoded.contains('SECRET_SRC_ID'), isFalse);
  });
}
