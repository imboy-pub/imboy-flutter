/// WebSocket 入站 action-ACK 转发策略（纯函数，零外部依赖）。
///
/// 传输层对 `*_ACK` 帧统一做出站确认清除（停重发）后，默认不再转发给
/// MessageService。但 `message_revoke_ack` / `message_edit_ack` 的本机效应
/// （原消息转已撤回/已编辑 + UI 刷新）在 `MessageActions` 的 ack 分支完成，
/// 必须放行——否则发送方气泡在服务端已确认后仍永不更新（J18.c 真机复现）。
library;

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
