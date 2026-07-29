/// E2EE-061 Slice 6（上半）—— 接收侧：从消息取 descriptor、重算绑定值、开封
///
/// 这是 [ChatAttachmentHandler] 封装动作的**镜像**。两侧必须对同一条消息算出
/// **同一个**绑定值，否则密文完好也打不开；因此 `conversation_id` 的推导
/// 两侧共用 [AttachmentConversationRef]（唯一真值源），本模块不另写一份。
///
/// ## 两条 fail-closed 的取舍
///
/// 1. **没有 descriptor ≠ 出错**：历史明文附件必须仍可读（设计 §4 兼容性约束），
///    故 [descriptorFrom] 返回 null 表示「这是明文对象，照旧直读」；
/// 2. **有 descriptor 但坏掉 = 出错**：**绝不**退回明文直读。
///    静默降级会把「密文被篡改成看起来不像 descriptor 的样子」变成
///    「当明文渲染一堆乱字节」，等于给攻击者一条把加密关掉的开关。
///
/// ⚠️ 完整性门本身在 [AttachmentEncryptor.open]（块数量/每块 tag/明文大小/
/// 明文 SHA-256 全过才返回），本模块只负责**把正确的输入喂给它**。
library;

import 'dart:typed_data';

import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_conversation_ref.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

/// 接收侧无法开封时抛出。**不细分原因**：具体哪一步不过不应成为 oracle。
class AttachmentOpenException implements Exception {
  final String message;
  AttachmentOpenException(this.message);
  @override
  String toString() => 'AttachmentOpenException: $message';
}

class AttachmentOpener {
  /// 从消息 payload 里取 descriptor。
  ///
  /// - 字段不存在 → `null`（明文对象，走今天的直读路径）；
  /// - 字段存在但不是 map / 解析不过 → **抛异常**（见文件头取舍 2）。
  static AttachmentDescriptor? descriptorFrom(Object? payload) {
    if (!AttachmentSealPolicy.carriesContentKey(payload)) return null;
    final raw = (payload as Map)[AttachmentSealPolicy.descriptorPayloadKey];
    if (raw is! Map) {
      throw AttachmentOpenException('attachment_descriptor 不是 map');
    }
    // 库/网络来的常是 Map<dynamic, dynamic>，严格 parser 要 Map<String, dynamic>。
    // 只做键类型规整，**不**做任何值的强制转换——那正是严格 parser 要拦的东西。
    try {
      return AttachmentDescriptor.fromMap(_deepStringKeys(raw));
    } on AttachmentDescriptorException catch (e) {
      throw AttachmentOpenException('descriptor 非法: ${e.message}');
    }
  }

  static Map<String, dynamic> _deepStringKeys(Map<Object?, Object?> raw) {
    final Map<String, dynamic> m = <String, dynamic>{};
    raw.forEach((k, v) {
      m['$k'] = v is Map ? _deepStringKeys(v) : v;
    });
    return m;
  }

  /// 重算绑定值（方案甲）。[fromUid] / [toUid] 就是消息的 `from` / `to`。
  ///
  /// 推不出稳定的会话标识（C2S / 未知类型）时抛异常，**不**用空串兜底——
  /// 空串会让同一发送者的所有附件共用一个绑定值，ATT-01 直接失效。
  static Uint8List bindingFor({
    required String messageId,
    required String chatType,
    required String fromUid,
    required String toUid,
  }) {
    final String? conv = AttachmentConversationRef.of(
      chatType: chatType,
      fromUid: fromUid,
      toUid: toUid,
    );
    if (conv == null || conv.isEmpty) {
      throw AttachmentOpenException('推不出 conversation_id: chatType=$chatType');
    }
    try {
      return AttachmentBinding.compute(
        messageId: messageId,
        conversationId: conv,
        senderUid: fromUid,
      );
    } on AttachmentBindingException catch (e) {
      throw AttachmentOpenException('绑定值算不出来: ${e.message}');
    }
  }

  /// 生产入口：给定一条收到的消息与下载到的对象字节，返回**已完整校验**的明文。
  ///
  /// [payload] 无 descriptor 时返回 null，表示「这是明文对象，[ciphertext]
  /// 本身就是内容」——调用方照旧直读，历史附件不受影响。
  static Uint8List? openForMessage({
    required Object? payload,
    required Uint8List objectBytes,
    required String messageId,
    required String chatType,
    required String fromUid,
    required String toUid,
  }) {
    final descriptor = descriptorFrom(payload);
    if (descriptor == null) return null;
    final binding = bindingFor(
      messageId: messageId,
      chatType: chatType,
      fromUid: fromUid,
      toUid: toUid,
    );
    try {
      return AttachmentEncryptor.open(
        ciphertext: objectBytes,
        descriptor: descriptor,
        bindingHash: binding,
      );
    } on AttachmentSealException catch (e) {
      // 收敛成本模块的异常类型：调用方只需要知道「不可读」，
      // 不需要（也不应该）按失败原因分支。
      throw AttachmentOpenException(e.message);
    }
  }
}
