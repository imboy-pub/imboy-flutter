/// WebSocket 入站 action-ACK 转发策略（纯函数，零外部依赖）。
///
/// 传输层对 `*_ACK` 帧统一做出站确认清除（停重发）后，默认不再转发给
/// MessageService。但 `message_revoke_ack` / `message_edit_ack` 的本机效应
/// （原消息转已撤回/已编辑 + UI 刷新）在 `MessageActions` 的 ack 分支完成，
/// 必须放行——否则发送方气泡在服务端已确认后仍永不更新（J18.c 真机复现）。
library;

import 'package:imboy/service/protocol/imboy_frame.dart';

/// 限制二进制帧总长，v2 封包额度包含固定头部。
bool isInboundFrameSizeAllowed(List<int> bytes, {required bool usesV2Frame}) {
  if (bytes.length <= ImboyFrame.maxPayload) return true;
  return usesV2Frame &&
      bytes.length <= ImboyFrame.maxPayload + ImboyFrame.headerSize &&
      bytes[0] == (ImboyFrame.magic >> 8) &&
      bytes[1] == (ImboyFrame.magic & 0xFF);
}

/// 按 UTF-8 字节数限制原始文本帧，无需分配编码后的副本。
bool isInboundTextSizeAllowed(String text) {
  if (text.length <= ImboyFrame.maxPayload ~/ 3) return true;
  if (text.length > ImboyFrame.maxPayload) return false;

  var byteCount = 0;
  for (final rune in text.runes) {
    if (rune <= 0x7F) {
      byteCount++;
    } else if (rune <= 0x7FF) {
      byteCount += 2;
    } else if (rune <= 0xFFFF) {
      byteCount += 3;
    } else {
      byteCount += 4;
    }
    if (byteCount > ImboyFrame.maxPayload) return false;
  }
  return true;
}

/// 流式增量是瞬态帧。其他 S2C/C2S 业务帧仍遵循收据合同。
bool shouldAcknowledgeBusinessFrame(String messageType, Object? messageKind) =>
    (messageType == 'S2C' || messageType == 'C2S') &&
    messageKind != 'stream_delta';

/// 需放行到 MessageService 的 action-ACK（与 [isAckSwallowedByTransport] 的
/// 入参一样按大写归一比较）。
const Set<String> kActionAcksWithLocalEffect = {
  'MESSAGE_REVOKE_ACK',
  'MESSAGE_EDIT_ACK',
};

/// 入站帧的 [normalizedAction]（已 `toUpperCase()`）是否应在传输层终止、
/// 不再转发给 MessageService。
///
/// - `CLIENT_ACK_CONFIRM` / `CLIENT_ACK_ERROR`：入站收据确认，传输层已处理完。
/// - 其他 `*_ACK`：默认终止；[kActionAcksWithLocalEffect] 例外放行。
/// - 非 ACK action（含空串）：一律放行。
bool isAckSwallowedByTransport(String normalizedAction) {
  if (normalizedAction == 'CLIENT_ACK_CONFIRM' ||
      normalizedAction == 'CLIENT_ACK_ERROR') {
    return true;
  }
  return normalizedAction.endsWith('_ACK') &&
      !kActionAcksWithLocalEffect.contains(normalizedAction);
}
