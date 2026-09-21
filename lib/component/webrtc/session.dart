/// 1:1 通话会话标识（纯信令层数据类）。
///
/// LK-APP-01：1:1 媒体面已迁移 LiveKit SFU，会话不再持有
/// RTCPeerConnection / RTCDataChannel / ICE 候选缓存；保留 peerId/sid/media
/// 供信令路由与通话页接线使用。
class WebRTCSession {
  WebRTCSession({required this.peerId, required this.sid, this.media});

  /// 对端 uid
  final String peerId;

  /// 会话 id（双 uid 排序拼接，见 webrtc/func.dart sessionId）
  final String sid;

  /// 会话媒体类型：'audio' | 'video'，null 表示未指定
  String? media;
}
