import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/webrtc/media_permission.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/init.dart' show webRTCSessions, p2pCallScreenOn;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_state_machine.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'p2p_call_screen_provider.g.dart';

/// 悬浮窗松手吸附：按当前窗口中心落在屏幕左/右半区，吸附到对应边缘（FaceTime PiP 同款）。
/// 返回吸附后的 left 像素值。
double snapFloatingLeft({
  required double currentLeft,
  required double windowWidth,
  required double screenWidth,
  double margin = 10,
}) {
  final center = currentLeft + windowWidth / 2;
  final rightEdge = screenWidth - windowWidth - margin;
  return center < screenWidth / 2 ? margin : rightEdge;
}

/// 主画面上下滑动交换本端/对端视频的最小速度阈值。
bool shouldSwapVideoLayout(double? verticalVelocity, {double threshold = 280}) {
  return (verticalVelocity ?? 0).abs() > threshold;
}

/// 通话时长格式化：<1h 显示 mm:ss，≥1h 显示 hh:mm:ss（FaceTime 同款）。
String formatCallDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// P2P Call Screen 状态
class P2pCallScreenState {
  final bool cameraOff;
  final bool isFrontCamera;
  final bool micOff;
  final bool speakerOn;
  final bool connected;
  final bool showTool;
  final bool minimized;

  /// 通话阶段 + 结束原因（唯一真值源，见 [CallStatus]）。
  /// 原来是一条自由文本 stateTips，接通后无人清空导致文案与实际状态脱节。
  final CallStatus callStatus;
  final String callDuration;
  final double localX;
  final double localY;

  /// 悬浮窗位置（最小化后的小窗，left/top 像素坐标）。
  final double floatX;
  final double floatY;

  /// 网络重连中（ICE Disconnected/Failed）。用于顶部“网络不佳”横幅。
  final bool reconnecting;
  final String errorMessage;
  final MediaPermissionTarget? permissionTarget;

  const P2pCallScreenState({
    this.cameraOff = false,
    this.isFrontCamera = true,
    this.micOff = false,
    this.speakerOn = true,
    this.connected = false,
    this.showTool = true,
    this.minimized = false,
    this.callStatus = const CallStatus(),
    this.callDuration = '00:00',
    this.localX = 0.0,
    this.localY = 0.0,
    this.floatX = 0.0,
    this.floatY = 0.0,
    this.reconnecting = false,
    this.errorMessage = '',
    this.permissionTarget,
  });

  P2pCallScreenState copyWith({
    bool? cameraOff,
    bool? isFrontCamera,
    bool? micOff,
    bool? speakerOn,
    bool? connected,
    bool? showTool,
    bool? minimized,
    CallStatus? callStatus,
    String? callDuration,
    double? localX,
    double? localY,
    double? floatX,
    double? floatY,
    bool? reconnecting,
    String? errorMessage,
    MediaPermissionTarget? permissionTarget,
    bool clearPermissionTarget = false,
  }) {
    return P2pCallScreenState(
      cameraOff: cameraOff ?? this.cameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      micOff: micOff ?? this.micOff,
      speakerOn: speakerOn ?? this.speakerOn,
      connected: connected ?? this.connected,
      showTool: showTool ?? this.showTool,
      minimized: minimized ?? this.minimized,
      callStatus: callStatus ?? this.callStatus,
      callDuration: callDuration ?? this.callDuration,
      localX: localX ?? this.localX,
      localY: localY ?? this.localY,
      floatX: floatX ?? this.floatX,
      floatY: floatY ?? this.floatY,
      reconnecting: reconnecting ?? this.reconnecting,
      errorMessage: errorMessage ?? this.errorMessage,
      permissionTarget: clearPermissionTarget
          ? null
          : permissionTarget ?? this.permissionTarget,
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

  // 页面 dispose 期间置位：阻止仍在飞行中的信令回调继续操作正在被
  // cleanUpP2P() 关闭的 PeerConnection（两者并发访问同一个 pc 有崩溃风险）。
  bool _closing = false;

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
  void Function(RTCSignalingState state)? onSignalingStateChange;
  void Function(WebRTCSession? session, WebRTCCallState state)?
  onCallStateChange;
  void Function(MediaStream stream)? onLocalStream;
  void Function(WebRTCSession session, MediaStream stream)? onAddRemoteStream;
  void Function(WebRTCSession session, MediaStream stream)?
  onRemoveRemoteStream;
  void Function(
    WebRTCSession session,
    RTCDataChannel dc,
    RTCDataChannelMessage data,
  )?
  onDataChannelMessage;
  void Function(WebRTCSession session, RTCDataChannel dc)? onDataChannel;

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
    // provider 释放时统一取消所有定时器，避免定时器在 dispose 后写 state
    // 抛 "Cannot use Ref after disposed"（cleanup 原仅在手动挂断路径调用）
    ref.onDispose(cleanup);
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
    _closing = false;
    _callSeconds = 0;
  }

  Future<void> initState() async {
    iPrint("> rtc logic signalingConnect ${DateTime.now()}");
    makingOffer = false;
    makingAnswer = false;
    _closing = false;
  }

  Future<void> onMessageP2P(WebRTCSession s, WebRTCSignalingModel msg) async {
    if (_closing) {
      iPrint('> rtc onMessageP2P: 正在关闭中，忽略信令 ${msg.webRtcType}');
      return;
    }
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
        final sid = (msg.payload['sid'] ?? s.sid) as String;
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

        // Glare 仲裁（perfect negotiation 简化版）：双方几乎同时发起 offer 时，
        // 按 uid 字典序固定一方为 polite（谦让）。impolite 方直接忽略冲突的
        // 入向 offer，让自己的 offer 继续；polite 方回退本地 offer 后接受对方。
        final offerCollision =
            makingOffer ||
            s2.pc?.signalingState ==
                RTCSignalingState.RTCSignalingStateHaveLocalOffer;
        final polite = _isPolitePeer(s2.peerId);
        if (offerCollision && !polite) {
          iPrint('> rtc offer collision: impolite peer ignores incoming offer');
          return;
        }
        if (offerCollision && polite) {
          iPrint('> rtc offer collision: polite peer rolls back local offer');
          await s2.pc!.setLocalDescription(
            RTCSessionDescription('', 'rollback'),
          );
        }

        final sd2 = RTCSessionDescription(
          sd['sdp'] as String,
          sd['type'] as String,
        );
        await s2.pc!.setRemoteDescription(sd2);

        // ICE candidate 必须在 remoteDescription 设置成功后再消费，
        // 提前 addCandidate 可能被底层拒绝导致候选丢失。
        if (s2.remoteCandidates.isNotEmpty) {
          for (var candidate in s2.remoteCandidates) {
            await s2.pc?.addCandidate(candidate);
          }
          s2.remoteCandidates.clear();
        }

        await _createAnswer(s2, msg.msgId, media);
        break;
      case 'answer':
        final sid = (msg.payload['sid'] ?? s.sid) as String;
        final sd = msg.payload['sd'];
        // SDP 基本格式校验
        if (sd is! Map || sd['sdp'] is! String || sd['type'] != 'answer') {
          iPrint('> rtc WARNING: invalid SDP in answer message');
          return;
        }
        final s2 = webRTCSessions[sid];

        makingOffer = false;
        await s2!.pc?.setRemoteDescription(
          RTCSessionDescription(sd['sdp'] as String, sd['type'] as String),
        );
        // 主叫方在等待 answer 期间到达的 ICE candidate 会被 _receiveCandidate
        // 缓冲进 remoteCandidates；remoteDescription 设置成功后必须在此消费，
        // 否则会静默丢失，导致 NAT 穿透失败。
        if (s2.remoteCandidates.isNotEmpty) {
          for (var candidate in s2.remoteCandidates) {
            await s2.pc?.addCandidate(candidate);
          }
          s2.remoteCandidates.clear();
        }
        webRTCSessions[sid] = s2;
        onCallStateChange?.call(s2, WebRTCCallState.callStateConnected);
        break;
      case 'candidate':
        final peerId = msg.from;
        final candidateMap = msg.payload['candidate'];
        await _receiveCandidate(peerId, candidateMap as Map<String, dynamic>);
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

  /// Glare 仲裁角色判定：双方按 uid 字典序（与 [sessionId] 排序规则一致）
  /// 各自独立算出同一结论，无需协商。uid 较大的一方为 polite（谦让）方。
  bool _isPolitePeer(String peerId) {
    final ids = [UserRepoLocal.to.currentUid, peerId]..sort();
    return UserRepoLocal.to.currentUid == ids[1];
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
    // 跨网络 relay 定位用：记录“对端实际收到的候选类型”。
    // 只见 host=信令丢 srflx/relay；见 srflx/relay 但媒体不通=ICE/SDP 或网络层。
    final recvType = _parseIceCandidateType(candidateStr);
    String sid = sessionId(peerId);
    var s = webRTCSessions[sid];
    if (s != null && s.pc != null) {
      final description = await s.pc?.getRemoteDescription();
      if (description != null) {
        iPrint('> rtc RECV ICE candidate type=$recvType applied');
        await s.pc?.addCandidate(candidate);
      } else {
        iPrint('> rtc RECV ICE candidate type=$recvType queued(no remoteDesc)');
        s.remoteCandidates.add(candidate);
      }
      webRTCSessions[sid] = s;
    } else {
      iPrint('> rtc RECV ICE candidate type=$recvType queued(no session/pc)');
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
      updateStateError(
        t.common.permissionAcquisitionFailed,
        permissionTarget: media == 'audio'
            ? MediaPermissionTarget.microphone
            : MediaPermissionTarget.camera,
      );
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
      // 权限/设备失败时不要继续创建“无本地轨道”的连接；否则对端只会
      // 看到黑屏或无声，用户也会误以为是公网 ICE 故障。
      if (_localStream == null) return newSession;
    }
    if (newSession.pc != null) {
      return newSession;
    }

    final iceConf = await _getIceConf();
    final pc = await createPeerConnection(iceConf, _offerSdpConstraints);

    pc.onAddStream = (stream) async {
      iPrint('> rtc pc onAddStream: ${stream.id.toString()}');
    };

    pc.onTrack = (RTCTrackEvent event) {
      iPrint("> rtc onTrack ${event.track.enabled}");
      if ((event.track.kind == 'audio' || event.track.kind == 'video') &&
          event.streams.isNotEmpty) {
        onAddRemoteStream?.call(newSession, event.streams.first);
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
          // 注意：此回调参数名为 state（遮蔽 Notifier.state），故用 setReconnecting
          setReconnecting(false);
          // 走与 SDP answer 相同的“接通”入口：否则这条路径只翻 connected 标志，
          // 既不停应答超时定时器、也不启动通话计时、也不写 start_at。
          onCallStateChange?.call(
            newSession,
            WebRTCCallState.callStateConnected,
          );
          break;

        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // 断开后等待 5 秒尝试恢复（顶部横幅提示用户网络不佳）
          setReconnecting(true);
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
          setReconnecting(true);
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
    String label = DataChannelConfig.defaultLabel,
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
    // 先置位再做任何异步清理：阻止仍在飞行中的 onMessageP2P 继续读写
    // 即将被关闭/dispose 的 PeerConnection。
    _closing = true;
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
      // 超过重试次数：这是链路故障，不是对端挂断。原来复用 callStateBye
      // 会让界面显示“对方已挂断”，并把通话记录写成对端挂断。
      onCallStateChange?.call(currentSession!, WebRTCCallState.callStateFailed);
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
        state = state.copyWith(isFrontCamera: true);
        onLocalStream?.call(_localStream!);
      } else {
        final tracks = _localStream!.getVideoTracks();
        if (tracks.isEmpty) return;
        Helper.switchCamera(tracks.first);
        state = state.copyWith(isFrontCamera: !state.isFrontCamera);
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
    final tracks = _localStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    tracks.first.enableSpeakerphone(speakerOn);
    state = state.copyWith(speakerOn: speakerOn);
  }

  bool? turnMicrophone() {
    iPrint("> rtc turnMicrophone");
    final tracks = _localStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return null;
    final nextEnabled = !tracks.first.enabled;
    tracks.first.enabled = nextEnabled;
    state = state.copyWith(micOff: !nextEnabled);
    return nextEnabled;
  }

  void turnCamera() {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    final muted = !state.cameraOff;
    state = state.copyWith(cameraOff: muted);
    tracks.first.enabled = !muted;
  }

  /// 用信令/本地事件驱动状态机，返回迁移后的状态（页面据此决定收尾动作）。
  CallStatus applySignal(CallSignal signal) {
    final next = state.callStatus.apply(signal);
    if (next != state.callStatus) {
      state = state.copyWith(callStatus: next);
    }
    return next;
  }

  void updateStateError(
    String message, {
    MediaPermissionTarget? permissionTarget,
  }) {
    state = state.copyWith(
      errorMessage: message,
      permissionTarget: permissionTarget,
      clearPermissionTarget: permissionTarget == null,
    );
  }

  void updateConnected(bool isConnected, {double? width}) {
    state = state.copyWith(
      connected: isConnected,
      localX: width != null
          // localX 与页面的 Positioned(right: localX) 保持同一坐标语义。
          // 旧实现把屏幕宽度减进来，导致窄屏时小窗直接跑到屏幕外。
          ? CallUILayoutConfig.localVideoOffsetX
          : state.localX,
      localY: CallUILayoutConfig.localVideoInitialY,
    );
  }

  void setReconnecting(bool v) {
    state = state.copyWith(reconnecting: v);
  }

  void startCallTimer(void Function() onUpdate) {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 同帧竞态兜底：provider 已释放则自行取消，不再写 state
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      _callSeconds++;
      state = state.copyWith(callDuration: formatCallDuration(_callSeconds));
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
    // 重复起臂时先撤旧的，否则旧 Timer 无人持有也不会被取消。
    _answerTimer?.cancel();
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

  /// 进入悬浮窗：设定初始小窗位置（由页面用 MediaQuery 算出右上角）并最小化。
  void enterFloating(double x, double y) {
    state = state.copyWith(floatX: x, floatY: y, minimized: true);
  }

  void updateFloatPosition(double x, double y) {
    state = state.copyWith(floatX: x, floatY: y);
  }

  Future<Map<String, dynamic>> _getIceConf({
    String from = 'incomingCallScreen',
  }) async {
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    Map<String, dynamic> turnCredential = await userApi.turnCredential();
    // 不在日志中输出 TURN 凭证（含 username/credential）
    if (turnCredential.isEmpty) {
      // TURN 凭证获取失败时不再返回 null（会导致下游 `iceConf!` 强制解包崩溃），
      // 回退到纯 STUN 配置：无法穿透对称 NAT 时通话仍可能失败，但至少不崩溃。
      if (from == 'openCallScreen') {
        AppLoading.showError(t.common.failedRequestPleaseCheckNetwork);
      }
      iPrint('> rtc _getIceConf: TURN 凭证获取失败，回退纯 STUN 配置');
      return _stunOnlyIceConf();
    }
    final iceServers = buildIceServers(turnCredential);
    if (iceServers == null) {
      // 凭证 map 非空但无有效 TURN URL（如后端未配 eturnal 返回空列表）：
      // 空 urls 传给原生 IceServer.Builder 会抛 IllegalArgumentException，
      // PeerConnection 建不起来且 session=null，连挂断 bye 都发不出。
      iPrint('> rtc _getIceConf: TURN 凭证无有效 URL，回退纯 STUN 配置');
      return _stunOnlyIceConf();
    }

    return {
      'iceServers': iceServers,
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

  /// 【纯函数】从 TURN 凭证组装 iceServers；过滤空 URL 条目。
  /// 无有效 turn_urls 时返回 null（调用方降级 _stunOnlyIceConf）。
  @visibleForTesting
  static List<Map<String, dynamic>>? buildIceServers(
    Map<String, dynamic> credential,
  ) {
    bool hasUrl(dynamic v) =>
        (v is String && v.isNotEmpty) || (v is List && v.isNotEmpty);

    final turnUrls = credential['turn_urls'];
    if (!hasUrl(turnUrls)) return null;

    // 解析 TURN URL 并生成 TCP 版本（用于防火墙/运营商封锁 UDP 时）
    String turnTcpUrl = '';
    if (turnUrls is String && turnUrls.contains('udp')) {
      turnTcpUrl = turnUrls.replaceAll('udp', 'tcp');
    }
    final stunUrls = credential['stun_urls'];
    return [
      // STUN 服务器（后端未配置时跳过，避免空 urls 崩溃）
      if (hasUrl(stunUrls)) {'urls': stunUrls},
      // Google STUN 作为备用
      {'urls': 'stun:stun.l.google.com:19302'},
      // TURN UDP
      {
        'urls': turnUrls,
        'username': credential['username'],
        'credential': credential['credential'],
      },
      // TURN TCP（关键：用于 UDP 被封锁的场景）
      if (turnTcpUrl.isNotEmpty)
        {
          'urls': turnTcpUrl,
          'username': credential['username'],
          'credential': credential['credential'],
        },
    ];
  }

  /// TURN 凭证不可用时的降级配置：仅公共 STUN，无 relay 中继能力。
  Map<String, dynamic> _stunOnlyIceConf() {
    return {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'iceCandidatePoolSize': 10,
      'encodedInsertableStreams': false,
      'bundlePolicy': 'balanced',
      'iceTransportPolicy': 'all',
      'rtcpMuxPolicy': 'require',
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
