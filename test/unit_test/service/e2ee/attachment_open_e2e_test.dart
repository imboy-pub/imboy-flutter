/// E2EE-061 Slice 6（上半）—— 发送侧封装 ↔ 接收侧开封的**端到端**验收
///
/// 这是本线第一次两侧真正对接：发送侧用 `ChatAttachmentHandler` 的判定与绑定
/// 输入封装，接收侧用 `AttachmentOpener` 从**消息本身**重算绑定值再开封。
/// 绑定值只要有一处推导不同，密文完好也打不开——所以这里的正向用例
/// 本身就是「两端一致」的证明。
///
/// 覆盖设计 §1 的威胁项：
/// - **ATT-01** 附件被搬到另一条消息 / 另一个会话 / 另一个发送者 → 拒绝；
/// - **ATT-02** 块重排 / 增删 / 截断 → 拒绝；
/// - **ATT-03** descriptor 字段被改（size / chunk_count / mime / name）→ 拒绝；
/// - **兼容性**：没有 descriptor 的历史明文附件仍可读。
library;

import 'dart:typed_data';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/service/e2ee/attachment_conversation_ref.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

const String kSender = '52278';
const String kReceiver = '53314';
const String kGroup = '900001';

Uint8List _plain(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 37 + 11) & 0xFF));

/// 发送侧：走 `ChatAttachmentHandler` 的真实判定与绑定推导
({Map<String, dynamic> payload, Uint8List objectBytes}) sendSide({
  required String messageId,
  required String chatType,
  required String peerId,
  required Uint8List plaintext,
  int chunkSize = 32,
  String attachmentId = 'image',
}) {
  final handler = ChatAttachmentHandler(
    peerId: peerId,
    type: chatType,
    conversationUk3: ConversationUk3Generator.generateSmart(
      type: chatType,
      currentUserId: kSender,
      peerId: peerId,
    ),
    currentUserOverride: const User(id: kSender, name: 'sender'),
    sealRollout: true,
    onMessageCreated: (Message m) async => true,
  );
  final AttachmentSealRequest? seal = ChatAttachmentHandler.buildSealRequest(
    rolloutEnabled: handler.sealRollout,
    payloadWillBeEncrypted: true,
    messageId: messageId,
    conversationId: handler.sealConversationId,
    senderUid: kSender,
    attachmentId: attachmentId,
  );
  final sealed = AttachmentEncryptor.seal(
    plaintext: plaintext,
    bindingHash: seal!.bindingHash,
    attachmentId: seal.attachmentId,
    objectKey: 'u$kSender/2026/07/a.bin',
    mime: 'image/jpeg',
    name: 'a.jpg',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: chunkSize,
  );
  return (
    payload: <String, dynamic>{
      'uri': sealed.descriptor.objectKey,
      AttachmentSealPolicy.descriptorPayloadKey: sealed.descriptor.toMap(),
    },
    objectBytes: sealed.ciphertext,
  );
}

/// 接收侧：只拿消息字段（id / type / from / to）重算，**不**碰发送侧的任何变量
Uint8List? recvSide({
  required Map<String, dynamic> payload,
  required Uint8List objectBytes,
  required String messageId,
  required String chatType,
  required String fromUid,
  required String toUid,
}) => AttachmentOpener.openForMessage(
  payload: payload,
  objectBytes: objectBytes,
  messageId: messageId,
  chatType: chatType,
  fromUid: fromUid,
  toUid: toUid,
);

void main() {
  group('1. 正向可用性：两端算出同一个绑定值，密文可开', () {
    test('C2C：收件人用消息字段重算即可开封，明文逐字节相同', () {
      final pt = _plain(100);
      final s = sendSide(
        messageId: 'msg-1',
        chatType: 'C2C',
        peerId: kReceiver,
        plaintext: pt,
      );
      final out = recvSide(
        payload: s.payload,
        objectBytes: s.objectBytes,
        messageId: 'msg-1',
        chatType: 'C2C',
        fromUid: kSender,
        toUid: kReceiver,
      );
      expect(out, equals(pt));
    });

    test('⚠️ C2G：群成员（既非发送者也不在 uk3 里）同样能开', () {
      final pt = _plain(70);
      final s = sendSide(
        messageId: 'msg-g',
        chatType: 'C2G',
        peerId: kGroup,
        plaintext: pt,
      );
      // 第三个成员：它算出的 conversationUk3 与发送者完全不同
      expect(
        ConversationUk3Generator.generateSmart(
          type: 'C2G',
          currentUserId: '777',
          peerId: kGroup,
        ),
        isNot(
          equals(
            ConversationUk3Generator.generateSmart(
              type: 'C2G',
              currentUserId: kSender,
              peerId: kGroup,
            ),
          ),
        ),
      );
      final out = recvSide(
        payload: s.payload,
        objectBytes: s.objectBytes,
        messageId: 'msg-g',
        chatType: 'C2G',
        fromUid: kSender,
        toUid: kGroup,
      );
      expect(out, equals(pt), reason: '群附件必须对每个成员都可读');
    });

    test('大于一块（多块 + 末块不满）也能完整还原', () {
      final pt = _plain(100);
      final s = sendSide(
        messageId: 'msg-m',
        chatType: 'C2C',
        peerId: kReceiver,
        plaintext: pt,
        chunkSize: 32, // 4 块，末块 4 字节
      );
      final out = recvSide(
        payload: s.payload,
        objectBytes: s.objectBytes,
        messageId: 'msg-m',
        chatType: 'C2C',
        fromUid: kSender,
        toUid: kReceiver,
      );
      expect(out, equals(pt));
    });
  });

  group('2. ATT-01：附件被搬走 → 拒绝', () {
    late ({Map<String, dynamic> payload, Uint8List objectBytes}) s;
    setUp(() {
      s = sendSide(
        messageId: 'msg-1',
        chatType: 'C2C',
        peerId: kReceiver,
        plaintext: _plain(100),
      );
    });

    test('搬到另一条消息（message_id 变）→ 拒绝', () {
      expect(
        () => recvSide(
          payload: s.payload,
          objectBytes: s.objectBytes,
          messageId: 'msg-OTHER',
          chatType: 'C2C',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('搬到另一个会话（对端换人）→ 拒绝', () {
      expect(
        () => recvSide(
          payload: s.payload,
          objectBytes: s.objectBytes,
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: kSender,
          toUid: '99999',
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('冒充另一个发送者 → 拒绝', () {
      expect(
        () => recvSide(
          payload: s.payload,
          objectBytes: s.objectBytes,
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: '99999',
          toUid: kReceiver,
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });
  });

  group('3. ATT-02：块被动过 → 拒绝', () {
    late ({Map<String, dynamic> payload, Uint8List objectBytes}) s;
    setUp(() {
      s = sendSide(
        messageId: 'msg-1',
        chatType: 'C2C',
        peerId: kReceiver,
        plaintext: _plain(100),
        chunkSize: 32,
      );
    });

    Uint8List mutate(void Function(Uint8List) f) {
      final copy = Uint8List.fromList(s.objectBytes);
      f(copy);
      return copy;
    }

    void expectRejected(Uint8List bytes) {
      expect(
        () => recvSide(
          payload: s.payload,
          objectBytes: bytes,
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    }

    test('翻一个 bit → 拒绝', () {
      expectRejected(mutate((b) => b[5] ^= 0x01));
    });

    test('两块整体互换 → 拒绝', () {
      const sealedLen = 32 + 16;
      expectRejected(
        mutate((b) {
          for (var i = 0; i < sealedLen; i++) {
            final t = b[i];
            b[i] = b[sealedLen + i];
            b[sealedLen + i] = t;
          }
        }),
      );
    });

    test('截断（少一块）→ 拒绝', () {
      expectRejected(
        Uint8List.fromList(
          s.objectBytes.sublist(0, s.objectBytes.length - (32 + 16)),
        ),
      );
    });

    test('追加一块（多出字节）→ 拒绝', () {
      expectRejected(
        Uint8List.fromList([...s.objectBytes, ...List<int>.filled(48, 0)]),
      );
    });
  });

  group('4. ATT-03：descriptor 字段被改（含一条能力边界对照组）', () {
    late ({Map<String, dynamic> payload, Uint8List objectBytes}) s;
    setUp(() {
      s = sendSide(
        messageId: 'msg-1',
        chatType: 'C2C',
        peerId: kReceiver,
        plaintext: _plain(100),
        chunkSize: 32,
      );
    });

    Map<String, dynamic> tampered(String key, Object? value) {
      final d = Map<String, dynamic>.from(
        s.payload[AttachmentSealPolicy.descriptorPayloadKey]
            as Map<String, dynamic>,
      );
      d[key] = value;
      return <String, dynamic>{
        ...s.payload,
        AttachmentSealPolicy.descriptorPayloadKey: d,
      };
    }

    void expectRejected(Map<String, dynamic> payload) {
      expect(
        () => recvSide(
          payload: payload,
          objectBytes: s.objectBytes,
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    }

    test('改 plain_size → 拒绝（chunk_count 自洽闸门先拦）', () {
      expectRejected(tampered('plain_size', 64));
    });

    test('改 chunk_count → 拒绝', () {
      expectRejected(tampered('chunk_count', 3));
    });

    test('⚠️ 对照组：改 mime **不**被本层拒绝（它不在块 AAD 内）', () {
      // 如实记录能力边界：mime / name 不进块 AAD，本层拦不住它们被改。
      // 它们的完整性由 **PFv3 对整个 payload 的认证**保证（descriptor 住在
      // 加密 payload 里），不是由附件分块 AEAD 保证。
      // 本例断言的是「改 mime 也拿不到别的内容」——即它不构成解密侧的口子。
      final out = recvSide(
        payload: tampered('mime', 'application/pdf'),
        objectBytes: s.objectBytes,
        messageId: 'msg-1',
        chatType: 'C2C',
        fromUid: kSender,
        toUid: kReceiver,
      );
      expect(out, equals(_plain(100)));
    });

    test('改 attachment_id → 拒绝（它进每块 AAD）', () {
      expectRejected(tampered('attachment_id', 'video'));
    });

    test('content_key 被换 → 拒绝', () {
      expectRejected(
        tampered('content_key', 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='),
      );
    });
  });

  group('5. 兼容性与 fail-closed', () {
    test('没有 descriptor → 返回 null（历史明文附件照旧直读）', () {
      expect(
        AttachmentOpener.descriptorFrom(<String, dynamic>{'uri': 'u1/a.jpg'}),
        isNull,
      );
      expect(
        AttachmentOpener.openForMessage(
          payload: <String, dynamic>{'uri': 'u1/a.jpg'},
          objectBytes: _plain(10),
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        isNull,
      );
    });

    test('⚠️ descriptor 存在但坏掉 → 抛异常，**绝不**退回明文直读', () {
      expect(
        () => AttachmentOpener.descriptorFrom(<String, dynamic>{
          AttachmentSealPolicy.descriptorPayloadKey: 'not-a-map',
        }),
        throwsA(isA<AttachmentOpenException>()),
        reason: '静默降级等于给攻击者一条把加密关掉的开关',
      );
      expect(
        () => AttachmentOpener.descriptorFrom(<String, dynamic>{
          AttachmentSealPolicy.descriptorPayloadKey: <String, dynamic>{
            'attachment_id': 'x',
          },
        }),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('库里读出的 Map<dynamic, dynamic>（含嵌套）也能解析', () {
      final s = sendSide(
        messageId: 'msg-1',
        chatType: 'C2C',
        peerId: kReceiver,
        plaintext: _plain(100),
      );
      final fromDb = <dynamic, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: <dynamic, dynamic>{
          ...s.payload[AttachmentSealPolicy.descriptorPayloadKey]
              as Map<String, dynamic>,
        },
      };
      final out = AttachmentOpener.openForMessage(
        payload: fromDb,
        objectBytes: s.objectBytes,
        messageId: 'msg-1',
        chatType: 'C2C',
        fromUid: kSender,
        toUid: kReceiver,
      );
      expect(out, equals(_plain(100)));
    });

    test('C2S / 未知会话类型 → 抛异常，不拿空串兜底', () {
      expect(
        () => AttachmentOpener.bindingFor(
          messageId: 'msg-1',
          chatType: 'C2S',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        throwsA(isA<AttachmentOpenException>()),
        reason: '空串会让同一发送者的所有附件共用一个绑定值，ATT-01 直接失效',
      );
    });
  });

  group('6. conversation_id 推导：发送侧 scope_ref 与接收侧同源', () {
    test('C2C：与 deriveUploadScope 的 scope_ref 同值（防两份实现漂移）', () {
      final s = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: 'C2C_${kSender}_$kReceiver',
        currentUid: kSender,
        peerId: kReceiver,
        type: 'C2C',
      );
      expect(
        s.scopeRef,
        equals(
          AttachmentConversationRef.of(
            chatType: 'C2C',
            fromUid: kSender,
            toUid: kReceiver,
          ),
        ),
      );
    });

    test('C2C：收发方向对调后同值', () {
      expect(
        AttachmentConversationRef.of(
          chatType: 'C2C',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        equals(
          AttachmentConversationRef.of(
            chatType: 'C2C',
            fromUid: kReceiver,
            toUid: kSender,
          ),
        ),
      );
    });

    test('C2G：等于 group_id；C2S/空 → null', () {
      expect(
        AttachmentConversationRef.of(
          chatType: 'C2G',
          fromUid: kSender,
          toUid: kGroup,
        ),
        equals(kGroup),
      );
      expect(
        AttachmentConversationRef.of(
          chatType: 'C2S',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        isNull,
      );
      expect(
        AttachmentConversationRef.of(
          chatType: 'C2C',
          fromUid: '',
          toUid: kReceiver,
        ),
        isNull,
      );
    });
  });
}
