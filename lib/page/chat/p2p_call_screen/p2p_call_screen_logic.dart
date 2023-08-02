import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' as getx;

import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class P2pCallScreenLogic {
  var cameraOff = false.obs;

  WebRTCSession session;
  final String media; // video audio data
  final bool caller;

  final bool micOff;

  bool makingOffer = false;

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

  final Map<String, dynamic> iceConfiguration;

  final Map<String, dynamic> offerSdpConstraints = {
    'mandatory': {},
    // 如果要与浏览器互通，需要设置DtlsSrtpKeyAgreement为true
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  Map<String, dynamic> privateDcConstraints = {
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
    this.session,
    this.iceConfiguration, {
    // 主叫者，发起通话人
    this.caller = true,
    // video audio data
    this.media = 'video',
    this.micOff = true,
  });

  Future<void> signalingConnect() async {
    debugPrint("> rtc logic signalingConnect ${DateTime.now()}");
    makingOffer = false;
  }

  Future<void> onMessageP2P(WebRTCSignalingModel msg) async {
    // Map<String, dynamic> mapData = message;
    // var data = mapData['data'];
    debugPrint("> rtc onMessageP2P ${msg.webrtctype} ${DateTime.now()}");
    debugPrint("> rtc onMessageP2P ${msg.toJson().toString()}");
    switch (msg.webrtctype) {
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
        String sid = msg.payload['sid'] ?? session.sid;
        var sd = msg.payload['sd'];
        var newSession = webRTCSessions[sid];
        debugPrint(
            "> rtc onMessageP2P 1 ${msg.webrtctype} ${newSession.toString()}, pc ${newSession?.pc.toString()}");
        // newSession = await createSession(
        //   newSession,
        //   media: m,
        //   screenSharing: false,
        // );

        await newSession!.pc!.setRemoteDescription(
          RTCSessionDescription(sd['sdp'], sd['type']),
        );
        if (newSession.remoteCandidates.isNotEmpty) {
          for (var candidate in newSession.remoteCandidates) {
            await newSession.pc?.addCandidate(candidate);
          }
          newSession.remoteCandidates.clear();
        }
        webRTCSessions[sid] = newSession;
        // await _createAnswer(newSession, media);
        // onCallStateChange?.call(newSession, WebRTCCallState.CallStateNew);
        break;
      case 'answer':
        // String m = msg.payload['media'] ?? media;
        String sid = msg.payload['sid'] ?? session.sid;
        var sd = msg.payload['sd'];
        var newSession = webRTCSessions[sid];
        debugPrint(
            "> rtc onMessageP2P 2 ${msg.webrtctype} ${newSession.toString()}, pc ${newSession?.pc.toString()}");

        makingOffer = false;
        newSession!.pc?.setRemoteDescription(
          RTCSessionDescription(sd['sdp'], sd['type']),
        );
        webRTCSessions[sid] = newSession;
        onCallStateChange?.call(session, WebRTCCallState.CallStateConnected);
        break;
      case 'candidate':
        // var peerId = data['from'];
        String peerId = msg.from;
        var candidateMap = msg.payload['candidate'];
        await receiveCandidate(peerId, candidateMap);
        break;
      case 'leave':
        // var peerId = data as String;
        closeSessionByPeerId(session.pid);
        break;
      case 'ringing': // 对端弹窗音视频会话框的时候发送消息
        onCallStateChange?.call(session, WebRTCCallState.CallStateRinging);
        break;
      case 'busy': // 对端拒绝接听的时候发送此消息
        onCallStateChange?.call(session, WebRTCCallState.CallStateBusy);
        break;
      case 'bye':
        var sid = msg.payload['sid'];
        var session = webRTCSessions.remove(sid);
        if (session != null) {
          onCallStateChange?.call(session, WebRTCCallState.CallStateBye);
          _closeSession(session);
        }
        break;
      case 'keepalive':
        // print('keepalive response!');
        break;
      default:
        break;
    }
  }

  RTCSessionDescription _fixSdp(RTCSessionDescription s) {
    // return s;
    var sdp = s.sdp;
    s.sdp =
        sdp!.replaceAll('profile-level-id=640c1f', 'profile-level-id=42e032');
    return s;
  }

  Future<void> _createAnswer(WebRTCSession session, String media) async {
    // 是否接受视频数据
    privateDcConstraints['mandatory']['OfferToReceiveVideo'] =
        media == 'video' ? true : false;
    try {
      RTCSessionDescription s = await session.pc!
          .createAnswer(media == 'data' ? privateDcConstraints : {});
      // 此方法触发 onIceCandidate
      await session.pc!.setLocalDescription(_fixSdp(s));
      final description = await session.pc!.getLocalDescription();

      await sendWebRTCMsg(
        'answer',
        {
          'media': media,
          // sd = session description
          'sd': {'sdp': description!.sdp, 'type': description.type},
        },
        to: session.pid,
        debug: 'from_createAnswer',
      );
    } catch (e) {
      debugPrint(e.toString());
    }
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

      debugPrint(
          "> rtc onLocalStream _createStream ${_localStream.toString()} ${DateTime.now()}");
      onLocalStream?.call(stream);
      return stream;
    } catch (e) {
      debugPrint("> rtc createStream error ${e.toString()} ${DateTime.now()}");
    }
    return null;
  }

  Future<WebRTCSession> createSession(
    WebRTCSession? newSession, {
    required String media,
    required bool screenSharing,
  }) async {
    debugPrint(
        "> rtc _createSession ${newSession?.sid}, ${newSession?.pc.toString()}, ${DateTime.now()}");
    if (media != 'data') {
      _localStream ??= await _createStream(media, screenSharing);
    }
    if (newSession != null && newSession.pc != null) {
      return newSession;
    }

    debugPrint("> rtc iceConfiguration ${iceConfiguration.toString()}");
    RTCPeerConnection pc = await createPeerConnection(
      iceConfiguration,
      offerSdpConstraints,
    );
    // 该方法在收到的信令指示一个transceiver将从远端接收媒体时被调用，实际就是在调用 SetRemoteDescription 时被触发。
    // 该接收track可以通过transceiver->receiver()->track()方法被访问到，其关联的streams可以通过transceiver->receiver()->streams()获取。
    // 只有在 unified-plan 语法下，该回调方法才会被触发。
    pc.onTrack = (RTCTrackEvent event) {
      debugPrint("> rtc onTrack ${event.track.enabled} ${DateTime.now()} "
          "${event.track.toString()}");
      // 收到对方音频/视频流数据
      if (event.track.kind == 'video') {
        onAddRemoteStream?.call(newSession!, event.streams[0]);
        onCallStateChange?.call(newSession, WebRTCCallState.CallStateConnected);
      }
    };
    _localStream!.getTracks().forEach((track) async {
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
      debugPrint('> rtc candidate pc onIceCandidate: ${DateTime.now()} '
          '${candidate.toMap().toString()}');
      if (candidate.candidate == null) {
        debugPrint('> rtc pc onIceCandidate: complete!');
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
        to: session.pid,
      );
    };

    // flutter-webrtc 貌似没有定义实现 onIceCandidateError
    // pc.onIceCandidateError = () {};
    // 信令状态改变 等价 OnSignalingChange
    pc.onSignalingState = (RTCSignalingState state) {
      debugPrint(
          '> rtc pc onSignalingState: ${state.toString()} ${DateTime.now()}');
      if (state == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        _createAnswer(newSession!, media);
      }
      onSignalingStateChange?.call(state);
    };

    // PeerConnection状态改变 等价 OnConnectionChange
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint(
          '> rtc pc onIceConnectionState: ${state.toString()} ${DateTime.now()}');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        pc.restartIce();
      }
    };

    // 收到远端Peer的一个新stream
    pc.onAddStream = (stream) async {
      debugPrint(
          '> rtc pc onAddStream: ${stream.id.toString()} ${DateTime.now()}');
      // await _setRemoteRenderer(stream);
    };

    // 收到远端Peer移出一个stream
    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession!, stream);
      // _remoteStreams.removeWhere((it) {
      //   return (it.id == stream.id);
      // });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession!, channel);
    };

    // 需要重新协商时触发，比如重启ICE时
    pc.onRenegotiationNeeded = () async {
      debugPrint(
          '> rtc pc onRenegotiationNeeded sid ${session.sid} caller $caller ${DateTime.now()}');
      debugPrint(
          '> rtc pc onRenegotiationNeeded pc state ${pc.signalingState.toString()} ');
      if (caller) {
        _createOffer(media);
      }
      // else {
      //   _createAnswer(newSession!, media);
      // }
    };

    newSession!.pc = pc;

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
  Future<void> invitePeer(String peer, String media) async {
    debugPrint("> rtc invitePeer $peer, ${UserRepoLocal.to.currentUid} $media");
    if (peer == UserRepoLocal.to.currentUid) {
      return;
    }

    debugPrint("> rtc invitePeer _createSession ${session.toString()}");
    session = await createSession(
      session,
      media: media,
      screenSharing: false,
    );
    webRTCSessions[session.sid] = session;

    if (media == 'data') {
      _createDataChannel(session);
    }
    debugPrint("> rtc invitePeer _createOffer pc ${session.pc.toString()}");
    await _createOffer(media);
    onCallStateChange?.call(session, WebRTCCallState.CallStateNew);
  }

  Future<void> _createOffer(String m) async {
    debugPrint(
        "> rtc _createOffer media $m sid ${session.sid}, makingOffer $makingOffer, ${DateTime.now()}");
    if (makingOffer) {
      return;
    }
    makingOffer = true;
    // 是否接受视频数据
    privateDcConstraints['mandatory']['OfferToReceiveVideo'] =
        media == 'video' ? true : false;
    RTCSessionDescription sd = await session.pc!
        .createOffer(media == 'data' ? privateDcConstraints : {});
    // 此方法触发 onIceCandidate
    await session.pc!.setLocalDescription(_fixSdp(sd));
    final description = await session.pc!.getLocalDescription();
    await sendWebRTCMsg(
      'offer',
      {
        // sd = session description
        'sd': {'sdp': description!.sdp, 'type': description.type},
        'media': m,
      },
      to: session.pid,
      debug: 'from_createOffer',
    );
    // } catch (e) {
    //   debugPrint("> rtc _createOffer error $e\n");
    // } finally {
    //   debugPrint("> rtc _createOffer finally ${DateTime.now()}");
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

  sendBusy(String to) {
    sendWebRTCMsg('busy', {}, to: to);
  }

  _stopLocalStream() async {
    debugPrint("> rtc _stopLocalStream start ${_localStream.toString()}");
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
    debugPrint("> rtc cleanSessions start ${webRTCSessions.length}");
    webRTCSessions.forEach((key, sess) async {
      sess.pc?.onIceCandidate = null;
      sess.pc?.onTrack = null;
      debugPrint('> rtc cleanSessions sess.sid ${sess.sid}');
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
    debugPrint("> rtc closeSession start ${session.sid}");
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
  }

  /// 退出之前清理打开的资源
  Future<void> cleanUpP2P() async {
    try {
      await cleanSessions();
    } catch (e) {
      //
    }

    await _stopLocalStream();

    p2pCallScreenOn = false;
  }

  void sendBye() {
    sendWebRTCMsg(
      'bye',
      {
        'sid': session.sid,
      },
      to: session.pid,
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
    debugPrint("> rtc turnMicrophone");
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

  Future<void> changeMessageState(String msgId, int state, int endAt) async {
    MessageRepo repo = MessageRepo();
    MessageModel? msg = await repo.find(msgId);
    if (msg ==null) {
      return;
    }
    Map<String, dynamic> payload = msg.payload!;
    payload['end_at'] = endAt;
    payload['state'] = state;
    int res = await repo.update({
      MessageRepo.id: msgId,
      MessageRepo.payload: payload,
      // MessageRepo.id: msgId,
      // MessageRepo.id: msgId,
    });
    if (res > 0) {
      msg.payload = payload;
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([msg.toTypeMessage()]);
    }
  }
}
