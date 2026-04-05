import 'package:flutter_webrtc/flutter_webrtc.dart';

// ignore: must_be_immutable
class WebRTCSession {
  WebRTCSession({
    required this.peerId,
    required this.sid,
    this.pc,
    this.dc,
    // DONE(2026-04-04): 添加 media 属性支持多媒体类型标识
    this.media,
  });

  // peerId
  final String peerId;

  // sessionId
  final String sid;

  /// 会话媒体类型：'audio' | 'video'，null 表示未指定
  String? media;

  RTCPeerConnection? pc;
  RTCDataChannel? dc;

  List<RTCIceCandidate> remoteCandidates = [];

  //
  // @override
  // List<Object?> get props => [pid, sid, pc, dc, remoteCandidates];
}
