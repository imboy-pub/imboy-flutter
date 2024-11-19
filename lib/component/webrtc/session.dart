import 'package:flutter_webrtc/flutter_webrtc.dart';

// ignore: must_be_immutable
class WebRTCSession {
  WebRTCSession({
    required this.peerId,
    required this.sid,
    this.pc,
    this.dc,
    // required this.media, // TODO 2022-11-16 00:08:17
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
