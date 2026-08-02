import 'package:imboy/component/webrtc/session.dart';

/// 判断一条 offer 是否属于当前已展示的通话。
///
/// ICE restart 会使用独立的消息 envelope id，因此不能用消息 id 判断；
/// 必须匹配 payload.call_id 与当前会话保存的原始通话 ID。
bool isActiveWebRtcCallOffer({
  required bool hasCallOverlay,
  required String peerId,
  required String callId,
  required Iterable<WebRTCSession> sessions,
}) {
  if (!hasCallOverlay || peerId.isEmpty || callId.isEmpty) return false;
  return sessions.any(
    (session) => session.peerId == peerId && session.callId == callId,
  );
}
