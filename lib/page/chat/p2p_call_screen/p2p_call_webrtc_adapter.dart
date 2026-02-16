/// P2P Call WebRTC 适配器
///
/// 桥接新旧 WebRTC 架构，提供统一的接口
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/connection/connection_barrel.dart';
import 'package:imboy/component/webrtc/state/state_barrel.dart';
import 'package:imboy/component/webrtc/enum.dart' as old_enum;
import 'package:imboy/component/webrtc/session.dart';

/// P2P Call WebRTC 适配器
///
/// 将新的 WebRTCConnection 和 WebRTCCallStateMachine 适配到现有接口
class P2pCallWebRTCAdapter {
  /// 会话 ID
  final String sessionId;

  /// 对等端 ID
  final String peerId;

  /// 媒体类型
  final String media;

  /// 本地用户 ID
  final String localUserId;

  /// WebRTC 连接（新架构）
  WebRTCConnection? _connection;

  /// 状态机（新架构）
  WebRTCCallStateMachine? _stateMachine;

  /// 旧的 Session（兼容）
  WebRTCSession? legacySession;

  /// 信令回调
  Function(String type, Map<String, dynamic> payload, {
    String? msgId,
    String? to,
    String? debug,
  })? sendSignaling;

  /// 本地流
  MediaStream? localStream;

  /// 远程流
  MediaStream? remoteStream;

  /// 状态回调
  Function(old_enum.WebRTCCallState)? onCallStateChange;

  /// ICE 候选回调
  Function(Map<String, dynamic>)? onIceCandidate;

  /// 订阅列表
  final List<StreamSubscription> _subscriptions = [];

  /// 是否已初始化
  bool get isInitialized => _connection != null;

  /// 当前状态
  WebRTCConnectionState get connectionState =>
      _connection?.state ?? WebRTCConnectionState.idle;

  /// 通话状态
  WebRTCCallState get callState =>
      _stateMachine?.state ?? WebRTCCallState.idle;

  /// 是否已连接
  bool get isConnected => _connection?.isConnected ?? false;

  /// 获取连接实例
  WebRTCConnection? get connection => _connection;

  /// 获取状态机实例
  WebRTCCallStateMachine? get stateMachine => _stateMachine;

  /// 创建适配器实例
  P2pCallWebRTCAdapter({
    required this.sessionId,
    required this.peerId,
    required this.media,
    required this.localUserId,
  });

  /// 初始化连接
  Future<void> initialize({
    WebRTCConnectionConfig? config,
  }) async {
    iPrint('> P2pCallWebRTCAdapter: initialize $sessionId');

    // 创建状态机
    _stateMachine = WebRTCCallStateMachine(
      sessionId: sessionId,
      peerId: peerId,
      callType: _mediaToCallType(media),
      direction: WebRTCCallDirection.outgoing,
    );

    // 监听状态机变化
    _subscriptions.add(_stateMachine!.stateStream.listen((event) {
      iPrint('> P2pCallWebRTCAdapter: state changed to ${event.state}');
      _notifyLegacyStateChange(event.state);
    }));

    // 创建连接
    final mediaType = _mediaToMediaType(media);
    _connection = await WebRTCConnectionManager.instance.createConnection(
      sessionId: sessionId,
      peerId: peerId,
      mediaType: mediaType,
      config: config,
    );

    // 监听连接状态变化
    _subscriptions.add(_connection!.stateStream.listen((event) {
      iPrint('> P2pCallWebRTCAdapter: connection state ${event.state}');
    }));

    // 监听远程流
    _subscriptions.add(_connection!.remoteStreamStream.listen((stream) {
      iPrint('> P2pCallWebRTCAdapter: remote stream received');
      remoteStream = stream;
    }));

    // 监听 ICE 候选
    _subscriptions.add(_connection!.iceCandidateStream.listen((candidate) {
      if (candidate.candidate != null) {
        onIceCandidate?.call({
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        });
      }
    }));

    // 创建兼容的 Session
    legacySession = WebRTCSession(
      peerId: peerId,
      sid: sessionId,
      pc: _connection!.peerConnection,
    );
  }

  /// 设置本地流
  void setLocalStream(MediaStream stream) {
    localStream = stream;
  }

  /// 发起通话
  Future<void> invite({String? msgId}) async {
    if (_stateMachine == null || _connection == null) {
      throw StateError('Not initialized');
    }

    await _stateMachine!.startConnecting();
    final offer = await _connection!.createOffer();

    sendSignaling?.call(
      'offer',
      {
        'sid': sessionId,
        'media': media,
        'sd': {'sdp': offer.sdp, 'type': offer.type},
      },
      msgId: msgId,
      to: peerId,
      debug: 'from_createOffer',
    );
  }

  /// 接听通话
  Future<RTCSessionDescription> answer({
    required RTCSessionDescription offer,
    String? msgId,
  }) async {
    if (_stateMachine == null || _connection == null) {
      throw StateError('Not initialized');
    }

    final answer = await _connection!.createAnswer(offer);

    sendSignaling?.call(
      'answer',
      {
        'sid': sessionId,
        'media': media,
        'sd': {'sdp': answer.sdp, 'type': answer.type},
      },
      msgId: msgId,
      to: peerId,
      debug: 'from_createAnswer',
    );

    // 状态将在连接成功时自动更新
    return answer;
  }

  /// 设置远程描述
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _connection?.setRemoteDescription(description);
  }

  /// 添加 ICE 候选
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _connection?.addIceCandidate(candidate);
  }

  /// 挂断通话
  Future<void> hangup({String? reason, String? msgId}) async {
    if (_stateMachine == null) {
      return;
    }

    await _stateMachine!.hangup(reason: reason);

    // 发送 bye 消息
    sendSignaling?.call(
      'bye',
      // ignore: use_null_aware_elements
      {'sid': sessionId, if (reason != null) 'reason': reason},
      msgId: msgId,
      to: peerId,
    );

    await close();
  }

  /// 拒绝通话
  Future<void> reject({String? reason}) async {
    _stateMachine?.onRejected(reason: reason);
    await close();
  }

  /// 关闭连接
  Future<void> close() async {
    iPrint('> P2pCallWebRTCAdapter: close $sessionId');

    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _connection?.close();
    await _stateMachine?.dispose();

    _connection = null;
    _stateMachine = null;
    legacySession = null;
    localStream = null;
    remoteStream = null;
  }

  /// 切换摄像头
  void switchCamera() {
    if (localStream != null &&
        localStream!.getVideoTracks().isNotEmpty) {
      Helper.switchCamera(localStream!.getVideoTracks()[0]);
    }
  }

  /// 切换麦克风
  bool? toggleMicrophone() {
    if (localStream != null &&
        localStream!.getAudioTracks().isNotEmpty) {
      bool enabled = localStream!.getAudioTracks()[0].enabled;
      localStream!.getAudioTracks()[0].enabled = !enabled;
      return enabled;
    }
    return null;
  }

  /// 切换摄像头开关
  void toggleCamera() {
    if (localStream != null &&
        localStream!.getVideoTracks().isNotEmpty) {
      bool enabled = localStream!.getVideoTracks()[0].enabled;
      localStream!.getVideoTracks()[0].enabled = !enabled;
    }
  }

  /// 切换扬声器
  void toggleSpeaker(bool speakerOn) {
    if (localStream != null &&
        localStream!.getAudioTracks().isNotEmpty) {
      localStream!.getAudioTracks()[0].enableSpeakerphone(speakerOn);
    }
  }

  /// 通知旧架构状态变化
  void _notifyLegacyStateChange(WebRTCCallState newState) {
    old_enum.WebRTCCallState? legacyState;
    switch (newState) {
      case WebRTCCallState.idle:
        // 旧架构没有空闲状态，跳过
        return;
      case WebRTCCallState.inviting:
        legacyState = old_enum.WebRTCCallState.callStateNew;
        break;
      case WebRTCCallState.connecting:
        legacyState = old_enum.WebRTCCallState.callStateInvite;
        break;
      case WebRTCCallState.reconnecting:
        // 重连中，使用连接中状态表示
        legacyState = old_enum.WebRTCCallState.callStateInvite;
        break;
      case WebRTCCallState.ringing:
        legacyState = old_enum.WebRTCCallState.callStateRinging;
        break;
      case WebRTCCallState.connected:
        legacyState = old_enum.WebRTCCallState.callStateConnected;
        break;
      case WebRTCCallState.ended:
        legacyState = old_enum.WebRTCCallState.callStateBye;
        break;
      case WebRTCCallState.failed:
        // 旧架构没有失败状态，使用忙状态代替
        legacyState = old_enum.WebRTCCallState.callStateBusy;
        break;
      case WebRTCCallState.busy:
        legacyState = old_enum.WebRTCCallState.callStateBusy;
        break;
      case WebRTCCallState.rejected:
        legacyState = old_enum.WebRTCCallState.callStateBusy;
        break;
      case WebRTCCallState.unanswered:
        // 旧架构没有未接听状态，使用忙状态代替
        legacyState = old_enum.WebRTCCallState.callStateBusy;
        break;
      case WebRTCCallState.paused:
        // 没有对应的旧状态
        return;
      case WebRTCCallState.muted:
        // 静音状态，没有对应的旧状态
        return;
    }

    // All cases either assign legacyState or return early, so legacyState is non-null here
    onCallStateChange?.call(legacyState);
  }

  /// 媒体字符串转 MediaType
  WebRTCMediaType _mediaToMediaType(String media) {
    switch (media) {
      case 'audio':
        return WebRTCMediaType.audio;
      case 'video':
        return WebRTCMediaType.video;
      case 'data':
        return WebRTCMediaType.data;
      default:
        return WebRTCMediaType.video;
    }
  }

  /// 媒体字符串转 CallType
  WebRTCCallType _mediaToCallType(String media) {
    switch (media) {
      case 'audio':
        return WebRTCCallType.audio;
      case 'video':
        return WebRTCCallType.video;
      default:
        return WebRTCCallType.video;
    }
  }

  /// 处理接收到的信令消息
  void handleSignalingMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'offer':
        _stateMachine?.onRinging();
        break;
      case 'answer':
        // 连接成功，状态将在实际连接时更新
        break;
      case 'ringing':
        _stateMachine?.onRinging();
        break;
      case 'busy':
        _stateMachine?.onBusy(reason: '对方忙');
        break;
      case 'bye':
        _stateMachine?.hangup(reason: '对方挂断');
        break;
    }
  }
}

/// 扩展 WebRTCConnection 以支持本地流设置
extension WebRTCConnectionLocalStream on WebRTCConnection {
  /// 设置本地流（需要在 initialize 后调用）
  Future<void> setLocalStream(MediaStream stream) async {
    final pc = peerConnection;
    if (pc == null) {
      debugPrint('WebRTCConnection: PeerConnection is null, cannot set local stream');
      return;
    }

    // 添加本地流的所有轨道到 PeerConnection
    for (var track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }
  }
}
