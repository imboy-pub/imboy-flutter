/// E2EE-061 —— 附件密文块的 AAD 绑定值（方案甲，2026-07-30 人工拍板）
///
/// ## 为什么不是 PFv3 的 `header_hash`
///
/// 设计 §2.1 原本要求绑 `header_hash`。**已实证不可实现**，两条独立原因：
///
/// 1. 附件上传发生在消息组装**之前**（`attachment_handler.dart` 先上传拿 meta，
///    之后才建消息），上传时 header 尚不存在；
/// 2. **决定性**：`chat_network_service.dart` 是**逐收件设备**建信封的循环，
///    `session_ref` 逐设备不同 ⇒ 一条消息有 **N 个 header_hash**，
///    而附件对象**只有一份**。绑其中任一个，其余设备必然打不开。
///
/// 详见 `evidence/E2EE-061-slice4-blocked-header-hash-binding.md`。
///
/// ## 方案甲绑什么
///
/// `binding = SHA-256(canonical_cbor({message_id, conversation_id, sender_uid}))`
///
/// 三个值**上传前即可确定、且全设备一致**：
/// - 附件搬到另一条消息 → `message_id` 变 → AAD 失配（**ATT-01**）；
/// - 搬到另一个会话 / 换发送方 → 另两项变 → 同样失配。
///
/// ⚠️ **已知代价（拍板时接受）**：绑定强度弱于原设计——不含 `message_type` /
/// `action` / `created_at_ms` / `session_ref` / `epoch_or_counter`。
/// descriptor 本身仍在 PFv3 加密 payload 内、仍受**完整** header 认证，
/// 因此改写 descriptor 仍不可行。
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

/// 绑定值构造违规。
class AttachmentBindingException implements Exception {
  final String message;
  AttachmentBindingException(this.message);
  @override
  String toString() => 'AttachmentBindingException: $message';
}

class AttachmentBinding {
  /// 域分隔串：防止本结构被当作别的上下文的 canonical 输入复用。
  static const String domain = 'imboy/e2ee/attachment-binding/v1';

  /// 计算 32 字节绑定值。
  ///
  /// 三项**均不得为空**：空 `message_id` 会让同一会话内所有附件共用同一绑定值，
  /// ATT-01 直接失效。fail-closed 放在构造处，任何调用点漏传都立刻炸，
  /// 而不是静默产出一个「谁都能打开」的绑定——这正是 E2EE-025 里
  /// `sessionRef: ''` 那次事故的同类。
  static Uint8List compute({
    required String messageId,
    required String conversationId,
    required String senderUid,
  }) {
    if (messageId.isEmpty) {
      throw AttachmentBindingException('message_id 不得为空');
    }
    if (conversationId.isEmpty) {
      throw AttachmentBindingException('conversation_id 不得为空');
    }
    if (senderUid.isEmpty) {
      throw AttachmentBindingException('sender_uid 不得为空');
    }

    // 复用 PFv3 已在产的 canonical CBOR：长度前缀天然无歧义，
    // 不引入第三套编码（与 Slice 2 的 AAD 同源）。
    final canonical = CanonicalCbor.encode({
      'ctx': domain,
      'message_id': messageId,
      'conversation_id': conversationId,
      'sender_uid': senderUid,
    });
    return Uint8List.fromList(sha256.convert(canonical).bytes);
  }
}
