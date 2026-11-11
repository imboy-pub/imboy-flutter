/// 附件转发适配接口调用契约验收测试：bind 参数逐项钉死（新 message id /
/// 目标 scope / 目标会话绑定 / 转发者）、fake adapter 调用记录、写回与
/// 尺寸复检流程（BND-05 客户端侧单元）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/history_bundle/bundle_attachment_forwarder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 记录型 fake：校验调用契约 + 返回可控新绑定 payload。
class _FakeForwarder implements BundleAttachmentForwarder {
  _FakeForwarder(this.stubPayload);

  final Map<String, dynamic> stubPayload;
  final List<BundleAttachmentForwardRequest> calls =
      <BundleAttachmentForwardRequest>[];

  @override
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  ) async {
    calls.add(request);
    return Map<String, dynamic>.of(stubPayload);
  }
}

HistoryBundleSourceMessage _attachMsg(
  String type,
  String id,
  Map<String, dynamic> payload,
) {
  return HistoryBundleSourceMessage(
    msgType: type,
    sourceMessageId: id,
    sourceChatType: 'C2G',
    sourceFromUid: '1001',
    sourceToUid: '77001',
    sentAtMs: 1760000000000,
    payload: payload,
    status: MessageStatus.sent,
  );
}

void main() {
  test(
    'bindBundleAttachmentTasks：任务绑定新 message id / 目标 scope / 目标会话 / 转发者',
    () {
      final success = (HistoryBundleBuilder.buildForTarget(
        'C2G_77001',
        <HistoryBundleSourceMessage>[
          _attachMsg(MessageType.image, 'SRC-IMG', <String, dynamic>{
            'name': 'a.png',
            'uri': 's3://src-object',
            'attachment_descriptor': <String, dynamic>{'key': 'k'},
          }),
          HistoryBundleSourceMessage(
            msgType: MessageType.text,
            sourceMessageId: 'SRC-TXT',
            sourceChatType: 'C2G',
            sourceFromUid: '1001',
            sourceToUid: '77001',
            sentAtMs: 1760000000001,
            payload: <String, dynamic>{'text': '说明文字'},
            status: MessageStatus.sent,
          ),
        ],
      ) as HistoryBundleBuildSuccessResult).success;

      expect(success.attachmentTasks, hasLength(1));
      final requests = bindBundleAttachmentTasks(
        tasks: success.attachmentTasks,
        newMessageId: 'NEW-MSG-1',
        targetScope: 'group',
        targetConversationUk3: 'C2G_77001',
        forwarderUid: '1001',
      );

      expect(requests, hasLength(1));
      final req = requests.single;
      // 调用契约：目标侧绑定（§4.5 附件按新 message ID、目标会话、转发者重封装）
      expect(req.newMessageId, 'NEW-MSG-1');
      expect(req.targetScope, 'group');
      expect(req.targetConversationUk3, 'C2G_77001');
      expect(req.forwarderUid, '1001');
      // 源侧绑定五元组原样传递（重封装 AAD 源输入）
      expect(req.task.sourceMessageId, 'SRC-IMG');
      expect(req.task.sourceChatType, 'C2G');
      expect(req.task.sourceFromUid, '1001');
      expect(req.task.sourceToUid, '77001');
      expect(req.task.sourceMsgType, 'image');
      expect(req.task.sourcePayload['uri'], 's3://src-object');
      // 文本条目不产生任务
      expect(
        success.attachmentTasks.any((t) => t.sourceMessageId == 'SRC-TXT'),
        isFalse,
      );
    },
  );

  test('fake adapter：收到完整请求参数；返回新绑定写回条目', () async {
    final success = (HistoryBundleBuilder.buildForTarget(
      'C2C_9001_9002',
      <HistoryBundleSourceMessage>[
        _attachMsg(MessageType.file, 'SRC-FILE', <String, dynamic>{
          'filename': 'doc.pdf',
          'size': 77,
          'uri': 's3://src-file',
        }),
      ],
    ) as HistoryBundleBuildSuccessResult).success;

    final forwarder = _FakeForwarder(<String, dynamic>{
      'filename': 'doc.pdf',
      'size': 77,
      'uri': 'https://garage/new-target-scoped-uri',
      'file_hash256': 'new-hash',
    });

    final requests = bindBundleAttachmentTasks(
      tasks: success.attachmentTasks,
      newMessageId: 'NEW-MSG-2',
      targetScope: 'c2c:9001:9002',
      targetConversationUk3: 'C2C_9001_9002',
      forwarderUid: '9001',
    );

    // 发送入口流程：逐任务调用 adapter（同目标串行，§4.3）
    var bundle = success.bundle;
    for (final req in requests) {
      final forwarded = await forwarder.forwardAttachment(req);
      bundle = bundle.withEntryPayload(req.task.entryIndex, forwarded);
      // 写回后必须复检尺寸（超限整条放弃）
      expect(validateBundlePayloadSize(bundle.serializedByteLength), isNull);
    }

    expect(forwarder.calls, hasLength(1));
    final call = forwarder.calls.single;
    expect(call.newMessageId, 'NEW-MSG-2');
    expect(call.targetScope, 'c2c:9001:9002');
    expect(call.targetConversationUk3, 'C2C_9001_9002');
    expect(call.forwarderUid, '9001');

    final entry = bundle.entries[call.task.entryIndex];
    expect(entry.msgType, 'file');
    expect(entry.payload['uri'], 'https://garage/new-target-scoped-uri');
    expect(entry.payload['file_hash256'], 'new-hash');
    // 原 bundle 占位未被污染
    expect(success.bundle.entries[0].payload.containsKey('uri'), isFalse);
  });

  test('多个附件任务按 entries 顺序绑定（imageMulti 单任务 + 独立消息多任务）', () async {
    final success = (HistoryBundleBuilder.buildForTarget(
      'C2G_77001',
      <HistoryBundleSourceMessage>[
        _attachMsg(MessageType.image, 'SRC-A', <String, dynamic>{
          'name': 'a.png',
          'uri': 's3://a',
        }),
        _attachMsg(MessageType.imageMulti, 'SRC-B', <String, dynamic>{
          'images': <dynamic>[
            <String, dynamic>{'name': 'b1.png', 'uri': 's3://b1'},
            <String, dynamic>{'name': 'b2.png', 'uri': 's3://b2'},
          ],
          'total': 2,
        }),
        _attachMsg(MessageType.voice, 'SRC-C', <String, dynamic>{
          'name': 'c.amr',
          'uri': 's3://c',
        }),
      ],
    ) as HistoryBundleBuildSuccessResult).success;

    // imageMulti 是一条消息 → 单个任务（整条多图重封装由 adapter 内部处理）
    expect(success.attachmentTasks, hasLength(3));
    expect(success.attachmentTasks.map((t) => t.entryIndex).toList(), <int>[
      0,
      1,
      2,
    ]);
    expect(
      success.attachmentTasks.map((t) => t.sourceMessageId).toList(),
      <String>['SRC-A', 'SRC-B', 'SRC-C'],
    );
    expect(
      success.attachmentTasks.map((t) => t.sourceMsgType).toList(),
      <String>['image', 'imageMulti', 'voice'],
    );

    final forwarder = _FakeForwarder(<String, dynamic>{'uri': 's3://new'});
    var bundle = success.bundle;
    for (final req in bindBundleAttachmentTasks(
      tasks: success.attachmentTasks,
      newMessageId: 'NEW-3',
      targetScope: 'group',
      targetConversationUk3: 'C2G_77001',
      forwarderUid: '1001',
    )) {
      bundle = bundle.withEntryPayload(
        req.task.entryIndex,
        await forwarder.forwardAttachment(req),
      );
    }
    expect(forwarder.calls, hasLength(3));
    expect(bundle.entries.every((e) => e.payload['uri'] == 's3://new'), isTrue);
  });

  test('msg_type 常量冻结：chat_history_bundle（不改 message_type_constants）', () {
    // W3-I 才在类型体系中注册；此处本地常量必须与后端合同一致。
    expect(HistoryBundleContract.msgType, 'chat_history_bundle');
    expect(HistoryBundleContract.bundleVersion, 1);
  });
}
