import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/websocket.dart';

enum WebRTCCallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
}

// ignore: must_be_immutable
class WebRTCSession {
  WebRTCSession({
    required this.pid,
    required this.sid,
  });
  // peerId
  String pid;
  // sessionId
  String sid;
  RTCPeerConnection? pc;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
//
// @override
// List<Object?> get props => [pid, sid, pc, dc, remoteCandidates];
}

class WebRTCSignaling extends getx.GetxController {
  final JsonEncoder _encoder = const JsonEncoder();
  final String from;
  final String to;
  final String media; // video audio data

  final bool micoff;
  late WSService _socket;
  Map<String, WebRTCSession> sessions = {};
  MediaStream? localStream;
  final List<MediaStream> remoteStreams = <MediaStream>[];

  Function(RTCSignalingState state)? onSignalingStateChange;
  Function(WebRTCSession session, WebRTCCallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(WebRTCSession session, MediaStream stream)? onAddRemoteStream;
  Function(WebRTCSession session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(
    WebRTCSession session,
    RTCDataChannel dc,
    RTCDataChannelMessage data,
  )? onDataChannelMessage;
  Function(WebRTCSession session, RTCDataChannel dc)? onDataChannel;

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  Map<String, dynamic> iceServers;

  final Map<String, dynamic> _config = {
    'mandatory': {},
// 如果要与浏览器互通，需要设置DtlsSrtpKeyAgreement为true
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  Map<String, dynamic> _dcConstraints = {
    'mandatory': {
// 是否接受语音数据
      'OfferToReceiveAudio': true,
// 是否接受视频数据
      'OfferToReceiveVideo': true,
// https://github.com/flutter-webrtc/flutter-webrtc/issues/509
      'IceRestart': true,
    },
    'optional': [],
  };

  WebRTCSignaling(
    this.from,
    this.to,
    this.media,
    this.iceServers, {
    this.micoff = true,
  });

  @override
  @mustCallSuper
  void onInit() async {
    super.onInit();

    _dcConstraints = {
      'mandatory': {
// 是否接受语音数据
        'OfferToReceiveAudio': micoff,
// 是否接受视频数据
        'OfferToReceiveVideo': true,
// https://github.com/flutter-webrtc/flutter-webrtc/issues/509
        'IceRestart': true,
      },
      'optional': [],
    };
  }

  close() async {
    await cleanSessions();
  }

  void switchCamera() {
    if (localStream != null) {
      Helper.switchCamera(localStream!.getVideoTracks()[0]);
    }
  }

  void muteMic() {
    if (localStream != null && localStream!.getAudioTracks().isNotEmpty) {
      bool enabled = localStream!.getAudioTracks()[0].enabled;
      localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }

  /// 邀请会话
  /// invite
  Future<void> invite(String peerId, String media) async {
    String sessionId = "$from-$peerId";
    // sessionId = "kybqdp-7b4v1b";
    debugPrint("> rtc invite sessionId $sessionId");
    WebRTCSession session = await createSession(
      null,
      peerId: peerId,
      sessionId: sessionId,
      media: media,
      screenSharing: false,
    );

    sessions[sessionId] = session;
    if (media == 'data') {
      _createDataChannel(session);
    }
    await _createOffer(session, media);
// onCallStateChange?.call(session, WebRTCCallState.CallStateNew);
    onCallStateChange?.call(session, WebRTCCallState.CallStateInvite);
  }

  void bye(String sessionId) {
    _send('bye', {
      'sid': sessionId,
    });
    var sess = sessions[sessionId];
    if (sess != null) {
      closeSession(sess);
    }
  }

  Future<void> accept(String sessionId, String media) async {
    var session = sessions[sessionId];
    debugPrint("> rtc accept signaling  $session");
    if (session == null) {
      return;
    }
    createAnswer(session, media);
  }

  void reject(String sessionId) {
    var session = sessions[sessionId];
    if (session == null) {
      return;
    }
    bye(session.sid);
  }

  Future<void> signalingConnect() async {
    _socket = WSService.to;
    WSService.to.openSocket();

// _send('authenticate', {
//   'username': UserRepoLocal.to.currentUser.account,
//   'password': 'password',
// });

// _socket.onMessage = (message) {
//   debugPrint('Received data: ' + message);
//   onMessage(_decoder.convert(message));
// };

// _socket.onError = (int? code, String? reason) {
//   debugPrint('Closed by server [$code => $reason]!');
//   onSignalingStateChange?.call(SignalingState.ConnectionClosed);
// };
// await _socket.onOpen();
  }

  Future<MediaStream> createStream(String media) async {
    debugPrint("> rtc createStream sdpSemantics");
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    MediaStream stream = await navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );
    onLocalStream?.call(stream);
    return stream;
  }

  Future<WebRTCSession> createSession(
    WebRTCSession? session, {
    required String peerId,
    required String sessionId,
    required String media,
    required bool screenSharing,
  }) async {
    var newSession = session ??
        WebRTCSession(
          sid: sessionId,
          pid: peerId,
        );
    debugPrint(
        "> rtc _createSession sdpSemantics $sdpSemantics ; media: $media ; sid: $sessionId; session： $session; newSession $newSession");

    if (media != 'data' && localStream == null) {
      localStream = await createStream(media);
    }
    RTCPeerConnection pc = await createPeerConnection({
      ...iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    if (media != 'data') {
      switch (sdpSemantics) {
        case 'plan-b':
          pc.onAddStream = (MediaStream stream) {
            onAddRemoteStream?.call(newSession, stream);
            remoteStreams.add(stream);
          };
          await pc.addStream(localStream!);
          break;
        case 'unified-plan': // Unified-Plan
          pc.onTrack = (RTCTrackEvent event) {
            if (event.track.kind == 'video') {
              // remoteStreams.add(event.streams[0]);
              onAddRemoteStream?.call(newSession, event.streams[0]);
            }
          };
          localStream!.getTracks().forEach((track) {
            pc.addTrack(track, localStream!);
          });
          break;
      }
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) async {
      debugPrint('> rtc onIceCandidate: ${candidate.toMap().toString()}');
      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      await Future.delayed(
          const Duration(milliseconds: 100),
          () => _send('candidate', {
                'candidate': {
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                  'sdpMid': candidate.sdpMid,
                  'candidate': candidate.candidate,
                },
                'sid': sessionId,
              }));
    };

    pc.onSignalingState = (RTCSignalingState state) {
      debugPrint('> rtc onSignalingState: ${state.toString()}');
      onSignalingStateChange?.call(state);
    };

    pc.onIceConnectionState = (state) {
      debugPrint('> rtc onIceConnectionState: ${state.toString()}');
    };

    pc.onRemoveStream = (stream) {
      debugPrint('> rtc onRemoveStream: ${stream.toString()}');
      onRemoveRemoteStream?.call(newSession, stream);
      remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    newSession.pc = pc;
    return newSession;
  }

  void _addDataChannel(WebRTCSession session, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(session, channel, data);
    };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  Future<void> _createDataChannel(WebRTCSession session,
      {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.pc!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }

  Future<void> _createOffer(WebRTCSession s, String media) async {
    debugPrint("> rtc _createOffer media $media sid ${s.sid}");
    try {
      s.pc!.createOffer(media == 'data' ? _dcConstraints : {}).then((sd) async {
        await s.pc!.setLocalDescription(sd);

        _send('offer', {
          'sd': {'sdp': sd.sdp, 'type': sd.type},
          'sid': s.sid,
          'media': media,
        });
      });
    } catch (e) {
      debugPrint("> rtc _createOffer err $e");
    }
  }

  Future<void> createAnswer(WebRTCSession session, String media) async {
    debugPrint(
        "> rtc accept createAnswer ${session.pc.toString()} state ${session.pc!.connectionState}");
    try {
      session.pc!
          .createAnswer(media == 'data' ? _dcConstraints : {})
          .then((RTCSessionDescription sd) async {
        await session.pc!.setLocalDescription(sd);
        _send('answer', {
          'media': media,
          'sid': session.sid,
          'sd': {'sdp': sd.sdp, 'type': sd.type},
        });
      });
    } catch (e) {
      debugPrint("> rtc createAnswer media $media e $e");
      debugPrint(
          "> rtc createAnswer session: ${session.toString()}, pc: ${session.pc!.toString()}",
          wrapWidth: 2048);
    }
  }

  _send(String event, Map payload) {
    Map request = {};
    request["ts"] = DateTimeHelper.currentTimeMillis();
    request["to"] = to;
    request["from"] = from;
    request["type"] = "webrtc_$event";
    request["payload"] = payload;
    debugPrint('> rtc _send $event ${request.toString()}');
    _socket.sendMessage(_encoder.convert(request));
  }

  Future<void> cleanSessions() async {
    if (localStream != null) {
      localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await localStream!.dispose();
      localStream = null;
    }
    sessions.forEach((key, sess) async {
      sess.pc?.onIceCandidate = null;
      sess.pc?.onTrack = null;
      await sess.pc?.close();
      await sess.pc?.dispose();
      await sess.dc?.close();
    });
    sessions.clear();
  }

  void closeSessionByPeerId(String peerId) {
    WebRTCSession? session;
    sessions.removeWhere((String key, WebRTCSession sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      closeSession(session!);
      onCallStateChange?.call(session!, WebRTCCallState.CallStateBye);
    }
  }

  Future<void> closeSession(WebRTCSession session) async {
    localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await localStream?.dispose();
    localStream = null;

    await session.pc?.close();
    await session.dc?.close();
  }
}
