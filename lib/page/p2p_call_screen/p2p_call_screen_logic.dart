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

  final String from; // current user id
  final String to; // peer id
  final String media; // video audio data

  final bool micoff;
  late WSService _socket;

  Map<String, WebRTCSession> sessions = {};
  MediaStream? _localStream;
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
  late Map<String, dynamic> iceConfiguration;

  final Map<String, dynamic> offerSdpConstraints = {
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
  //
  bool makingOffer = false;
  bool ignoreOffer = false;
  bool isSettingRemoteAnswerPending = false;
  bool isPolite;

  final mediaConstraints = <String, dynamic>{
    'audio': true,
    'video': true,
  };
  P2pCallScreenLogic(
    // current user id
    this.from,
    // peer id
    this.to,
    this.iceConfiguration, {
    // video audio data
    this.media = 'video',
    this.isPolite = true,
    this.micoff = true,
  });

  Future<void> signalingConnect() async {
    debugPrint("> rtc logic signalingConnect");
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
      debugPrint("> rtc ${DateTime.now()} listen " + obj.toJson().toString());
      try {
        onMessage(obj);
      } catch (e) {
        debugPrint("> rtc ${DateTime.now()} listen error " + e.toString());
      }
    });
    debugPrint("> rtc logic onInit ${DateTime.now()}");

    // OnSignalingChange：信令状态改变。
    onSignalingStateChange = (RTCSignalingState state) async {
      debugPrint(
          "> rtc onSignalingStateChange ${DateTime.now()} state ${state.toString()}");
    };

    onPeersUpdate = ((event) {
      debugPrint("> rtc onPeersUpdate ${DateTime.now()} event $event ");
    });

    onLocalStream = ((stream) async {
      debugPrint("> rtc onLocalStream ${DateTime.now()}");
      _localStream ??= stream;
      if (localRenderer.value.textureId == null) {
        await localRenderer.value.initialize();
      }
      if (localRenderer.value.srcObject?.id != stream.id) {
        localRenderer.value.setSrcObject(stream: stream);
        localRenderer.refresh();
      }
    });

    onAddRemoteStream = ((WebRTCSession sess, stream) async {
      // 收到对方音频/视频流数据
      debugPrint(
          "> rtc onAddRemoteStream ${DateTime.now()} ${remoteRenderer.value.textureId} , ${sess.sid == sessionid.value} , stream ${stream.id}");
      if (remoteRenderer.value.textureId == null) {
        await remoteRenderer.value.initialize();
      }
      debugPrint(
          "> rtc onAddRemoteStream ${remoteRenderer.value.textureId} before ${DateTime.now()}, stream ${stream.id == remoteRenderer.value.srcObject?.id}");
      if (remoteRenderer.value.srcObject?.id != stream.id) {
        sessionid.value = sess.sid;
        remoteRenderer.value.setSrcObject(stream: stream);
        remoteRenderer.refresh();
      }
      debugPrint(
          "> rtc onAddRemoteStream ${remoteRenderer.value.textureId} after ${DateTime.now()}, stream ${stream.id == remoteRenderer.value.srcObject?.id}");
    });

    onRemoveRemoteStream = ((WebRTCSession sess, stream) {
      debugPrint("> rtc onRemoveRemoteStream , ${sess.sid} ${DateTime.now()}");
      remoteRenderer.value.dispose();
      remoteRenderer.refresh();
    });
  }

  // 设置Renderers
  initRenderers() async {
    if (localRenderer.value.textureId == null) {
      await localRenderer.value.initialize();
    }
    if (remoteRenderer.value.textureId == null) {
      await remoteRenderer.value.initialize();
    }
  }

  void onMessage(WebRTCSignalingModel msg) async {
    debugPrint(
        "> rtc onMessage ${msg.webrtctype}: ${DateTime.now()} ${msg.toJson().toString()}");
    if (msg.webrtctype == 'offer' || msg.webrtctype == 'answer') {
      onReceivedDescription(msg);
    } else if (msg.webrtctype == 'candidate') {
      String peerId = msg.from;
      String sid = msg.payload['sid'];
      sessionid.value = sid;
      var candidateMap = msg.payload['candidate'];
      var session = sessions[sid];
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );

      debugPrint("> rtc candidate peerid $peerId, s ${session.toString()}");
      if (session != null) {
        debugPrint(
            "> rtc candidate peerid $peerId, s.pc ${session.pc.toString()}");
        if (session.pc != null) {
          // addCandidate is addIceCandidate ? TODO leeyi 2022-12-13
          await session.pc?.addCandidate(candidate);
          session.remoteCandidates.clear();
        } else {
          session.remoteCandidates.add(candidate);
        }
      } else {
        sessions[sid] = await _createSession(
            peerId: msg.from,
            sessionId: sid,
            media: media,
            screenSharing: false)
          ..remoteCandidates.add(candidate);
      }
    } else if (msg.webrtctype == 'bye') {
      String sid = msg.payload['sid'];
      var session = sessions.remove(sid);
      debugPrint("> rtc logic bye $sid : $session");
      if (session == null) {
        cleanUp();
      } else {
        onCallStateChange?.call(session, WebRTCCallState.CallStateBye);
      }
    } else if (msg.webrtctype == 'leave') {
      String peerId = msg.from;
      closeSessionByPeerId(peerId);
    } else if (msg.webrtctype == 'keepalive') {
    } else if (msg.webrtctype == 'keepalive') {}
  }

  Future<void> onReceivedDescription(WebRTCSignalingModel msg) async {
    String sid = msg.payload['sid'];
    String peerId = msg.from;
    String m = msg.payload['media'] ?? media;
    sessionid.value = sid;
    var session = sessions[sid];
    if (session == null) {
      session = await _createSession(
        peerId: peerId,
        sessionId: sid,
        media: m,
        screenSharing: false,
      );
      sessions[sid] = session;
    }
    // sd = session description
    var sd = msg.payload['sd'];
    // this code implements the "polite peer" principle, as described here:
    // https://w3c.github.io/webrtc-pc/#peer-to-peer-connections
    String type = sd['type'].toString().toLowerCase();
    // An offer may come in while we are busy processing SRD(answer).
    // In this case, we will be in "stable" by the time the offer is processed
    // so it is safe to chain it on our Operations Chain now.
    bool readyForOffer = !makingOffer &&
        (session.pc!.signalingState ==
                RTCSignalingState.RTCSignalingStateStable ||
            isSettingRemoteAnswerPending);
    bool offerCollision = type == 'offer' && !readyForOffer;

    debugPrint(
        "> rtc onReceivedDescription offerCollision: ${DateTime.now()} " +
            offerCollision.toString());

    ignoreOffer = !isPolite && offerCollision;

    debugPrint("> rtc l              state: ${DateTime.now()} " +
        session.pc!.signalingState.toString());
    debugPrint("> rtc l        makingOffer: " + makingOffer.toString());
    debugPrint("> rtc l     offerCollision: " + offerCollision.toString());
    debugPrint("> rtc l        ignoreOffer: " + ignoreOffer.toString());
    debugPrint("> rtc l             polite: " + isPolite.toString());

    if (ignoreOffer) {
      debugPrint("> rtc onReceivedDescription $type ignored ${DateTime.now()}");
      return;
    }
    isSettingRemoteAnswerPending = type == 'answer';
    // unified-plan 语法下，该回调方法才会被触发 onTrack
    await session.pc!.setRemoteDescription(
      RTCSessionDescription(
        sd['sdp'],
        sd['type'],
      ),
    ); // SRD rolls back as needed
    isSettingRemoteAnswerPending = false;

    if (type == 'offer') {
      debugPrint(
          "> rtc onReceivedDescription received offer ${DateTime.now()}");
      // 此方法触发 onIceCandidate
      await session.pc!.setLocalDescription(
        await session.pc!.createAnswer(mediaConstraints),
      );
      var localDesc = await session.pc!.getLocalDescription();
      await _send('answer', {
        'media': media,
        'sid': session.sid,
        'sd': {'sdp': localDesc!.sdp, 'type': localDesc.type},
      });

      debugPrint("> rtc onReceivedDescription answer sent ${DateTime.now()}");
      if (session.remoteCandidates.isNotEmpty) {
        for (var candidate in session.remoteCandidates) {
          // addCandidate is addIceCandidate ? TODO leeyi 2022-12-13
          await session.pc?.addCandidate(candidate);
        }
        session.remoteCandidates.clear();
      }
      // 外呼=。New + Invite
      // 呼入=。New + Ringing
      onCallStateChange?.call(session, WebRTCCallState.CallStateNew);
      onCallStateChange?.call(session, WebRTCCallState.CallStateRinging);
    } else {
      // recive answer
      onCallStateChange?.call(
        session,
        WebRTCCallState.CallStateConnected,
      );
    }
  }

  Future<MediaStream> _createStream(String media) async {
    debugPrint("> rtc createStream sdpSemantics ${DateTime.now()}");
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': media == 'video'
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

  Future<WebRTCSession> _createSession({
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
        "> rtc _createSession ${DateTime.now()} sid: $sessionId; iceConfiguration： $iceConfiguration; newSession $newSession");

    if (media != 'data' && _localStream == null) {
      _localStream = await _createStream(media);
    }
    RTCPeerConnection pc =
        await createPeerConnection(iceConfiguration, offerSdpConstraints);
    if (media != 'data') {
      // 该方法在收到的信令指示一个transceiver将从远端接收媒体时被调用，实际就是在调用 SetRemoteDescription 时被触发。
      // 该接收track可以通过transceiver->receiver()->track()方法被访问到，其关联的streams可以通过transceiver->receiver()->streams()获取。
      // 只有在 unified-plan 语法下，该回调方法才会被触发。
      pc.onTrack = (RTCTrackEvent event) {
        debugPrint(
            "> rtc onTrack ${event.track.kind} ${DateTime.now()} ${event.track.toString()}");
        // 收到对方音频/视频流数据
        if (event.track.kind == 'video') {
          debugPrint('> rtc onTrack pc: ${event.toString()}');
          onAddRemoteStream?.call(newSession, event.streams[0]);
        }
      };
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    // Unified-Plan: Simuclast
    /*
    await pc.addTransceiver(
      track: _localStream!.getAudioTracks()[0],
      init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendOnly, streams: [_localStream!]),
    );

    await pc.addTransceiver(
      track: _localStream!.getVideoTracks()[0],
      init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendOnly,
          streams: [
            _localStream!
          ],
          sendEncodings: [
            RTCRtpEncoding(rid: 'f', active: true),
            RTCRtpEncoding(
              rid: 'h',
              active: true,
              scaleResolutionDownBy: 2.0,
              maxBitrate: 150000,
            ),
            RTCRtpEncoding(
              rid: 'q',
              active: true,
              scaleResolutionDownBy: 4.0,
              maxBitrate: 100000,
            ),
          ]),
    );
    */
    // 收集到一个新的ICE候选项时触发
    // ice 收集是由 setLocalDescription 触发，主/被叫都是
    pc.onIceCandidate = (RTCIceCandidate candidate) async {
      debugPrint(
          '> rtc pc onIceCandidate: ${DateTime.now()} ${candidate.toMap().toString()}');
      if (candidate.candidate == null) {
        debugPrint('> rtc pc onIceCandidate: complete!');
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

      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      // await Future.delayed(const Duration(milliseconds: 500), () {
      //   _send('candidate', {
      //     'candidate': {
      //       'sdpMLineIndex': candidate.sdpMLineIndex,
      //       'sdpMid': candidate.sdpMid,
      //       'candidate': candidate.candidate,
      //     },
      //     'sid': sessionId,
      //   });
      // });
    };
    // flutter-webrtc 貌似没有定义实现 onIceCandidateError
    // pc.onIceCandidateError = () {};
    // 信令状态改变 等价 OnSignalingChange
    pc.onSignalingState = (RTCSignalingState state) {
      debugPrint(
          '> rtc pc onSignalingState: ${DateTime.now()} ${state.toString()}');
      onSignalingStateChange?.call(state);
    };
    // PeerConnection状态改变 等价 OnConnectionChange
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint(
          '> rtc pc onIceConnectionState: ${DateTime.now()} ${state.toString()}');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        pc.restartIce();
      }
    };

    // 收到远端Peer的一个新stream
    pc.onAddStream = (stream) async {
      debugPrint(
          '> rtc pc onAddStream: ${DateTime.now()} ${stream.toString()}');
      if (remoteRenderer.value.textureId == null) {
        await remoteRenderer.value.initialize();
      }
      if (remoteRenderer.value.srcObject?.id != stream.id) {
        remoteRenderer.value.srcObject = stream;
        remoteRenderer.refresh();
      }
    };

    // 收到远端Peer移出一个stream
    pc.onRemoveStream = (stream) {
      debugPrint('> rtc pc onRemoveStream: ${stream.toString()}');
      onRemoveRemoteStream?.call(newSession, stream);
      remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    // 需要重新协商时触发，比如重启ICE时
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

  /// 邀请对端通话
  void invitePeer(String peerId, String media) async {
    debugPrint("> rtc invitePeer $peerId $media");
    if (peerId == UserRepoLocal.to.currentUid) {
      return;
    }
    String sessionId = "$from-$peerId";
    debugPrint("> rtc invite sessionId $sessionId ${DateTime.now()}");
    WebRTCSession session = await _createSession(
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

  RTCSessionDescription _fixSdp(RTCSessionDescription s) {
    return s;
    var sdp = s.sdp;
    s.sdp =
        sdp!.replaceAll('profile-level-id=640c1f', 'profile-level-id=42e032');
    return s;
  }

  Future<void> _createOffer(WebRTCSession s, String m) async {
    debugPrint(
        "> rtc _createOffer ${DateTime.now()} media $media sid ${s.sid}");
    try {
      makingOffer = true;
      s.pc!.createOffer(m == 'data' ? _dcConstraints : {}).then((sd) async {
        await _send('offer', {
          'sd': {'sdp': sd.sdp, 'type': sd.type},
          'sid': s.sid,
          'media': m,
        });

        // 此方法触发 onIceCandidate
        await s.pc!.setLocalDescription(_fixSdp(sd));
      });
    } catch (e) {
      debugPrint("> rtc _createOffer error $e");
    } finally {
      debugPrint("> rtc _createOffer finally ${DateTime.now()}");
      makingOffer = false;
    }
  }

  Future<void> _createDataChannel(WebRTCSession session,
      {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel = await session.pc!.createDataChannel(
      label,
      dataChannelDict,
    );
    _addDataChannel(session, channel);
  }

  _send(String event, Map payload) {
    Map request = {};
    request["ts"] = DateTimeHelper.currentTimeMillis();
    request["id"] = Xid().toString();
    request["to"] = to;
    request["from"] = from;
    request["type"] = "webrtc_$event";
    request["payload"] = payload;
    debugPrint('> rtc _send ${DateTime.now()} $event ${request.toString()}');
    _socket.sendMessage(json.encode(request));
  }

  Future<void> cleanSessions() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
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
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    await session.pc?.close();
    await session.dc?.close();
  }

  /// 需要重新协商时触发，比如重启ICE时
  void _onRenegotiationNeeded() async {
    debugPrint('> rtc pc onRenegotiationNeeded start ${DateTime.now()}');
    var session = sessions[sessionid.value] ?? null;

    if (session == null || session.pc!.signalingState == null) {
      return;
    }
    debugPrint(
        '> rtc pc onRenegotiationNeeded state before ${DateTime.now()}: ' +
            session.pc!.signalingState.toString());
    try {
      makingOffer = true;

      await session.pc!
          .createOffer(mediaConstraints)
          .then((RTCSessionDescription s) async {
        // 此方法触发 onIceCandidate
        await session.pc!.setLocalDescription(s);
        await _send('answer', {
          'media': media,
          'sid': session.sid,
          'sd': {'sdp': s.sdp, 'type': s.type},
        });
        debugPrint('> rtc pc onRenegotiationNeeded sent ${DateTime.now()}');
      });
    } catch (e) {
      debugPrint("> rtc pc onRenegotiationNeeded error " + e.toString());
    } finally {
      makingOffer = false;
      debugPrint('> rtc pc onRenegotiationNeeded done ${DateTime.now()}');
    }
  }

  /// 退出之前清理打开的资源
  void cleanUp() async {
    try {
      await cleanSessions();
    } catch (e) {}
    counter.value.close();
    if (localRenderer.value.srcObject != null) {
      localRenderer.value.srcObject = null;
    }
    if (localRenderer.value.textureId != null) {
      await localRenderer.value.dispose();
    }
    if (remoteRenderer.value.srcObject != null) {
      remoteRenderer.value.srcObject = null;
    }
    if (remoteRenderer.value.textureId != null) {
      await remoteRenderer.value.dispose();
    }
    connected = false.obs;
    refresh();
    p2pCallScreenOn = false;
    if (closePage != null) {
      closePage?.call();
    }
  }

  /// 挂断
  void hangUp() {
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

  void bye(String sessionId) {
    _send('bye', {
      'sid': sessionId,
    });
    cleanUp();
  }

  @override
  void onClose() {
    cleanUp();
    super.onClose();
  }

  /// 切换工具栏
  void switchTools() {
    update([
      showTool.value = !showTool.value,
    ]);
  }

  /// 切换本地相机
  /// Switch local camera
  void switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  /// 开关扬声器/耳机
  /// Switch speaker/earpiece
  void switchSpeaker() {
    if (_localStream != null) {
      speakerOn.value = !speakerOn.value;
      MediaStreamTrack audioTrack = _localStream!.getAudioTracks()[0];
      audioTrack.enableSpeakerphone(speakerOn.value);
      debugPrint(
          "> rtc switchSpeaker" + (speakerOn.value ? "speaker" : "earpiece"));
    }
  }

  /// 打开或关闭本地麦克风
  /// Open or close local microphone
  void turnMicrophone() {
    debugPrint("> rtc turnMicrophone");
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      bool muted = !microphoneOff.value;
      microphoneOff.value = muted;
      _localStream!.getAudioTracks()[0].enabled = !muted;
    }
  }

  /// 打开或关闭本地视频
  /// Open or close local video
  void turnCamera() {
    if (_localStream!.getVideoTracks().isNotEmpty) {
      var muted = !cameraOff.value;
      cameraOff.value = muted;
      _localStream!.getVideoTracks()[0].enabled = !muted;
    }
  }
}
