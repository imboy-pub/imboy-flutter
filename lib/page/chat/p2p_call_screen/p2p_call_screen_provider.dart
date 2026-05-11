import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/init.dart' show webRTCSessions, p2pCallScreenOn;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'p2p_call_screen_provider.g.dart';

/// P2P Call Screen 状态
class P2pCallScreenState {
  final bool cameraOff;
  final bool micOff;
  final bool speakerOn;
  final bool connected;
  final bool showTool;
  final bool minimized;
  final String stateTips;
  final String callDuration;
  final double localX;
  final double localY;

  const P2pCallScreenState({
    this.cameraOff = false,
    this.micOff = false,
    this.speakerOn = true,
    this.connected = false,
    this.showTool = true,
    this.minimized = false,
    this.stateTips = '',
    this.callDuration = '00:00',
    this.localX = 0.0,
    this.localY = 0.0,
  });

  P2pCallScreenState copyWith({
    bool? cameraOff,
    bool? micOff,
    bool? speakerOn,
    bool? connected,
    bool? showTool,
    bool? minimized,
    String? stateTips,
    String? callDuration,
    double? localX,
    double? localY,
  }) {
    return P2pCallScreenState(
      cameraOff: cameraOff ?? this.cameraOff,
      micOff: micOff ?? this.micOff,
      speakerOn: speakerOn ?? this.speakerOn,
      connected: connected ?? this.connected,
      showTool: showTool ?? this.showTool,
      minimized: minimized ?? this.minimized,
      stateTips: stateTips ?? this.stateTips,
      callDuration: callDuration ?? this.callDuration,
      localX: localX ?? this.localX,
      localY: localY ?? this.localY,
    );
  }
}

/// P2P Call Screen Provider
@riverpod
class P2pCallScreenNotifier extends _$P2pCallScreenNotifier {
  WebRTCSession? session;
  String media = 'video';
  bool caller = true;
  String msgId = '';

  bool makingOffer = false;
  bool makingAnswer = false;

  MediaStream? _localStream;
  final List<RTCRtpSender> _senders = <RTCRtpSender>[];
  VideoSource _videoSource = VideoSource.camera;

  Timer? _answerTimer;
  Timer? _callTimer;
  int _callSeconds = 0;

  // ICE 重启计数器（防止无限重连）
  int _iceRestartCount = 0;
  static const int _maxIceRestarts = 3;
  Timer? _iceDisconnectTimer;

  // 回调函数
  Function(RTCSignalingState state)? onSignalingStateChange;
  Function(WebRTCSession? session, WebRTCCallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(WebRTCSession session, MediaStream stream)? onAddRemoteStream;
  Function(WebRTCSession session, MediaStream stream)? onRemoveRemoteStream;
  Function(
    WebRTCSession session,
    RTCDataChannel dc,
    RTCDataChannelMessage data,
  )?
  onDataChannelMessage;
  Function(WebRTCSession session, RTCDataChannel dc)? onDataChannel;

  final Map<String, dynamic> _offerSdpConstraints = {
    'mandatory': <String, dynamic>{},
    'optional': <Map<String, dynamic>>[
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _privDcConstraint = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
      'IceRestart': true,
    },
    'optional': <Map<String, dynamic>>[],
  };

  @override
  P2pCallScreenState build() {
    return const P2pCallScreenState();
  }

  void initSession({
    required WebRTCSession newSession,
    required String newMedia,
    required bool isCaller,
    required String newMsgId,
  }) {
    session = newSession;
    media = newMedia;
    caller = isCaller;
    msgId = newMsgId;
    makingOffer = false;
    makingAnswer = false;
    _callSeconds = 0;
  }

  Future<void> initState() async {
    iPrint("> rtc logic signalingConnect ${DateTime.now()}");
    makingOffer = false;
    makingAnswer = false;
  }

  Future<void> onMessageP2P(WebRTCSession s, WebRTCSignalingModel msg) async {
    iPrint("> rtc onMessageP2P ${msg.webRtcType}");

    // 安全校验：验证信令消息发送方是否为当前会话的合法对等端
    if (msg.from != s.peerId &&
        msg.webRtcType != 'peers' &&
        msg.webRtcType != 'heartbeat') {
      iPrint(
        '> rtc WARNING: message from unexpected peer ${msg.from}, expected ${s.peerId}',
      );
      return;
    }

    switch (msg.webRtcType) {
      case 'peers':
        break;
      case 'offer':
        final sid = msg.payload['sid'] ?? s.sid;
        final sd = msg.payload['sd'];
        // SDP 基本格式校验
        if (sd is! Map || sd['sdp'] is! String || sd['type'] != 'offer') {
          iPrint('> rtc WARNING: invalid SDP in offer message');
          return;
        }
        final s2 = await createSession(
          s,
          msgId: msg.msgId,
          media: media,
          screenSharing: false,
        );
        webRTCSessions[sid] = s2;

        if (s2.remoteCandidates.isNotEmpty) {
          for (var candidate in s2.remoteCandidates) {
            await s2.pc?.addCandidate(candidate);
          }
          s2.remoteCandidates.clear();
        }

        final sd2 = RTCSessionDescription(sd['sdp'], sd['type']);
        await s2.pc!.setRemoteDescription(sd2);
        await _createAnswer(s2, msg.msgId, media);
        break;
      case 'answer':
        final sid = msg.payload['sid'] ?? s.sid;
        final sd = msg.payload['sd'];
        // SDP 基本格式校验
        if (sd is! Map || sd['sdp'] is! String || sd['type'] != 'answer') {
          iPrint('> rtc WARNING: invalid SDP in answer message');
          return;
        }
        final s2 = webRTCSessions[sid];

        makingOffer = false;
        await s2!.pc?.setRemoteDescription(
          RTCSessionDescription(sd['sdp'], sd['type']),
        );
        webRTCSessions[sid] = s2;
        onCallStateChange?.call(s2, WebRTCCallState.callStateConnected);
        break;
      case 'candidate':
        final peerId = msg.from;
        final candidateMap = msg.payload['candidate'];
        await _receiveCandidate(peerId, candidateMap);
        break;
      case 'leave':
        closeSessionByPeerId(s.peerId);
        break;
      case 'ringing':
        onCallStateChange?.call(s, WebRTCCallState.callStateRinging);
        break;
      case 'busy':
        onCallStateChange?.call(s, WebRTCCallState.callStateBusy);
        break;
      case 'bye':
        final sid = msg.payload['sid'];
        final s2 = webRTCSessions.remove(sid);
        if (s2 != null) {
          onCallStateChange?.call(s2, WebRTCCallState.callStateBye);
          _closeSession(s2);
        }
        break;
      case 'heartbeat':
        break;
      default:
        break;
    }
  }

  Future<void> _receiveCandidate(
    String peerId,
    Map<String, dynamic> data,
  ) async {
    // ICE 候选字段校验
    final candidateStr = data['candidate'];
    final sdpMid = data['sdpMid'];
    final sdpMLineIndex = data['sdpMLineIndex'];
    if (candidateStr is! String ||
        candidateStr.isEmpty ||
        sdpMid is! String ||
        sdpMLineIndex is! int) {
      iPrint('> rtc WARNING: invalid ICE candidate fields, skipping');
      return;
    }
    RTCIceCandidate candidate = RTCIceCandidate(
      candidateStr,
      sdpMid,
      sdpMLineIndex,
    );
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
      webRTCSessions[sid] = WebRTCSession(peerId: peerId, sid: sid)
        ..remoteCandidates.add(candidate);
    }
  }

  Future<void> _createAnswer(
    WebRTCSession session,
    String msgId,
    String media,
  ) async {
    if (makingAnswer) {
      iPrint('> rtc _createAnswer: already making answer, skipping');
      return;
    }
    makingAnswer = true;
    try {
      _privDcConstraint['mandatory']['OfferToReceiveVideo'] = media == 'video'
          ? true
          : false;
      iPrint("> rtc onMessageP2P 3 _createAnswer ${DateTime.now()}");

      Map<String, dynamic> conf = media == 'data' ? _privDcConstraint : {};
      final s = await session.pc!.createAnswer(conf);
      await session.pc!.setLocalDescription(s);

      sendWebRTCMsg(
        'answer',
        {
          'media': media,
          'sd': {'sdp': s.sdp, 'type': s.type},
        },
        msgId: msgId,
        to: session.peerId,
        debug: 'from_createAnswer',
      );
    } catch (e, s) {
      iPrint('> rtc _createAnswer error: $e\n$s');
    } finally {
      makingAnswer = false;
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
                'minWidth': VideoQualityConfig.minVideoWidth,
                'minHeight': VideoQualityConfig.minVideoHeight,
                'minFrameRate': VideoQualityConfig.minFrameRate.toString(),
              },
              'facingMode': 'user',
              'optional': <Map<String, dynamic>>[],
            }
          : false,
    };
    try {
      late MediaStream stream;
      if (userScreen) {
        if (WebRTC.platformIsDesktop) {
          // Desktop screen share implementation
        } else {
          stream = await navigator.mediaDevices.getDisplayMedia(
            mediaConstraints,
          );
        }
      } else {
        stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      }
      _localStream = stream;

      iPrint("> rtc onLocalStream _createStream ${_localStream.toString()}");
      onLocalStream?.call(stream);
      return stream;
    } catch (e) {
      iPrint("> rtc createStream error userScreen $userScreen ${e.toString()}");
    }
    return null;
  }

  Future<WebRTCSession> createSession(
    WebRTCSession newSession, {
    required String msgId,
    required String media,
    required bool screenSharing,
  }) async {
    iPrint("> rtc createSession media $media, sid ${newSession.sid}");
    if (media != 'data') {
      _localStream ??= await _createStream(media, screenSharing);
    }
    if (newSession.pc != null) {
      return newSession;
    }

    final iceConf = await _getIceConf();
    final pc = await createPeerConnection(iceConf!, _offerSdpConstraints);

    pc.onAddStream = (stream) async {
      iPrint('> rtc pc onAddStream: ${stream.id.toString()}');
    };

    pc.onTrack = (RTCTrackEvent event) {
      iPrint("> rtc onTrack ${event.track.enabled}");
      if (event.track.kind == 'audio' || event.track.kind == 'video') {
        onAddRemoteStream?.call(newSession, event.streams[0]);
        onCallStateChange?.call(newSession, WebRTCCallState.callStateConnected);
      }
    };

    _localStream?.getTracks().forEach((track) async {
      _senders.add(await pc.addTrack(track, _localStream!));
    });

    pc.onIceCandidate = (RTCIceCandidate candidate) async {
      iPrint('> rtc candidate pc onIceCandidate: ${DateTime.now()}');
      if (candidate.candidate == null) {
        iPrint('> rtc pc onIceCandidate: complete!');
        return;
      }

      // 解析并记录 ICE 候选类型（便于调试 NAT 穿透问题）
      final candidateType = _parseIceCandidateType(candidate.candidate ?? '');
      // 仅记录候选类型，不输出完整候选字符串（含 IP 地址）
      iPrint('> rtc ICE candidate type: $candidateType');

      final currentSession = session;
      if (currentSession == null) {
        iPrint('> rtc onIceCandidate: session is null, skipping');
        return;
      }
      try {
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
          to: currentSession.peerId,
        );
      } catch (e, s) {
        iPrint('> rtc onIceCandidate send error: $e\n$s');
        // 网络错误不中断流程，ICE 候选会继续收集
      }
    };

    pc.onSignalingState = (RTCSignalingState state) {
      iPrint('> rtc pc onSignalingState: ${state.toString()}');
      if (state == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        _createAnswer(newSession, msgId, media);
      }
      onSignalingStateChange?.call(state);
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      iPrint('> rtc pc onIceConnectionState: ${state.toString()}');

      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          // 连接成功，重置计数器
          _iceRestartCount = 0;
          _iceDisconnectTimer?.cancel();
          _iceDisconnectTimer = null;
          updateConnected(true);
          break;

        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // 断开后等待 5 秒尝试恢复
          _iceDisconnectTimer?.cancel();
          _iceDisconnectTimer = Timer(const Duration(seconds: 5), () {
            if (session?.pc?.iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
              iPrint('> rtc ICE disconnected timeout, attempting restart');
              _attemptIceRestart();
            }
          });
          break;

        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          // ICE 失败时尝试重启
          _attemptIceRestart();
          break;

        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _iceDisconnectTimer?.cancel();
          break;

        default:
          break;
      }
    };

    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    pc.onRenegotiationNeeded = () async {
      iPrint('> rtc pc onRenegotiationNeeded');
      if (caller) {
        _createOffer(msgId, media);
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

  Future<void> invitePeer({
    required String msgId,
    required String peer,
    required String media,
  }) async {
    final currentSession = session;
    if (currentSession == null) {
      iPrint('> rtc invitePeer: session is null, cannot invite');
      return;
    }
    iPrint("> rtc invitePeer $peer $media");
    if (media == 'data') {
      _createDataChannel(currentSession);
    }
    await _createOffer(msgId, media);
    onCallStateChange?.call(currentSession, WebRTCCallState.callStateNew);
  }

  Future<void> _createOffer(String msgId, String m) async {
    final currentSession = session;
    if (currentSession == null) {
      iPrint('> rtc _createOffer: session is null, skipping');
      return;
    }
    iPrint("> rtc _createOffer media $m sid ${currentSession.sid}");
    if (makingOffer) {
      iPrint('> rtc _createOffer: already making offer, skipping');
      return;
    }
    makingOffer = true;
    try {
      _privDcConstraint['mandatory']['OfferToReceiveVideo'] = media == 'video'
          ? true
          : false;
      RTCSessionDescription sd = await currentSession.pc!.createOffer(
        media == 'data' ? _privDcConstraint : {},
      );
      await currentSession.pc!.setLocalDescription(sd);
      final description = await currentSession.pc!.getLocalDescription();
      sendWebRTCMsg(
        'offer',
        {
          'sd': {'sdp': description!.sdp, 'type': description.type},
          'media': m,
        },
        msgId: msgId,
        to: currentSession.peerId,
        debug: 'from_createOffer',
      );
    } catch (e, s) {
      iPrint('> rtc _createOffer error: $e\n$s');
    } finally {
      makingOffer = false;
    }
  }

  Future<void> _createDataChannel(
    WebRTCSession session, {
    label = DataChannelConfig.defaultLabel,
  }) async {
    final pc = session.pc;
    if (pc == null) {
      iPrint(
        '> rtc _createDataChannel: pc is null, cannot create data channel',
      );
      return;
    }
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = DataChannelConfig.maxRetransmits;
    RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
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
    await Future.wait(
      webRTCSessions.values.map((sess) async {
        sess.pc?.onIceCandidate = null;
        sess.pc?.onTrack = null;
        await sess.pc?.close();
        await sess.pc?.dispose();
        await sess.dc?.close();
      }),
    );
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
      onCallStateChange?.call(session!, WebRTCCallState.callStateBye);
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
    _videoSource = VideoSource.camera;
    webRTCSessions.remove(session.sid);
  }

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
    final currentSession = session;
    if (currentSession == null) {
      iPrint('> rtc sendBye: session is null, skipping');
      return;
    }
    sendWebRTCMsg(
      'bye',
      {'sid': currentSession.sid},
      msgId: msgId,
      to: currentSession.peerId,
    );
    var s = webRTCSessions[currentSession.sid];
    if (s != null) {
      _closeSession(s);
    }
  }

  /// 尝试 ICE 重启（带重试限制）
  void _attemptIceRestart() {
    final currentSession = session;
    if (currentSession?.pc == null) {
      iPrint('> rtc _attemptIceRestart: no peer connection');
      return;
    }

    if (_iceRestartCount < _maxIceRestarts) {
      _iceRestartCount++;
      iPrint('> rtc ICE restart attempt $_iceRestartCount/$_maxIceRestarts');
      currentSession!.pc!.restartIce();
    } else {
      iPrint('> rtc ICE restart max attempts reached, connection failed');
      // 超过重试次数，通知连接失败
      onCallStateChange?.call(currentSession!, WebRTCCallState.callStateBye);
      updateStateTips(t.errorNetwork);
    }
  }

  /// 解析 ICE 候选类型
  /// 返回: host, srflx, prflx, relay, 或 unknown
  String _parseIceCandidateType(String candidate) {
    // ICE 候选字符串格式示例:
    // a=candidate:4234997325 1 udp 2043278322 192.168.0.1 52324 typ host
    // a=candidate:4234997325 1 udp 2043278322 10.0.0.1 52324 typ srflx
    // a=candidate:4234997325 1 udp 2043278322 10.0.0.1 52324 typ relay
    if (candidate.contains('typ host')) {
      return 'host'; // 本地候选
    } else if (candidate.contains('typ srflx')) {
      return 'srflx'; // 服务器反射候选（STUN）
    } else if (candidate.contains('typ prflx')) {
      return 'prflx'; // 对等反射候选
    } else if (candidate.contains('typ relay')) {
      return 'relay'; // 中继候选（TURN）
    }
    return 'unknown';
  }

  void switchCamera() {
    if (_localStream != null) {
      if (_videoSource != VideoSource.camera) {
        for (var sender in _senders) {
          if (sender.track!.kind == 'video') {
            sender.replaceTrack(_localStream!.getVideoTracks()[0]);
          }
        }
        _videoSource = VideoSource.camera;
        onLocalStream?.call(_localStream!);
      } else {
        Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      }
    }
  }

  void switchToScreenSharing(MediaStream stream) {
    if (_localStream != null && _videoSource != VideoSource.screen) {
      for (var sender in _senders) {
        if (sender.track!.kind == 'video') {
          sender.replaceTrack(stream.getVideoTracks()[0]);
        }
      }
      onLocalStream?.call(stream);
      _videoSource = VideoSource.screen;
    }
  }

  void switchSpeaker(bool speakerOn) {
    if (_localStream != null) {
      MediaStreamTrack audioTrack = _localStream!.getAudioTracks()[0];
      audioTrack.enableSpeakerphone(speakerOn);
    }
  }

  bool? turnMicrophone() {
    iPrint("> rtc turnMicrophone");
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
      return enabled;
    }
    return null;
  }

  void turnCamera() {
    if (_localStream!.getVideoTracks().isNotEmpty) {
      bool muted = !state.cameraOff;
      state = state.copyWith(cameraOff: muted);
      _localStream!.getVideoTracks()[0].enabled = !muted;
    }
  }

  void updateStateTips(String tips) {
    state = state.copyWith(stateTips: tips);
  }

  void updateConnected(bool isConnected, {double? width}) {
    state = state.copyWith(
      connected: isConnected,
      localX: width != null
          ? width - CallUILayoutConfig.localVideoOffsetX
          : state.localX,
      localY: CallUILayoutConfig.localVideoInitialY,
    );
  }

  void startCallTimer(void Function() onUpdate) {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callSeconds++;
      final minutes = _callSeconds ~/ 60;
      final seconds = _callSeconds % 60;
      state = state.copyWith(
        callDuration:
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      );
      onUpdate();
    });
  }

  void stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  void stopAnswerTimer() {
    _answerTimer?.cancel();
    _answerTimer = null;
  }

  void startAnswerTimer(VoidCallback onTimeout) {
    _answerTimer = Timer(
      const Duration(seconds: CallTimeoutConfig.answerTimeout),
      () {
        onTimeout();
      },
    );
  }

  void toggleShowTool() {
    state = state.copyWith(showTool: !state.showTool);
  }

  void toggleMinimized() {
    state = state.copyWith(minimized: !state.minimized);
  }

  void updateLocalPosition(double x, double y) {
    state = state.copyWith(localX: x, localY: y);
  }

  Future<Map<String, dynamic>?> _getIceConf({
    String from = 'incomingCallScreen',
  }) async {
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    Map<String, dynamic> turnCredential = await userApi.turnCredential();
    // 不在日志中输出 TURN 凭证（含 username/credential）
    if (turnCredential.isEmpty && from == 'openCallScreen') {
      EasyLoading.showError(t.failedRequestPleaseCheckNetwork);
      return null;
    } else if (turnCredential.isEmpty) {
      return null;
    }
    // 解析 TURN URL 并生成 TCP 版本（用于防火墙/运营商封锁 UDP 时）
    final turnUrls = turnCredential['turn_urls'];
    String turnTcpUrl = '';
    if (turnUrls is String && turnUrls.contains('udp')) {
      turnTcpUrl = turnUrls.replaceAll('udp', 'tcp');
    }

    return {
      'iceServers': [
        // STUN 服务器
        {'urls': turnCredential['stun_urls']},
        // Google STUN 作为备用
        {'urls': 'stun:stun.l.google.com:19302'},
        // TURN UDP
        {
          'urls': turnUrls,
          'username': turnCredential['username'],
          'credential': turnCredential['credential'],
        },
        // TURN TCP（关键：用于 UDP 被封锁的场景）
        if (turnTcpUrl.isNotEmpty)
          {
            'urls': turnTcpUrl,
            'username': turnCredential['username'],
            'credential': turnCredential['credential'],
          },
      ],
      // 关键修复：从 0 改为 10，确保 ICE 候选充分收集
      "iceCandidatePoolSize": 10,
      "encodedInsertableStreams": false,
      "bundlePolicy": "balanced",
      // 使用所有可用传输方式，NAT 穿透困难时会自动使用 TURN relay
      'iceTransportPolicy': 'all',
      "rtcpMuxPolicy": "require",
      'sdpSemantics': 'unified-plan',
    };
  }

  void cleanup() {
    _callTimer?.cancel();
    _answerTimer?.cancel();
    _iceDisconnectTimer?.cancel();
    _iceDisconnectTimer = null;
    _iceRestartCount = 0;
  }
}
