import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/provider/user_provider.dart';

enum WebRTCSignalingState {
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

enum WebRTCCallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
}

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
}

class WebRTCSignaling {
  WebRTCSignaling(
    this.from,
    this.to, {
    this.micoff = true,
  });

  final JsonEncoder _encoder = const JsonEncoder();
  final String from;
  final String to;
  final bool micoff;
  late WSService _socket;
  var _turnCredential;
  Map<String, WebRTCSession> sessions = {};
  MediaStream? localStream;
  final List<MediaStream> remoteStreams = <MediaStream>[];

  Function(WebRTCSignalingState state)? onSignalingStateChange;
  Function(WebRTCSession session, WebRTCCallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(WebRTCSession session, MediaStream stream)? onAddRemoteStream;
  Function(WebRTCSession session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(
          WebRTCSession session, RTCDataChannel dc, RTCDataChannelMessage data)?
      onDataChannelMessage;
  Function(WebRTCSession session, RTCDataChannel dc)? onDataChannel;

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'url': STUN_URL,
      },
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    // 如果要与浏览器互通，需要设置DtlsSrtpKeyAgreement为true
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      // 是否接受语音数据
      'OfferToReceiveAudio': false,
      // 是否接受视频数据
      'OfferToReceiveVideo': true,
      // https://github.com/flutter-webrtc/flutter-webrtc/issues/509
      'IceRestart': true,
    },
    'optional': [],
  };

  close() async {
    await _cleanSessions();
    // _socket.close();
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
    String sessionId = from + '-' + peerId;
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
    _createOffer(session, media);
    debugPrint(">>> ws rtc cc ${DateTime.now()} invite _createOffer end ");
    onCallStateChange?.call(session, WebRTCCallState.CallStateNew);
    onCallStateChange?.call(session, WebRTCCallState.CallStateInvite);
  }

  void bye(String sessionId) {
    _send('bye', {
      'sid': sessionId,
    });
    var sess = sessions[sessionId];
    if (sess != null) {
      _closeSession(sess);
    }
  }

  void accept(String sessionId) {
    var session = sessions[sessionId];
    if (session == null) {
      return;
    }
    _createAnswer(session, 'video');
  }

  void reject(String sessionId) {
    var session = sessions[sessionId];
    if (session == null) {
      return;
    }
    bye(session.sid);
  }

  void onMessage(WebRTCSignalingModel msg) async {
    var data = msg.payload;

    debugPrint(
        ">>> ws rtc revice ${msg.webrtctype} payload ${data.toString()}");
    switch (msg.webrtctype) {
      case 'peers':
        {
          Map peers = data;
          if (onPeersUpdate != null) {
            Map<String, dynamic> event = Map<String, dynamic>();
            event['peers'] = peers;
            onPeersUpdate?.call(event);
          }
        }
        break;
      case 'offer': // 收到from 发送的 offer
        {
          // sd = session description
          var description = data['sd'];
          var media = data['media'];
          var sessionId = data['sid'];
          reciveOffer(to, description, media, sessionId);
        }
        break;
      case 'answer':
        {
          // sd = session description
          var description = data['sd'];
          var sessionId = data['sid'];
          var session = sessions[sessionId];
          debugPrint(
              ">>> ws rtc cc answer sid ${sessionId} ; ${session.toString()}");
          session?.pc?.setRemoteDescription(RTCSessionDescription(
            description['sdp'],
            description['type'],
          ));
          onCallStateChange?.call(session!, WebRTCCallState.CallStateConnected);
          // sessions[sessionId] = session;
        }
        break;
      case 'candidate':
        {
          var peerId = msg.from;
          var candidateMap = data['candidate'];
          var sessionId = data['sid'];
          var session = sessions[sessionId];
          RTCIceCandidate candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );

          if (session != null) {
            debugPrint(
                ">>> ws rtc candidate sessionId $sessionId, peerid ${peerId}, s ${session.pc.toString()}");
            if (session.pc != null) {
              await session.pc?.addCandidate(candidate);
            } else {
              session.remoteCandidates.add(candidate);
            }
          } else {
            sessions[sessionId] = WebRTCSession(
              pid: peerId,
              sid: sessionId,
            )..remoteCandidates.add(candidate);
          }
        }
        break;
      case 'leave':
        {
          var peerId = msg.from;
          _closeSessionByPeerId(peerId);
        }
        break;
      case 'bye':
        {
          var sessionId = data['sid'];
          var session = sessions.remove(sessionId);
          if (session != null) {
            onCallStateChange?.call(session, WebRTCCallState.CallStateBye);
            _closeSession(session);
          }
        }
        break;
      case 'keepalive':
        {
          debugPrint('keepalive response!');
        }
        break;
      default:
        break;
    }
  }

  Future<void> connect() async {
    _socket = WSService.to;
    debugPrint(">>> ws rtc connect");
    if (_turnCredential == null) {
      try {
        _turnCredential = await UserProvider().turnCredential();
        _iceServers = {
          'iceServers': [
            {
              'url': STUN_URL,
            },
            {
              // 'urls': _turnCredential['uris'][0],
              'urls': [TURN_URL],
              "ttl": 86400,
              'username': _turnCredential['username'],
              'credential': _turnCredential['credential']
            },
          ],
          'iceTransportPolicy': 'relay',
        };
        debugPrint(
            ">>> ws rtc connect _turnCredential ${_turnCredential.toString()} ; _iceServers: ${_iceServers.toString()}");
      } catch (e) {}
    }
    WSService.to.openSocket();

    onSignalingStateChange?.call(WebRTCSignalingState.ConnectionOpen);

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
    final Map<String, dynamic> mediaConstraints = {
      // 'audio': micoff ? false : true,
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

    debugPrint(
        ">>> ws rtc createStream media: $media, s ${mediaConstraints.toString()}");
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
        ">>> ws rtc _createSession sdpSemantics $sdpSemantics ; media: $media ; sid: ${sessionId}; session： ${session.toString()}; newSession ${newSession.toString()}");

    if (media != 'data') {
      localStream = await createStream(media);
    }
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
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
        case 'unified-plan':
          // Unified-Plan
          pc.onTrack = (event) {
            if (event.track.kind == 'video') {
              remoteStreams.add(event.streams[0]);
              onAddRemoteStream?.call(newSession, event.streams[0]);
            }
          };
          localStream!.getTracks().forEach((track) {
            pc.addTrack(track, localStream!);
          });
          break;
      }
    }

    pc.onIceCandidate = (candidate) async {
      if (candidate == null) {
        debugPrint('onIceCandidate: complete!');
        return;
      }

      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      await Future.delayed(
          const Duration(milliseconds: 0),
          () => _send('candidate', {
                'candidate': {
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                  'sdpMid': candidate.sdpMid,
                  'candidate': candidate.candidate,
                },
                'sid': sessionId,
              }));
    };

    pc.onIceConnectionState = (state) {};

    pc.onRemoveStream = (stream) {
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
      {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.pc!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }

  Future<void> _createOffer(WebRTCSession s, String media) async {
    debugPrint(">>> ws rtc invite _createOffer media $media ");
    try {
      RTCSessionDescription sd =
          await s.pc!.createOffer(media == 'data' ? _dcConstraints : {});
      await s.pc!.setLocalDescription(sd);
      _send('offer', {
        'sd': {'sdp': sd.sdp, 'type': sd.type},
        'sid': s.sid,
        'media': media,
      });
    } catch (e) {
      debugPrint(">>> ws rtc invite _createOffer err " + e.toString());
    }
  }

  Future<void> _createAnswer(WebRTCSession session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc!.createAnswer(media == 'data' ? _dcConstraints : {});
      await session.pc!.setLocalDescription(s);
      _send('answer', {
        'media': media,
        'sid': session.sid,
        'sd': {'sdp': s.sdp, 'type': s.type},
      });
    } catch (e) {
      debugPrint(">>> ws rtc answer _createAnswer $media e " + e.toString());
      debugPrint(
          ">>> ws rtc answer session: ${session.toString()}, pc: ${session.pc!.toString()}",
          wrapWidth: 2048);
    }
  }

  _send(String event, Map payload) {
    Map request = {};
    request["ts"] = DateTimeHelper.currentTimeMillis();
    request["to"] = to;
    request["from"] = from;
    request["type"] = "webrtc_" + event;
    request["payload"] = payload;
    debugPrint('>>> ws rtc cc _send $event ${request.toString()}');
    _socket.sendMessage(_encoder.convert(request));
  }

  Future<void> _cleanSessions() async {
    if (localStream != null) {
      localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await localStream!.dispose();
      localStream = null;
    }
    sessions.forEach((key, sess) async {
      await sess.pc?.close();
      await sess.dc?.close();
    });
    sessions.clear();
  }

  void _closeSessionByPeerId(String peerId) {
    WebRTCSession? session;
    sessions.removeWhere((String key, WebRTCSession sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      _closeSession(session!);
      onCallStateChange?.call(session!, WebRTCCallState.CallStateBye);
    }
  }

  Future<void> _closeSession(WebRTCSession session) async {
    localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await localStream?.dispose();
    localStream = null;

    await session.pc?.close();
    await session.dc?.close();
  }

  Future<void> reciveOffer(
    String peerId,
    Map<String, dynamic> description,
    String media,
    String sessionId,
  ) async {
    var session = sessions[sessionId];

    var newSession = await createSession(session,
        peerId: peerId,
        sessionId: sessionId,
        media: media,
        screenSharing: false);
    sessions[sessionId] = newSession;
    await newSession.pc?.setRemoteDescription(RTCSessionDescription(
      description['sdp'],
      description['type'],
    ));

    // await _createAnswer(newSession, media);

    if (newSession.remoteCandidates.isNotEmpty) {
      for (var candidate in newSession.remoteCandidates) {
        await newSession.pc?.addCandidate(candidate);
      }
      newSession.remoteCandidates.clear();
    }
    onCallStateChange?.call(newSession, WebRTCCallState.CallStateNew);
    onCallStateChange?.call(newSession, WebRTCCallState.CallStateRinging);
  }
}
