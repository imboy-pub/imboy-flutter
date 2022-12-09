import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/counter.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:xid/xid.dart';

class P2pCallScreenLogic extends getx.GetxController {
  // WebRTCSignaling signaling = Get.find<WebRTCSignaling>(tag: 'p2psignaling');

  var showTool = true.obs;

  // 最小化的
  var minimized = false.obs;
  var stateTips = "".obs;

  var switchRenderer = true.obs;

  var cameraOff = false.obs;
  var microphoneOff = false.obs;
  var speakerOn = true.obs;
  //
  getx.Rx<double> localX = 0.0.obs;
  getx.Rx<double> localY = 0.0.obs;

  // 计时器
  getx.Rx<Counter> counter = Counter(count: 0).obs;

  //////// view line
  getx.Rx<RTCVideoRenderer> localRenderer = RTCVideoRenderer().obs;
  getx.Rx<RTCVideoRenderer> remoteRenderer = RTCVideoRenderer().obs;

  getx.Rx<String> sessionid = "".obs;

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

  Function? closePage;
  late Map<String, dynamic> iceServers;

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
      'OfferToReceiveAudio': true,
      // 是否接受视频数据
      'OfferToReceiveVideo': true,
      // https://github.com/flutter-webrtc/flutter-webrtc/issues/509
      'IceRestart': true,
    },
    'optional': [],
  };

  // bool callee = false;
  var connected = false.obs;
  var makingAnswer = false.obs;
  var makingOffer = false.obs;
  var ignoreOffer = false.obs;
  var isSettingRemoteAnswerPending = false.obs;
  bool isPolite;

  final mediaConstraints = <String, dynamic>{
    'audio': true,
    'video': true,
  };
  P2pCallScreenLogic(
    this.from,
    this.to,
    this.media,
    this.isPolite,
    this.iceServers, {
    this.micoff = true,
  });

  Future<void> signalingConnect() async {
    _socket = WSService.to;
    WSService.to.openSocket();
    counter.value.close();
  }

  @override
  @mustCallSuper
  void onInit() async {
    super.onInit();
    initRenderers();
    // 接收到新的消息订阅
    eventBus
        .on<WebRTCSignalingModel>()
        .listen((WebRTCSignalingModel obj) async {
      // ignore: prefer_interpolation_to_compose_strings
      debugPrint("> rtc logic onInit listen " + obj.toJson().toString());
      onMessage(obj);
    });
    debugPrint("> rtc logic onInit ");

    onSignalingStateChange = (RTCSignalingState state) async {
      debugPrint("> rtc onSignalingStateChange logic ${state.toString()}");
    };

    onPeersUpdate = ((event) {
      debugPrint("> rtc _connect onPeersUpdate");
      // setState(() {
      //   peers = event['peers'];
      // });
    });

    onLocalStream = ((stream) async {
      debugPrint("> rtc onLocalStream");
      localStream ??= stream;
      if (localRenderer.value.textureId == null) {
        await localRenderer.value.initialize();
      }
      localRenderer.value.setSrcObject(stream: stream);
      localRenderer.refresh();
    });

    onAddRemoteStream = ((WebRTCSession sess, stream) async {
      debugPrint("> rtc onAddRemoteStream ${stream.toString()} , ${sess.sid}");
      sessionid.value = sess.sid;
      sessionid.refresh();
      if (remoteRenderer.value.textureId == null) {
        await remoteRenderer.value.initialize();
      }
      remoteRenderer.value.setSrcObject(stream: stream);
      remoteRenderer.refresh();
    });

    onRemoveRemoteStream = ((WebRTCSession sess, stream) {
      debugPrint("> rtc _connect onRemoveRemoteStream , ${sess.sid}");
      sessionid.value = sess.sid;
      sessionid.refresh();
      remoteRenderer.value.srcObject = null;
      remoteRenderer.refresh();
    });
  }

  // 设置Renderers
  initRenderers() async {
    await localRenderer.value.initialize();
    localRenderer.refresh();
    await remoteRenderer.value.initialize();
    remoteRenderer.refresh();
  }

  void onMessage(WebRTCSignalingModel msg) async {
    var data = msg.payload;

    debugPrint("> rtc logic onMessage ${msg.webrtctype}: ${data.toString()}");
    switch (msg.webrtctype) {
      case 'offer': // 收到from 发送的 offer
        {
          // sd = session description
          var description = data['sd'];
          var media = data['media'];
          var sessionId = data['sid'];

          var rtcSession = sessions[sessionId];

          if (rtcSession == null) {
            rtcSession = await createSession(
                peerId: msg.from,
                sessionId: sessionId,
                media: media,
                screenSharing: false);
            sessions[sessionId] = rtcSession;
            makingAnswer = true.obs;
          }

          await _onReceivedDescription(rtcSession, media, description);
        }
        break;
      case 'answer':
        {
          // sd = session description
          var description = data['sd'];
          var sessionId = data['sid'];

          var session = sessions[sessionId];

          debugPrint("> rtc recive answer ${session.toString()}");
          if (session == null) {
            session = await createSession(
              peerId: msg.from,
              sessionId: sessionId,
              media: media,
              screenSharing: false,
            );
            sessions[sessionId] = session;
          }
          await _onReceivedDescription(session, media, description);
          onCallStateChange?.call(
            session,
            WebRTCCallState.CallStateConnected,
          );
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

          debugPrint(
              "> rtc candidate sessionId $sessionId, peerid $peerId, s ${session.toString()}");
          if (session != null) {
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
          closeSessionByPeerId(peerId);
        }
        break;
      case 'bye':
        {
          var sessionId = data['sid'];
          var session = sessions.remove(sessionId);
          debugPrint("> rtc logic bye $sessionId : $session");
          if (session != null) {
            closeSession(session);
            onCallStateChange?.call(session, WebRTCCallState.CallStateBye);
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

  /// 切换本地相机
  /// Switch local camera
  switchCamera() {
    if (localStream != null) {
      Helper.switchCamera(localStream!.getVideoTracks()[0]);
    }
  }

  /// 开关扬声器/耳机
  /// Switch speaker/earpiece
  switchSpeaker() {
    if (localStream != null) {
      speakerOn.value = !speakerOn.value;
      MediaStreamTrack audioTrack = localStream!.getAudioTracks()[0];
      audioTrack.enableSpeakerphone(speakerOn.value);
      _debug(
          "> rtc switchSpeaker" + (speakerOn.value ? "speaker" : "earpiece"));
    }
  }

  Future<MediaStream> createStream(String media) async {
    debugPrint("> rtc createStream sdpSemantics");
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': media == "video"
          ? {
              'mandatory': {
                // Provide your own width, height and frame rate here
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };
    MediaStream stream = await navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );
    onLocalStream?.call(stream);
    return stream;
  }

  Future<WebRTCSession> createSession({
    required String peerId,
    required String sessionId,
    required String media,
    required bool screenSharing,
  }) async {
    var newSession = WebRTCSession(
      sid: sessionId,
      pid: peerId,
    );
    debugPrint(
        "> rtc _createSession media: $media ; sid: $sessionId; iceServers： $iceServers; newSession $newSession");

    if (media != 'data' && localStream == null) {
      localStream = await createStream(media);
    }
    RTCPeerConnection pc = await createPeerConnection({
      ...iceServers,
      ...{'sdpSemantics': 'unified-plan'}
    }, _config);
    if (media != 'data') {
      pc.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video') {
          debugPrint('> rtc onTrack: ${event.toString()}');
          remoteStreams.add(event.streams[0]);
          onAddRemoteStream?.call(newSession, event.streams[0]);
        }
      };
      localStream!.getTracks().forEach((track) {
        pc.addTrack(track, localStream!);
      });
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) async {
      debugPrint('> rtc onIceCandidate: ${candidate.toMap().toString()}');
      if (candidate == null) {
        debugPrint('> rtc onIceCandidate: empty!');
        return;
      }
      _send('candidate', {
        'candidate': {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        },
        'sid': sessionId,
      });
    };

    pc.onSignalingState = (RTCSignalingState state) {
      debugPrint('> rtc onSignalingState: ${state.toString()}');
      onSignalingStateChange?.call(state);
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('> rtc onIceConnectionState: ${state.toString()}');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        pc.restartIce();
      }
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
    pc.onRenegotiationNeeded = _onRenegotiationNeeded;
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

  /// 打开或关闭本地视频
  /// Open or close local video
  turnCamera() {
    if (localStream!.getVideoTracks().isNotEmpty) {
      var muted = !cameraOff.value;
      cameraOff.value = muted;
      localStream!.getVideoTracks()[0].enabled = !muted;
    } else {
      _debug(":::Unable to operate the camera:::");
    }
  }

  /// 打开或关闭本地麦克风
  /// Open or close local microphone
  turnMicrophone() {
    debugPrint("> rtc turnMicrophone");
    if (localStream != null && localStream!.getAudioTracks().isNotEmpty) {
      bool muted = !microphoneOff.value;
      microphoneOff.value = muted;
      localStream!.getAudioTracks()[0].enabled = !muted;
      _debug("> rtc The microphone is ${muted ? 'muted' : 'unmuted'}:::");
    }
  }

  /// 退出之前清理打开的资源
  cleanUp() async {
    await cleanSessions();

    counter.value.close();
    if (localRenderer.value.srcObject != null) {
      localRenderer.value.srcObject = null;
      await localRenderer.value.dispose();
      localRenderer.refresh();
    }
    if (remoteRenderer.value.srcObject != null) {
      remoteRenderer.value.srcObject = null;
      await remoteRenderer.value.dispose();
      remoteRenderer.refresh();
    }
    connected = false.obs;
    connected.refresh();
    p2pCallScreenOn = false;
    if (closePage != null) {
      closePage?.call();
    }
  }

  _debug(String message) {
    debugPrint(message);
  }

  hangUp() {
    // if (value != null) {
    //   bye(session.value!.sid);
    // }
    getx.Get.dialog(AlertDialog(
        title: const Text("Hangup"),
        content: const Text("Are you sure to leave the room?"),
        actions: <Widget>[
          TextButton(
            child: const Text("Cancel"),
            onPressed: () {
              getx.Get.back();
            },
          ),
          TextButton(
            child: const Text(
              "Hangup",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              // Get.toNamed("/login");
              cleanUp();
            },
          )
        ]));
  }

  /// 邀请对端通话
  void invitePeer(String peerId, String media) async {
    debugPrint("> rtc invitePeer $peerId $media");
    if (peerId != UserRepoLocal.to.currentUid) {
      invite(peerId, media);
    }
  }

  /// 邀请会话
  /// invite
  Future<void> invite(String peerId, String media) async {
    String sessionId = "$from-$peerId";
    // sessionId = "kybqdp-7b4v1b";
    debugPrint("> rtc invite sessionId $sessionId");
    WebRTCSession session = await createSession(
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
    onCallStateChange?.call(session, WebRTCCallState.CallStateInvite);
  }

  Future<void> _createOffer(WebRTCSession s, String media) async {
    debugPrint("> rtc _createOffer media $media sid ${s.sid}");
    try {
      makingOffer = true.obs;
      s.pc!.createOffer(media == 'data' ? _dcConstraints : {}).then((sd) async {
        await s.pc!.setLocalDescription(sd);

        await _send('offer', {
          'sd': {'sdp': sd.sdp, 'type': sd.type},
          'sid': s.sid,
          'media': media,
        });
      });
    } catch (e) {
      debugPrint("> rtc _createOffer err $e");
    } finally {
      debugPrint("> rtc _createOffer finally");
      makingOffer = false.obs;
    }
  }

  Future<void> _createDataChannel(WebRTCSession session,
      {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.pc!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }

  void bye(String sessionId) {
    _send('bye', {
      'sid': sessionId,
    });
    cleanUp();
  }

  /// 切换工具栏
  void switchTools() {
    update([
      showTool.value = !showTool.value,
    ]);
  }

  _send(String event, Map payload) {
    Map request = {};
    request["ts"] = DateTimeHelper.currentTimeMillis();
    request["id"] = Xid().toString();
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

  @override
  void onClose() {
    cleanUp();
    super.onClose();
  }

  Future<void> _onReceivedDescription(
    var session,
    String media,
    Map description,
  ) async {
    debugPrint("> rtc _onReceivedDescription start _peerConnection=" +
        session.pc.toString());

    // this code implements the "polite peer" principle, as described here:
    // https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Perfect_negotiation
    try {
      String type = description['type'];
      var offerCollision = (type.toLowerCase() == 'offer') &&
          (makingOffer.isTrue ||
              (session.pc!.signalingState !=
                      RTCSignalingState.RTCSignalingStateStable ||
                  session.pc!.signalingState != null));

      debugPrint("> rtc onReceivedDescription offerCollision: " +
          offerCollision.toString());

      ignoreOffer.value = !isPolite && offerCollision;

      debugPrint("> rtc l              state: " +
          session.pc!.signalingState.toString());
      debugPrint("> rtc l        makingOffer: " + makingOffer.toString());
      debugPrint("> rtc l     offerCollision: " + offerCollision.toString());
      debugPrint("> rtc l        ignoreOffer: " + ignoreOffer.toString());
      debugPrint("> rtc l             polite: " + isPolite.toString());

      if (ignoreOffer.isTrue) {
        debugPrint("> rtc onReceivedDescription offer ignored");
        return;
      }

      await session.pc!.setRemoteDescription(
        RTCSessionDescription(
          description['sdp'],
          description['type'],
        ),
      ); // SRD rolls back as needed

      if (description['type'] == "offer") {
        debugPrint("> rtc onReceivedDescription received offer");
        await session.pc!.setLocalDescription(
            await session.pc!.createAnswer(mediaConstraints));
        var localDesc = await session.pc!.getLocalDescription();
        await _send('answer', {
          'media': media,
          'sid': session.sid,
          'sd': {'sdp': localDesc!.sdp, 'type': localDesc.type},
        });

        if (session.remoteCandidates.isNotEmpty) {
          for (var candidate in session.remoteCandidates) {
            await session.pc?.addCandidate(candidate);
          }
          session.remoteCandidates.clear();
        }
        onCallStateChange?.call(
          session,
          WebRTCCallState.CallStateConnected,
        );
        debugPrint("> rtc onReceivedDescription answer sent");
      }
    } catch (e) {
      debugPrint("> rtc e" + e.toString());
    }
  }

  void _onRenegotiationNeeded() async {
    debugPrint('> rtc onRenegotiationNeeded start');
    var session = sessions[sessionid.value] ?? null;
    if (session == null || makingAnswer.value || makingOffer.value) {
      return;
    }
    try {
      makingOffer = true.obs;
      await session.pc!
          .setLocalDescription(await session.pc!.createOffer(mediaConstraints));
      debugPrint(
          '> rtc onRenegotiationNeeded state after setLocalDescription: ' +
              session.pc!.signalingState.toString());
      // send offer via callManager
      var localDesc = await session.pc!.getLocalDescription();

      // _send('offer', {
      //   'sd': {'sdp': localDesc!.sdp, 'type': localDesc.type},
      //   'sid': sessionid,
      //   'media': media,
      // });
      await _send('answer', {
        'media': media,
        'sid': session.sid,
        'sd': {'sdp': localDesc!.sdp, 'type': localDesc.type},
      });
      // callManager.sendCallMessage(
      //     MsgType.rtc_offer, RtcOfferAnswer(localDesc.sdp, localDesc.type));
      debugPrint('> rtc onRenegotiationNeeded; offer sent');
    } catch (e) {
      debugPrint("> rtc onRenegotiationNeeded error: " + e.toString());
    } finally {
      makingOffer = false.obs;
      debugPrint('> rtc onRenegotiationNeeded done');
    }
  }
}
