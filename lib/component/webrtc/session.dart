import 'package:flutter_webrtc/flutter_webrtc.dart';

// ignore: must_be_immutable
class WebRTCSession {
  WebRTCSession({
    required this.pid,
    required this.sid,
    // required this.media, // TODO 2022-11-16 00:08:17
  });
  // peerId
  String pid;
  // sessionId
  String sid;
  // video audio data
  // String media;

  RTCPeerConnection? pc;
  RTCDataChannel? dc;

  //
  // @override
  // List<Object?> get props => [pid, sid, pc, dc, remoteCandidates];
}
