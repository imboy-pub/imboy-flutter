/// E2EE-061 Slice 4（接线刀）—— 上传路径的封装判定与绑定输入验收
///
/// 本刀把 Slice 2/3/4a/4b 的积木接进 `ChatAttachmentHandler`：
/// message_id 提前到上传之前生成、按闸门决定是否传 `seal`、descriptor 进
/// **加密** payload。
///
/// ⚠️ 上传动作本身依赖文件 IO 与静态 `AttachmentApi`，进不了单测；
/// 因此可验收的是**判定与绑定输入**（纯函数）+ **meta 的哈希语义**（走注入
/// seam）。「handler 真的把 seal 传下去了」只有真机腿能证，见 evidence 残留。
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

ChatAttachmentHandler _handler({
  required String type,
  required String peerId,
  required String selfUid,
  bool sealRollout = true,
}) => ChatAttachmentHandler(
  peerId: peerId,
  type: type,
  conversationUk3: ConversationUk3Generator.generateSmart(
    type: type,
    currentUserId: selfUid,
    peerId: peerId,
  ),
  currentUserOverride: User(id: selfUid, name: 'self'),
  sealRollout: sealRollout,
  onMessageCreated: (Message m) async => true,
);

AttachmentSealRequest? _build({
  bool rollout = true,
  bool encrypted = true,
  String messageId = 'msg-1',
  String conversationId = 'c2c:1:2',
  String senderUid = '1001',
  String attachmentId = 'image',
}) => ChatAttachmentHandler.buildSealRequest(
  rolloutEnabled: rollout,
  payloadWillBeEncrypted: encrypted,
  messageId: messageId,
  conversationId: conversationId,
  senderUid: senderUid,
  attachmentId: attachmentId,
);

void main() {
  group('1. buildSealRequest：正向可用性（防「恒 null 也满分」）', () {
    test('全部就绪时确实封装，且绑定值就是方案甲的那个值', () {
      final req = _build();
      expect(req, isNotNull);
      expect(
        req!.bindingHash,
        equals(
          AttachmentBinding.compute(
            messageId: 'msg-1',
            conversationId: 'c2c:1:2',
            senderUid: '1001',
          ),
        ),
      );
      expect(req.attachmentId, equals('image'));
      expect(req.chunkSize, equals(1024 * 1024)); // 拍板 ③
    });

    test('message_id 不同 → 绑定值不同（ATT-01 的锚点确实穿过来了）', () {
      final a = _build(messageId: 'msg-a')!.bindingHash;
      final b = _build(messageId: 'msg-b')!.bindingHash;
      expect(a, isNot(equals(b)));
    });
  });

  group('2. buildSealRequest：fail-closed 矩阵', () {
    test('⚠️ payload 不会被加密 → 绝不封装（content key 会明文出网）', () {
      expect(_build(encrypted: false), isNull);
    });

    test('推出开关关闭 → 不封装（Slice 6 未接线前的默认态）', () {
      expect(_build(rollout: false), isNull);
    });

    test('message_id 为空 → 不封装', () {
      expect(_build(messageId: ''), isNull);
    });

    test('conversation_id 为空 → 不封装', () {
      expect(_build(conversationId: ''), isNull);
    });

    test('sender_uid 为空 → 不封装', () {
      expect(_build(senderUid: ''), isNull);
    });
  });

  group('3. 绑定用的 conversation_id 必须两端一致', () {
    test('⚠️⚠️ C2G 不得用 conversationUk3——它含本机 uid，逐用户不同', () {
      final sender = _handler(type: 'C2G', peerId: 'g-9', selfUid: '1001');
      final receiver = _handler(type: 'C2G', peerId: 'g-9', selfUid: '2002');

      // uk3 两端不同：直接拿它当绑定输入，群附件除发送者外无人能开
      expect(sender.conversationUk3, isNot(equals(receiver.conversationUk3)));
      // 实际用的值两端一致
      expect(sender.sealConversationId, equals('g-9'));
      expect(receiver.sealConversationId, equals('g-9'));
    });

    test('C2C：两端算出同一个 conv_key（整数归一化）', () {
      final a = _handler(type: 'C2C', peerId: '2002', selfUid: '1001');
      final b = _handler(type: 'C2C', peerId: '1001', selfUid: '2002');
      expect(a.sealConversationId, equals('c2c:1001:2002'));
      expect(b.sealConversationId, equals(a.sealConversationId));
    });

    test('非聊天面（private）→ 空串 → 闸门判 missingBinding 不封装', () {
      final h = _handler(type: 'C2S', peerId: 'sys', selfUid: '1001');
      expect(h.sealConversationId, equals(''));
      expect(_build(conversationId: h.sealConversationId), isNull);
    });
  });

  group('4. meta 的 file_hash256 必须与服务端同值', () {
    final plain = Uint8List.fromList(
      List<int>.generate(100, (i) => (i * 31 + 7) & 0xFF),
    );

    Future<Map<String, dynamic>> upload({AttachmentSealRequest? seal}) {
      Map<String, dynamic>? confirmBody;
      return AttachmentApi.uploadBytesViaPresignMeta(
        plain,
        'a.bin',
        'application/octet-stream',
        seal: seal,
        presignFn: (f, m) async => IMBoyHttpResponse.success(<String, dynamic>{
          'put_url': 'https://example.invalid/put',
          'object_key': 'u1001/2026/07/a.bin',
        }),
        putFn: (url, b, mime, process) async {},
        confirmFn: (body) async {
          confirmBody = body;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
      ).then((meta) {
        // 把 confirm 实参并进返回值，便于比对「消息体 == 服务端」
        return <String, dynamic>{...meta, '_confirm': confirmBody};
      });
    }

    test('未封装：仍是明文哈希（旧行为零破坏）', () async {
      final meta = await upload();
      expect(meta['file_hash256'], equals(sha256.convert(plain).toString()));
      expect(
        meta['file_hash256'],
        equals((meta['_confirm'] as Map)['file_hash256']),
      );
    });

    test('⚠️ 封装后：消息体带的是密文哈希，与 confirm 同值', () async {
      final seal = AttachmentSealRequest(
        bindingHash: AttachmentBinding.compute(
          messageId: 'msg-1',
          conversationId: 'c2c:1:2',
          senderUid: '1001',
        ),
        attachmentId: 'file',
        chunkSize: 32,
      );
      final meta = await upload(seal: seal);
      expect(
        meta['file_hash256'],
        isNot(equals(sha256.convert(plain).toString())),
        reason: '明文哈希不得出现在消息体与 confirm 里（拍板 ①）',
      );
      expect(
        meta['file_hash256'],
        equals((meta['_confirm'] as Map)['file_hash256']),
        reason: '与服务端 attachment.file_hash256 不同值会断掉收藏引用计数',
      );
      // size 仍是明文大小：它进的是加密 payload，给 UI 用
      expect(meta['size'], equals(100));
    });
  });

  group('5. carriesContentKey：明文出网闸门的判据', () {
    test('带 descriptor → true', () {
      expect(
        AttachmentSealPolicy.carriesContentKey(<String, dynamic>{
          AttachmentSealPolicy.descriptorPayloadKey: <String, dynamic>{
            'attachment_id': 'x',
          },
        }),
        isTrue,
      );
    });

    test('⚠️ 库里读出的 Map<dynamic, dynamic> 也必须认得（否则静默放行）', () {
      final fromDb = <dynamic, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: <dynamic, dynamic>{
          'attachment_id': 'x',
        },
      };
      expect(AttachmentSealPolicy.carriesContentKey(fromDb), isTrue);
    });

    test('普通 payload / null → false', () {
      expect(
        AttachmentSealPolicy.carriesContentKey(<String, dynamic>{'text': 'hi'}),
        isFalse,
      );
      expect(AttachmentSealPolicy.carriesContentKey(null), isFalse);
    });
  });
}
