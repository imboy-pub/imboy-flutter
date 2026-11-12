/// 导出前 E2EE 会话判定（W3-J / chat_export_share_v1；W5-G3 复审 S1-L4 收紧）。
///
/// 只读复用既有判据（不新增加密逻辑），判定为「**任一命中即需确认**」：
///
/// 1. `E2EEService.shouldEncryptOutgoingPayload`（消息发送链路的会话加密
///    判定真源，部署级 policy + AI 明文门）——覆盖「当前策略要求加密」；
/// 2. **E2EE 历史行**（S1-L4）：本次导出消息中存在带 E2EE 元数据标记的
///    行（`metadata['e2ee']` 非空，或解密失败占位 `metadata['_e2ee_failed']`
///    ——占位行必为密文历史）。单靠 outgoing 判定的漏洞：部署级策略从
///    加密翻为不加密后，历史 E2EE 消息的导出会静默跳过「内容将离开加密
///    环境」确认——历史密文一旦落盘/分享，敏感性不因当前策略放松而消失。
///    判定只读 flow 已有的消息数据（消息级 metadata），**不引入新 DB 查询**。
///
/// - `interactiveConfirm: false`：判定语境非 UI 确认，绝不触发 AI 明文
///   绑定弹窗（只读判定）；
/// - 判定抛异常（policy 未初始化 fail-closed 等）→ **按需确认处理**：
///   宁可多弹一次「内容将离开加密环境」确认，不漏弹（导出是读操作，
///   多确认无害；漏确认才是安全事故）。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;

import 'package:imboy/service/e2ee_service.dart';

/// 目标会话当前是否需要「内容将离开加密环境」确认（导出确认门用）。
///
/// [messages] 为本次导出的消息集（flow 已有数据，只读其 metadata）。
Future<bool> isEncryptedConversationForExport({
  required String chatType,
  String? toId,
  List<core.Message> messages = const <core.Message>[],
}) async {
  try {
    final outgoingNeedsConfirm = await E2EEService.shouldEncryptOutgoingPayload(
      chatType,
      toId: toId,
      interactiveConfirm: false,
    );
    if (outgoingNeedsConfirm) return true;
  } on Object {
    // policy 未初始化等：fail-closed，宁可多确认。
    return true;
  }
  // 当前策略不要求加密：仍需扫历史行——本次导出消息里存在 E2EE 历史
  // （密文行 / 解密失败占位行）时同样必须确认（S1-L4）。
  return messages.any(hasE2eeHistoryMarker);
}

/// 消息级 E2EE 历史标记（只读 metadata，无副作用；测试直接断言用——
/// 不加 @visibleForTesting 注解：本仓测试可见性约定走 foundation 再导出，
/// 此处保持零 Flutter import，命名即约定）：
/// - `metadata['e2ee']` 非空（Map/String 均认）：行上携带 e2ee 元数据；
/// - `metadata['_e2ee_failed'] == true`：解密失败占位行（必为密文历史）。
bool hasE2eeHistoryMarker(core.Message message) {
  final metadata = message.metadata;
  if (metadata == null) return false;
  if (metadata['_e2ee_failed'] == true) return true;
  final e2ee = metadata['e2ee'];
  if (e2ee is Map) return e2ee.isNotEmpty;
  if (e2ee is String) return e2ee.isNotEmpty;
  return false;
}
