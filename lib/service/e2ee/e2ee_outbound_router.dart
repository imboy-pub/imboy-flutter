/// E2EE 发送侧路由（ADR 02 §4 / ADR 05 §4.2）。
///
/// 业务层只传入已选定的 [ProtocolSuite]；本路由通过
/// [E2eeProtocolRegistry] 找到协议插件并补齐双写期的通用信封。
///
/// S2.1: [encryptV3] 使用 Protected Frame v3（ADR 15）包装密文，
/// 将 protected_header 与 payload 一同加密，实现路由字段认证。
library;

import 'dart:convert';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'dart:typed_data';

import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

/// E2EE-027: 出站 immutable 密文无法提交到事务存储。
///
/// ADR 14 §8「CryptoStore 提交失败」→ 消息保留"未发送"。抛出此异常意味着
/// **调用方不得发送**：密文没有落到 outbox，崩溃后既无投递也无重发依据，
/// 而用户界面会显示"已发送"。
class E2eeOutboxCommitException implements Exception {
  const E2eeOutboxCommitException(this.message);
  final String message;
  @override
  String toString() => 'E2eeOutboxCommitException: $message';
}

class E2eeOutboundRouter {
  const E2eeOutboundRouter._();

  /// v2 加密路径（向后兼容，meta_version=2）。
  static Future<E2eeCiphertext> encrypt({
    required ProtocolSuite suite,
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
    int? createdAtMs,
  }) async {
    final protocol = E2eeProtocolRegistry.resolve({
      'protocol': suite.protocol,
      'version': suite.version,
    });
    if (protocol.suite != suite) {
      throw StateError(
        'E2EE suite mismatch: selected=$suite, registered=${protocol.suite}',
      );
    }
    final encrypted = await protocol.encrypt(
      plaintext: plaintext,
      recipients: recipients,
      context: context,
    );
    final metadata = <String, dynamic>{
      ...encrypted.metadata,
      'e2ee': true,
      'e2ee_ver': suite.protocol == ProtocolSuite.rsa.protocol ? 1 : 2,
      'e2ee_suite': suite.legacyWire,
      'meta_version': 2,
      'protocol': suite.protocol,
      'version': suite.version,
      'cipher': suite.cipher,
      'created_at': createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    };
    return E2eeCiphertext(encrypted.ciphertext, metadata);
  }

  /// v3 加密路径（ADR 15 Protected Frame v3）。
  ///
  /// 与 [encrypt] 的区别：
  /// 1. 构造 canonical CBOR protected_header 并绑定到 inner_frame；
  /// 2. 加密对象是完整 inner_frame（header + payload），而非裸 payload；
  /// 3. 返回的 metadata 是 v3 外层信封（meta_version=3）；
  /// 4. ciphertext 字段在 metadata 内（base64url），外层 ciphertext 为空字符串。
  ///
  /// [messageId] 全局消息 ID（TSID 十进制字符串）。
  /// [senderUid] 发送者 UID（十进制字符串）。
  /// [senderDid] 发送者设备 ID。
  /// [destination] 对端 UID 或 GID。
  /// [messageType] 业务消息类型（text/image/...）。
  /// [action] 消息动作（message/room_key/...）。
  /// [sessionRef] 协议会话标识（Olm session ID / Megolm session ID）。
  /// [epochOrCounter] MLS epoch 或应用去重计数。
  static Future<E2eeCiphertext> encryptV3({
    required ProtocolSuite suite,
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
    required String messageId,
    required String senderUid,
    required String senderDid,
    required String destination,
    required String messageType,
    required String action,
    required String sessionRef,
    int epochOrCounter = 0,
    int? createdAtMs,
  }) async {
    final protocol = E2eeProtocolRegistry.resolve({
      'protocol': suite.protocol,
      'version': suite.version,
    });
    if (protocol.suite != suite) {
      throw StateError(
        'E2EE suite mismatch: selected=$suite, registered=${protocol.suite}',
      );
    }

    final now = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final scope = context.scope == 'c2c'
        ? FrameScope.c2c
        : context.scope == 'c2g'
        ? FrameScope.group
        : FrameScope.control;

    // conversation_id: C2C 为排序后 uid 对，群为 gid
    final conversationId = scope == FrameScope.group
        ? (context.gid ?? destination)
        : _c2cConversationId(senderUid, destination);

    final frameContext = FrameContext(
      messageId: messageId,
      scope: scope,
      conversationId: conversationId,
      senderUid: senderUid,
      senderDid: senderDid,
      destination: destination,
      messageType: messageType,
      action: action,
      createdAtMs: now,
      protocol: suite.protocol,
      protocolVersion: suite.version,
      sessionRef: sessionRef,
      epochOrCounter: epochOrCounter,
    );

    // 构造 inner_frame（ADR 15 §3.2）并 CBOR 编码
    final header = ProtectedFrameV3.buildProtectedHeader(frameContext);
    final innerFrame = <String, dynamic>{
      'v': 3,
      'protected_header': header,
      'payload': jsonDecode(plaintext),
    };
    final innerFrameCbor = CanonicalCbor.encode(innerFrame);
    final innerFrameB64 = base64Url.encode(innerFrameCbor);

    // 加密完整 inner_frame
    final encrypted = await protocol.encrypt(
      plaintext: innerFrameB64,
      recipients: recipients,
      context: context,
    );

    // 构造 v3 外层信封
    final ciphertextBytes = Uint8List.fromList(
      utf8.encode(encrypted.ciphertext),
    );
    final protocolMetadata = Map<String, dynamic>.from(encrypted.metadata);

    final envelope = ProtectedFrameV3.encodeOuterEnvelope(
      context: frameContext,
      ciphertext: ciphertextBytes,
      protocolMetadata: protocolMetadata,
    );

    // E2EE-027: 加密后先把 immutable 密文落 outbox，**再**允许调用方发送
    // （ADR 20 §S2.3）。fail-closed：无法提交就抛错，不返回可发送信封——否则
    // 崩溃后消息既未投递也无重发依据，用户却看到"已发送"（ADR 14 §8）。
    //
    // 写入错误一律向上传播，不得 catch 后照常返回（静默吞错即 fail-open）。
    final db = await SqliteService.to.db;
    if (db == null) {
      throw const E2eeOutboxCommitException(
        'crypto store unavailable; refusing to hand out sendable ciphertext',
      );
    }
    final store = CryptoStore(db);
    await store.ensureSchema();
    await store.insertOutbox(id: messageId, payload: jsonEncode(envelope));

    // v3: ciphertext 在 envelope 内，外层 E2eeCiphertext.ciphertext 为空
    return E2eeCiphertext('', envelope);
  }

  /// C2C conversation_id: 两个 UID 排序后拼接（确定性，双方计算结果相同）
  static String _c2cConversationId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}:${sorted[1]}';
  }
}
