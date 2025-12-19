import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class P2pCallScreenLogic {
  var cameraOff = false.obs;

  WebRTCSession session;
  final String media; // video audio data
  final bool caller;

  final bool micOff;

  bool makingOffer = false;
  bool makingAnswer = false;

  MediaStream? _localStream;
  final List<RTCRtpSender> _senders = <RTCRtpSender>[];
  VideoSource _videoSource = VideoSource.Camera;

  Function(RTCSignalingState state)? onSignalingStateChange;
  Function(WebRTCSession? session, WebRTCCallState state)? onCallStateChange;

  Function(MediaStream stream)? onLocalStream;
  Function(WebRTCSession session, MediaStream stream)? onAddRemoteStream;
  Function(WebRTCSession session, MediaStream stream)? onRemoveRemoteStream;

  Function(
    WebRTCSession session,
    RTCDataChannel dc,
    RTCDataChannelMessage data,
  )? onDataChannelMessage;
  Function(WebRTCSession session, RTCDataChannel dc)? onDataChannel;

  final Map<String, dynamic> offerSdpConstraints = {
    'mandatory': {
      // "OfferToReceiveAudio": true,
      // "OfferToReceiveVideo": true,
    },
    // 如果要与浏览器互通，需要设置DtlsSrtpKeyAgreement为true
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  Map<String, dynamic> privDcConstraint = {
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

  P2pCallScreenLogic(
    this.session, {
    // 主叫者，发起通话人
    this.caller = true,
    // video audio data
    this.media = 'video',
    this.micOff = true,
  });

  Future<void> initState() async {
    iPrint("> rtc logic signalingConnect ${DateTime.now()}");
    makingOffer = false;
    makingAnswer = false;
  }

  Future<void> onMessageP2P(WebRTCSession s, WebRTCSignalingModel msg) async {
    // Map<String, dynamic> mapData = message;
    // var data = mapData['data'];
    iPrint("> rtc onMessageP2P ${msg.webRtcType} ${DateTime.now()}");
    // iPrint("> rtc onMessageP2P ${msg.toJson().toString()}");
    switch (msg.webRtcType) {
      case 'peers':
        // List<dynamic> peers = data;
        // if (onPeersUpdate != null) {
        //   Map<String, dynamic> event = Map<String, dynamic>();
        //   event['self'] = _selfId;
        //   event['peers'] = peers;
        //   onPeersUpdate?.call(event);
        // }
        break;
      case 'offer':
        // var peerId = data['from'];
        // var description = data['description'];
        // var media = data['media'];
        // String m = msg.payload['media'] ?? media;
        final sid = msg.payload['sid'] ?? s.sid;
        final sd = msg.payload['sd'];
        final s2 = await createSession(
          s,
          msgId: msg.msgId,
          media: media,
          screenSharing: false,
        );
        webRTCSessions[sid] = s2;
        iPrint(
            "> rtc onMessageP2P 1 ${msg.webRtcType} ${s2.toString()}, pc ${s2.pc.toString()}");

        if (s2.remoteCandidates.isNotEmpty) {
          for (var candidate in s2.remoteCandidates) {
            await s2.pc?.addCandidate(candidate);
          }
          s2.remoteCandidates.clear();
        }

        // s2.pc!
        //     .setRemoteDescription(RTCSessionDescription(sd['sdp'], sd['type']))
        //     .then((_) {
        //   _createAnswer(s2, msg.msgId, media);
        // });
        // 先调用 createOffer 或 createAnswer，然后调用 setLocalDescription，接着交换 SDP（会话描述协议）信息，最后调用 setRemoteDescription。
        final sd2 = RTCSessionDescription(sd['sdp'], sd['type']);
        await s2.pc!.setRemoteDescription(sd2);
        // Future.delayed(const Duration(milliseconds: 200), () async {
        //   await _createAnswer(newSession, msg.msgId, media);
        // });
        await _createAnswer(s2, msg.msgId, media);
        // onCallStateChange?.call(newSession, WebRTCCallState.CallStateNew);
        break;
      case 'answer':
        // String m = msg.payload['media'] ?? media;
        final sid = msg.payload['sid'] ?? s.sid;
        final sd = msg.payload['sd'];
        final s2 = webRTCSessions[sid];
        iPrint(
            "> rtc onMessageP2P 2 ${msg.webRtcType} ${s2.toString()}, pc ${s2?.pc.toString()}, sd ${sd.toString()} ;");

        makingOffer = false;
        s2!.pc?.setRemoteDescription(
          RTCSessionDescription(sd['sdp'], sd['type']),
        );
        webRTCSessions[sid] = s2;
        onCallStateChange?.call(s2, WebRTCCallState.CallStateConnected);
        break;
      case 'candidate':
        // var peerId = data['from'];
        final peerId = msg.from;
        final candidateMap = msg.payload['candidate'];
        await _receiveCandidate(peerId, candidateMap);
        break;
      case 'leave':
        // var peerId = data as String;
        closeSessionByPeerId(s.peerId);
        break;
      case 'ringing': // 对端弹窗音视频会话框的时候发送消息
        onCallStateChange?.call(s, WebRTCCallState.CallStateRinging);
        break;
      case 'busy': // 对端拒绝接听的时候发送此消息
        onCallStateChange?.call(s, WebRTCCallState.CallStateBusy);
        break;
      case 'bye':
        final sid = msg.payload['sid'];
        final s2 = webRTCSessions.remove(sid);
        if (s2 != null) {
          onCallStateChange?.call(s2, WebRTCCallState.CallStateBye);
          _closeSession(s2);
        }
        break;
      case 'keepalive':
        // print('keepalive response!');
        break;
      default:
        break;
    }
  }

  /// 接受暂存候选消息
  Future<void> _receiveCandidate(String peerId, Map<String, dynamic> data) async {
    RTCIceCandidate candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    // String pid = data['from'];
    String sid = sessionId(peerId);
    var s = webRTCSessions[sid];
    if (s != null && s.pc != null) {
      final description = await s.pc?.getRemoteDescription();
      if (description != null) {
        await s.pc?.addCandidate(candidate);
      } else {
        s.remoteCandidates.add(candidate);
      }
      webRTCSessions[sid] = s;
    } else {
      webRTCSessions[sid] = WebRTCSession(
        peerId: peerId,
        sid: sid,
      )..remoteCandidates.add(candidate);
    }
  }

  // RTCSessionDescription _fixSdp(RTCSessionDescription s) {
  //   // return s;
  //   String sdp = s.sdp!;
  //   sdp = sdp.replaceAll('H264', 'VP8');
  //   sdp = sdp.replaceAll('profile-level-id=640c1f', 'profile-level-id=42e032');
  //   s.sdp = sdp;
  //   return s;
  // }

  Future<void> answer(WebRTCSession s, String msgId, String media) async {
    iPrint("> rtc answer 1 $msgId, pc ${s.pc.toString()}");
    _createAnswer(s, msgId, media);
  }

  Future<void> _createAnswer(
      WebRTCSession session, String msgId, String media) async {
    if (makingAnswer) {
      return;
    }
    makingAnswer = true;
    // 是否接受视频数据
    privDcConstraint['mandatory']['OfferToReceiveVideo'] =
        media == 'video' ? true : false;
    iPrint(
        "> rtc onMessageP2P 3 _createAnswer ${DateTime.now()}, ${session.pc!.signalingState.toString()}");
    // if (session.pc!.signalingState !=
    //     RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
    //   return;
    // }
    // if (session.pc!.signalingState ==
    //     RTCSignalingState.RTCSignalingStateStable) {
    //   return;
    // }

    // try {
    Map<String, dynamic> conf = media == 'data' ? privDcConstraint : {};
    final s = await session.pc!.createAnswer(conf);
    iPrint(
        "> rtc onMessageP2P 4 _createAnswer ${DateTime.now()}, ${s.type.toString()}, sdp ${s.sdp.toString()}");
    // 此方法触发 onIceCandidate
    await session.pc!.setLocalDescription(s);
    // await session.pc!.setLocalDescription(_fixSdp(s));

    // final s2 = await session.pc!.getLocalDescription();
    sendWebRTCMsg(
      'answer',
      {
        'media': media,
        // sd = session description
        'sd': {'sdp': s.sdp, 'type': s.type},
      },
      msgId: msgId,
      to: session.peerId,
      debug: 'from_createAnswer',
    );
    makingAnswer = false;
    // } catch (e) {
    //   iPrint(e.toString());
    // }
  }

  Future<MediaStream?> _createStream(String media, bool userScreen) async {
    if (_localStream != null) {
      return _localStream;
    }
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': media == 'video'
          ? {
              'mandatory': {
                // Provide your own width, height and frame rate here
                'minWidth': getx.Get.width.toInt(),
                'minHeight': getx.Get.height.toInt(),
                'minFrameRate': '60',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };
    try {
      late MediaStream stream;
      if (userScreen) {
        if (WebRTC.platformIsDesktop) {
          /*
          final source = await showDialog<DesktopCapturerSource>(
            context: context!,
            builder: (context) => ScreenSelectDialog(),
          );
          stream =
              await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
            'video': source == null
                ? true
                : {
                    'deviceId': {'exact': source.id},
                    'mandatory': {'frameRate': 30.0}
                  }
          });
          */
        } else {
          stream =
              await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
        }
      } else {
        stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      }
      _localStream = stream;

      iPrint(
          "> rtc onLocalStream _createStream ${_localStream.toString()} ${DateTime.now()}");
      onLocalStream?.call(stream);
      return stream;
    } catch (e) {
      iPrint(
          "> rtc createStream error userScreen $userScreen ${e.toString()} ${DateTime.now()}");
    }
    return null;
  }

  Future<WebRTCSession> createSession(
    WebRTCSession newSession, {
    required String msgId,
    required String media,
    required bool screenSharing,
  }) async {
    iPrint(
        "> rtc createSession media $media, sid ${newSession.sid}, ${newSession.pc.toString()}, ${DateTime.now()}");
    if (media != 'data') {
      _localStream ??= await _createStream(media, screenSharing);
    }
    if (newSession.pc != null) {
      return newSession;
    }

    final iceConf = await _getIceConf();
    iPrint("> rtc createSession iceConfiguration ${iceConf.toString()}");
    final pc = await createPeerConnection(
      iceConf!,
      offerSdpConstraints,
    );
    // 收到远端Peer的一个新stream
    pc.onAddStream = (stream) async {
      iPrint('> rtc pc onAddStream: ${stream.id.toString()} ${DateTime.now()}');
      // onAddRemoteStream?.call(newSession!, stream);
      // onCallStateChange?.call(newSession, WebRTCCallState.CallStateConnected);
      // await _setRemoteRenderer(stream);
    };

    // 该方法在收到的信令指示一个transceiver将从远端接收媒体时被调用，实际就是在调用 SetRemoteDescription 时被触发。
    // 该接收track可以通过transceiver->receiver()->track()方法被访问到，其关联的streams可以通过transceiver->receiver()->streams()获取。
    // 只有在 unified-plan 语法下，该回调方法才会被触发。
    pc.onTrack = (RTCTrackEvent event) {
      iPrint("> rtc onTrack ${event.track.enabled} ${DateTime.now()} "
          "${event.track.toString()}");
      // 收到对方音频/视频流数据
      if (event.track.kind == 'audio' || event.track.kind == 'video') {
        onAddRemoteStream?.call(newSession, event.streams[0]);
        onCallStateChange?.call(newSession, WebRTCCallState.CallStateConnected);
      }
    };

    _localStream?.getTracks().forEach((track) async {
      _senders.add(await pc.addTrack(track, _localStream!));
    });
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
      iPrint('> rtc candidate pc onIceCandidate: ${DateTime.now()} '
          '${candidate.toMap().toString()}');
      if (candidate.candidate == null) {
        iPrint('> rtc pc onIceCandidate: complete!');
        return;
      }
      sendWebRTCMsg(
        'candidate',
        {
          'candidate': {
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
            'candidate': candidate.candidate,
          },
        },
        msgId: msgId,
        to: session.peerId,
      );
      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      // await Future.delayed(const Duration(milliseconds: 1500), () {
      //   sendWebRTCMsg(
      //     'candidate',
      //     {
      //       'candidate': {
      //         'sdpMLineIndex': candidate.sdpMLineIndex,
      //         'sdpMid': candidate.sdpMid,
      //         'candidate': candidate.candidate,
      //       },
      //     },
      //     msgId: msgId,
      //     to: session.peerId,
      //   );
      // });
    };

    // flutter-webrtc 貌似没有定义实现 onIceCandidateError
    // pc.onIceCandidateError = () {};
    // 信令状态改变 等价 OnSignalingChange
    pc.onSignalingState = (RTCSignalingState state) {
      iPrint(
          '> rtc pc onSignalingState: ${state.toString()} ${DateTime.now()}');
      if (state == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        _createAnswer(newSession, msgId, media);
      }
      onSignalingStateChange?.call(state);
    };

    // PeerConnection状态改变 等价 OnConnectionChange
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      iPrint(
          '> rtc pc onIceConnectionState: ${state.toString()} ${DateTime.now()}');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        pc.restartIce();
      }
    };

    // 收到远端Peer移出一个stream
    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      // _remoteStreams.removeWhere((it) {
      //   return (it.id == stream.id);
      // });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    // 需要重新协商时触发，比如重启ICE时
    pc.onRenegotiationNeeded = () async {
      iPrint(
          '> rtc pc onRenegotiationNeeded sid ${session.sid} caller $caller ${DateTime.now()}');
      iPrint(
          '> rtc pc onRenegotiationNeeded pc state ${pc.signalingState.toString()} ');
      if (caller) {
        _createOffer(msgId, media);
      } else {
        // _createAnswer(newSession!, msgId, media);
      }
    };

    newSession.pc = pc;

    webRTCSessions[newSession.sid] = newSession;
    session = newSession;
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
  Future<void> invitePeer(
      {required String msgId,
      required String peer,
      required String media}) async {
    iPrint("> rtc invitePeer $peer, ${UserRepoLocal.to.currentUid} $media");
    if (peer == UserRepoLocal.to.currentUid) {
      return;
    }

    if (media == 'data') {
      _createDataChannel(session);
    }
    iPrint("> rtc invitePeer _createOffer pc ${session.pc.toString()}");
    await _createOffer(msgId, media);
    onCallStateChange?.call(session, WebRTCCallState.CallStateNew);
  }

  Future<void> _createOffer(String msgId, String m) async {
    iPrint(
        "> rtc _createOffer media $m sid ${session.sid}, makingOffer $makingOffer, ${DateTime.now()}");
    if (makingOffer) {
      return;
    }
    makingOffer = true;
    // 是否接受视频数据
    privDcConstraint['mandatory']['OfferToReceiveVideo'] =
        media == 'video' ? true : false;
    RTCSessionDescription sd =
        await session.pc!.createOffer(media == 'data' ? privDcConstraint : {});
    // 此方法触发 onIceCandidate
    // await session.pc!.setLocalDescription(_fixSdp(sd));
    await session.pc!.setLocalDescription(sd);
    final description = await session.pc!.getLocalDescription();
    sendWebRTCMsg(
      'offer',
      {
        // sd = session description
        'sd': {'sdp': description!.sdp, 'type': description.type},
        'media': m,
      },
      msgId: msgId,
      to: session.peerId,
      debug: 'from_createOffer',
    );
    // } catch (e) {
    //   iPrint("> rtc _createOffer error $e\n");
    // } finally {
    //   iPrint("> rtc _createOffer finally ${DateTime.now()}");
    // }
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

  void sendBusy(String msgId, String to) {
    sendWebRTCMsg('busy', {}, msgId: msgId, to: to);
  }

  Future<void> _stopLocalStream() async {
    iPrint("> rtc _stopLocalStream start ${_localStream.toString()}");
    if (_localStream == null) {
      return;
    }
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    if (_localStream?.id != null) {
      await _localStream?.dispose();
    }
    _localStream = null;
  }

  Future<void> cleanSessions() async {
    iPrint("> rtc cleanSessions start ${webRTCSessions.length}");
    webRTCSessions.forEach((key, sess) async {
      sess.pc?.onIceCandidate = null;
      sess.pc?.onTrack = null;
      iPrint('> rtc cleanSessions sess.sid ${sess.sid}');
      await sess.pc?.close();
      await sess.pc?.dispose();
      await sess.dc?.close();
    });
    webRTCSessions.clear();
  }

  void closeSessionByPeerId(String peerId) {
    WebRTCSession? session;
    webRTCSessions.removeWhere((String key, WebRTCSession sess) {
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
    iPrint("> rtc closeSession start ${session.sid}");
    if (_localStream != null) {
      _localStream?.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream?.dispose();
      _localStream = null;
    }

    await session.pc?.close();
    await session.pc?.dispose();
    await session.dc?.close();
    _senders.clear();
    _videoSource = VideoSource.Camera;
    webRTCSessions.remove(session.sid);
  }

  /// 退出之前清理打开的资源
  Future<void> cleanUpP2P() async {
    try {
      await cleanSessions();
    } catch (e) {
      //
    }

    await _stopLocalStream();
    initState();
    p2pCallScreenOn = false;
  }

  void sendBye(String msgId) {
    sendWebRTCMsg(
      'bye',
      {
        'sid': session.sid,
      },
      msgId: msgId,
      to: session.peerId,
    );
    var s = webRTCSessions[session.sid];
    if (s != null) {
      _closeSession(s);
    }
  }

  /// 切换本地相机
  /// Switch local camera
  void switchCamera() {
    if (_localStream != null) {
      if (_videoSource != VideoSource.Camera) {
        for (var sender in _senders) {
          if (sender.track!.kind == 'video') {
            sender.replaceTrack(_localStream!.getVideoTracks()[0]);
          }
        }
        _videoSource = VideoSource.Camera;
        onLocalStream?.call(_localStream!);
      } else {
        Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      }
    }
  }

  /// 前后分享屏幕
  void switchToScreenSharing(MediaStream stream) {
    if (_localStream != null && _videoSource != VideoSource.Screen) {
      for (var sender in _senders) {
        if (sender.track!.kind == 'video') {
          sender.replaceTrack(stream.getVideoTracks()[0]);
        }
      }
      onLocalStream?.call(stream);
      _videoSource = VideoSource.Screen;
    }
  }

  /// 开关扬声器/耳机
  /// Switch speaker/earpiece
  bool? switchSpeaker(bool speakerOn) {
    if (_localStream != null) {
      // speakerOn.value = !speakerOn.value;
      MediaStreamTrack audioTrack = _localStream!.getAudioTracks()[0];
      audioTrack.enableSpeakerphone(speakerOn);
    }
    return null;
  }

  /// 打开或关闭本地麦克风
  /// Open or close local microphone
  bool? turnMicrophone() {
    iPrint("> rtc turnMicrophone");
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      // bool muted = !microphoneOff.value;
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      // microphoneOff.value = enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
      return enabled;
    }
    return null;
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

  /// 获取 ice 配置信息
  Future<Map<String, dynamic>?> _getIceConf(
      {String from = 'incomingCallScreen'}) async {
    Map<String, dynamic> turnCredential = await UserProvider().turnCredential();
    debugPrint("getIceServers _turnCredential ${turnCredential.toString()}");
    if (turnCredential.isEmpty && from == 'openCallScreen') {
      EasyLoading.showError('failedRequestPleaseCheckNetwork'.tr);
      return null;
    } else if (turnCredential.isEmpty) {
      return null;
    }
    return {
      'iceServers': [
        {
          'urls': turnCredential['stun_urls'], // stun urls
          // 'username': turnCredential['username'],
          // 'credential': turnCredential['credential']
        },
        {
          'urls': turnCredential['turn_urls'], // turn urls
          "ttl": turnCredential['ttl'] ?? 86400,
          'username': turnCredential['username'],
          'credential': turnCredential['credential']
        },
      ],
      // ceCandidatePoolSize默认值是0，表示不限制候选数量。5，来限制ICE候选的数量。
      "iceCandidatePoolSize": 0,
      // encodedInsertableStreams 是一个实验性的特性，它允许开发者在浏览器中插入自定义的编码器和解码器
      "encodedInsertableStreams": false,
      // balanced：默认值，尝试在减少传输层连接数和保持足够的灵活性之间找到平衡。这通常意味着音频和视频流会捆绑在一起，但不会强制捆绑所有媒体类型。
      // max-bundle：尽可能地将所有媒体流捆绑到一个RTP会话中。这减少了建立的连接数，可以减少总体的连接建立时间，因为只需要进行一次ICE协商。
      // max-compat：不强制捆绑媒体流，以保持最大的兼容性。这可能会增加建立连接所需的时间，因为每个媒体流可能需要单独的ICE协商。
      "bundlePolicy": "balanced",
      // all:可以使用任何类型的候选者(表示host类型、srflx反射、relay中继都支持)
      // relay: 只使用中继候选者（在真实的网络情况下一般都使用 relay，因为Nat穿越在中国很困难）
      'iceTransportPolicy': 'all',
      "rtcpMuxPolicy": "require",
      'sdpSemantics': 'unified-plan',
    };
  }
}
