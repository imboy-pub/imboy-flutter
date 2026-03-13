import 'package:flutter_webrtc/flutter_webrtc.dart';

// ignore: must_be_immutable
class WebRTCSession {
  WebRTCSession({
    required this.peerId,
    required this.sid,
    this.pc,
    this.dc,
    // TODO(功能扩展): 添加 media 属性支持多媒体类型标识
    // 如需区分 audio-only/video/audio-video 会话，取消注释：
    // required this.media,
  });

  // peerId
  final String peerId;

  // sessionId
  final String sid;

  // video audio data
  // String media;

  RTCPeerConnection? pc;
  RTCDataChannel? dc;

  List<RTCIceCandidate> remoteCandidates = [];

  //
  // @override
  // List<Object?> get props => [pid, sid, pc, dc, remoteCandidates];
}
