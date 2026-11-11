/// 导出前 E2EE 会话判定（W3-J / chat_export_share_v1）。
///
/// 只读复用既有判据（不新增加密逻辑）：`E2EEService.shouldEncryptOutgoingPayload`
/// 是消息发送链路的会话加密判定真源（部署级 policy + AI 明文门），对
/// 「该会话的消息是否端到端加密」给出同一口径的答案。
///
/// - `interactiveConfirm: false`：判定语境非 UI 确认，绝不触发 AI 明文
///   绑定弹窗（只读判定）；
/// - 判定抛异常（policy 未初始化 fail-closed 等）→ **按加密会话处理**：
///   宁可多弹一次「内容将离开加密环境」确认，不漏弹（导出是读操作，
///   多确认无害；漏确认才是安全事故）。
library;

import 'package:imboy/service/e2ee_service.dart';

/// 目标会话当前是否为 E2EE 加密会话（导出确认门用）。
Future<bool> isEncryptedConversationForExport({
  required String chatType,
  String? toId,
}) async {
  try {
    return await E2EEService.shouldEncryptOutgoingPayload(
      chatType,
      toId: toId,
      interactiveConfirm: false,
    );
  } on Object {
    return true;
  }
}
