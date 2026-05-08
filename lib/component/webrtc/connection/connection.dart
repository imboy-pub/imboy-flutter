/// WebRTC 连接
///
/// 封装单个 WebRTC 连接的生命周期和操作
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'connection_state.dart';
import 'connection_config.dart';
import '../reconnect/reconnect_manager.dart';
import '../quality/quality_monitor.dart';

/// WebRTC 连接类
///
/// 负责管理单个 P2P 连接的完整生命周期
class WebRTCConnection {
  /// 会话 ID
  final String sessionId;

  /// 对等端 ID
  final String peerId;

  /// 媒体类型
  final WebRTCMediaType mediaType;

  /// 连接配置
  final WebRTCConnectionConfig config;

  /// RTCPeerConnection 实例
  RTCPeerConnection? _pc;

  /// 本地媒体流
  MediaStream? _localStream;

  /// 远程媒体流
  MediaStream? _remoteStream;

  /// 数据通道
  RTCDataChannel? _dataChannel;

  /// 当前状态
  WebRTCConnectionState _state = WebRTCConnectionState.idle;

  /// 状态变更流控制器
  final StreamController<WebRTCConnectionStateEvent> _stateController =
      StreamController<WebRTCConnectionStateEvent>.broadcast();

  /// 远程流变更流控制器
  final StreamController<MediaStream> _remoteStreamController =
      StreamController<MediaStream>.broadcast();

  /// ICE 候选流控制器
  final StreamController<RTCIceCandidate> _iceCandidateController =
      StreamController<RTCIceCandidate>.broadcast();

  /// 数据通道消息流控制器
  final StreamController<String> _dataChannelMessageController =
      StreamController<String>.broadcast();

  /// ICE 候选收集完成标志
  bool _iceGatheringComplete = false;

  /// 重连管理器
  WebRTCReconnectManager? _reconnectManager;

  /// 网络质量监控器
  WebRTCNetworkQualityMonitor? _qualityMonitor;

  /// 连接状态变更流
  Stream<WebRTCConnectionStateEvent> get stateStream => _stateController.stream;

  /// 远程流变更流
  Stream<MediaStream> get remoteStreamStream => _remoteStreamController.stream;

  /// ICE 候选流
  Stream<RTCIceCandidate> get iceCandidateStream =>
      _iceCandidateController.stream;

  /// 数据通道消息流
  Stream<String> get dataChannelMessageStream =>
      _dataChannelMessageController.stream;

  /// 当前状态
  WebRTCConnectionState get state => _state;

  /// PeerConnection 实例（只读）
  RTCPeerConnection? get peerConnection => _pc;

  /// 本地流（只读）
  MediaStream? get localStream => _localStream;

  /// 远程流（只读）
  MediaStream? get remoteStream => _remoteStream;

  /// 数据通道（只读）
  RTCDataChannel? get dataChannel => _dataChannel;

  /// 是否已连接
  bool get isConnected => _state == WebRTCConnectionState.connected;

  /// 是否已关闭
  bool get isClosed => _state == WebRTCConnectionState.closed;

  /// 质量评分流
  Stream<int> get qualityScoreStream =>
      _qualityMonitor?.qualityScoreStream ?? const Stream.empty();

  /// 创建连接实例
  WebRTCConnection({
    required this.sessionId,
    required this.peerId,
    required this.mediaType,
    WebRTCConnectionConfig? config,
  }) : config = config ?? WebRTCConnectionConfig.defaultConfig();

  /// 初始化连接
  ///
  /// 创建 PeerConnection、获取本地流、设置事件监听
  Future<void> initialize() async {
    if (_state != WebRTCConnectionState.idle) {
      throw StateError('Connection already initialized or closed');
    }

    _setState(WebRTCConnectionState.initializing);

    try {
      // 获取 ICE 配置
      final iceConfig = await _getIceConfiguration();

      // 创建 PeerConnection
      _pc = await createPeerConnection(iceConfig);

      // 设置事件监听
      _setupPeerConnectionListeners();

      // 获取本地流
      if (mediaType != WebRTCMediaType.data) {
        await _createLocalStream();
      }

      // 创建数据通道（如果需要）
      if (config.enableDataChannel && mediaType != WebRTCMediaType.data) {
        await _createDataChannel();
      }

      // 初始化重连管理器
      if (config.reconnectConfig.enabled) {
        _reconnectManager = WebRTCReconnectManager(
          config: config.reconnectConfig,
          onReconnect: () async {
            await _restartIce();
          },
          onSendHeartbeat: () async {
            // 通过数据通道发送心跳消息
            if (_dataChannel != null &&
                _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
              try {
                final heartbeatMsg = jsonEncode({
                  'type': 'heartbeat',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                });
                _dataChannel!.send(RTCDataChannelMessage(heartbeatMsg));
                return true;
              } catch (e) {
                debugPrint('Failed to send heartbeat: $e');
                return false;
              }
            }
            return false;
          },
        );
      }

      // 初始化质量监控器
      if (config.qualityConfig.enabled) {
        _qualityMonitor = WebRTCNetworkQualityMonitor(
          connection: this,
          config: config.qualityConfig,
        );
      }

      _setState(WebRTCConnectionState.ready);
    } catch (e, s) {
      debugPrint('WebRTCConnection initialize error: $e\n$s');
      _setState(WebRTCConnectionState.failed, error: e.toString());
      rethrow;
    }
  }

  /// 创建 Offer
  Future<RTCSessionDescription> createOffer() async {
    if (_state != WebRTCConnectionState.ready) {
      throw StateError('Connection not ready, current state: $_state');
    }

    _setState(WebRTCConnectionState.creatingOffer);

    try {
      final offer = await _pc!.createOffer(config.offerConstraints);
      await _pc!.setLocalDescription(offer);

      // 如果没有数据通道，等待 ICE 收集完成
      if (!config.enableDataChannel) {
        await _waitForIceGathering();
      }

      return offer;
    } catch (e, s) {
      debugPrint('WebRTCConnection createOffer error: $e\n$s');
      _setState(WebRTCConnectionState.failed, error: e.toString());
      rethrow;
    } finally {
      if (_state == WebRTCConnectionState.creatingOffer) {
        _setState(WebRTCConnectionState.connecting);
      }
    }
  }

  /// 创建 Answer
  Future<RTCSessionDescription> createAnswer(
    RTCSessionDescription offer,
  ) async {
    if (_state != WebRTCConnectionState.ready) {
      throw StateError('Connection not ready, current state: $_state');
    }

    _setState(WebRTCConnectionState.creatingAnswer);

    try {
      await _pc!.setRemoteDescription(offer);
      final answer = await _pc!.createAnswer(config.answerConstraints);
      await _pc!.setLocalDescription(answer);

      // 等待 ICE 收集完成
      await _waitForIceGathering();

      return answer;
    } catch (e, s) {
      debugPrint('WebRTCConnection createAnswer error: $e\n$s');
      _setState(WebRTCConnectionState.failed, error: e.toString());
      rethrow;
    } finally {
      if (_state == WebRTCConnectionState.creatingAnswer) {
        _setState(WebRTCConnectionState.connecting);
      }
    }
  }

  /// 设置远程描述
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    try {
      await _pc?.setRemoteDescription(description);
    } catch (e, s) {
      debugPrint('WebRTCConnection setRemoteDescription error: $e\n$s');
      rethrow;
    }
  }

  /// 添加 ICE 候选
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _pc?.addCandidate(candidate);
    } catch (e, s) {
      debugPrint('WebRTCConnection addIceCandidate error: $e\n$s');
      // ICE 候选添加失败不视为致命错误
    }
  }

  /// 重启 ICE
  Future<void> _restartIce() async {
    try {
      await _pc?.restartIce();
    } catch (e, s) {
      debugPrint('WebRTCConnection restartIce error: $e\n$s');
      rethrow;
    }
  }

  /// 关闭连接
  Future<void> close({String? reason}) async {
    if (_state == WebRTCConnectionState.closed ||
        _state == WebRTCConnectionState.closing) {
      return;
    }

    _setState(WebRTCConnectionState.closing);

    try {
      // 停止质量监控
      await _qualityMonitor?.dispose();
      _qualityMonitor = null;

      // 停止重连
      _reconnectManager?.dispose();
      _reconnectManager = null;

      // 清理本地流
      if (_localStream != null) {
        await Future.wait(
          _localStream!.getTracks().map((track) => track.stop()),
        );
        await _localStream!.dispose();
        _localStream = null;
      }

      // 清理远程流
      _remoteStream = null;
      await _remoteStreamController.close();

      // 清理 ICE 候选流
      await _iceCandidateController.close();

      // 清理数据通道消息流
      await _dataChannelMessageController.close();

      // 关闭数据通道
      await _dataChannel?.close();
      _dataChannel = null;

      // 关闭 PeerConnection
      await _pc?.close();
      await _pc?.dispose();
      _pc = null;

      _setState(
        WebRTCConnectionState.closed,
        metadata: reason != null ? {'reason': reason} : null,
      );

      await _stateController.close();
    } catch (e, s) {
      debugPrint('WebRTCConnection close error: $e\n$s');
    }
  }

  /// 设置状态
  void _setState(
    WebRTCConnectionState newState, {
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    if (_state != newState) {
      final previousState = _state;
      _state = newState;

      final event = WebRTCConnectionStateEvent(
        state: newState,
        previousState: previousState,
        error: error,
        metadata: metadata,
      );

      _stateController.add(event);

      // 触发重连管理器回调
      if (newState == WebRTCConnectionState.connected) {
        _reconnectManager?.onConnected();
        _qualityMonitor?.startMonitoring();
      } else if (newState == WebRTCConnectionState.disconnected) {
        _reconnectManager?.onDisconnected();
      } else if (newState == WebRTCConnectionState.failed) {
        _reconnectManager?.onConnectionFailed();
      }
    }
  }

  /// 设置 PeerConnection 监听器
  void _setupPeerConnectionListeners() {
    if (_pc == null) return;

    // ICE 候选
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) {
        _iceGatheringComplete = true;
        debugPrint('ICE gathering complete for session $sessionId');
      }
      // 将 ICE 候选添加到流中
      if (!_iceCandidateController.isClosed) {
        _iceCandidateController.add(candidate);
      }
    };

    // ICE 连接状态
    _pc!.onIceConnectionState = (state) {
      debugPrint('ICE connection state: $state');
      _handleIceConnectionState(state);
    };

    // 信令状态
    _pc!.onSignalingState = (state) {
      debugPrint('Signaling state: $state');
      _handleSignalingState(state);
    };

    // 连接状态
    _pc!.onConnectionState = (state) {
      debugPrint('Connection state: $state');
      _handleConnectionState(state);
    };

    // 媒体轨道
    _pc!.onTrack = (event) {
      debugPrint('Received track: ${event.track.kind}');
      _handleRemoteTrack(event);
    };

    // 需要重新协商
    _pc!.onRenegotiationNeeded = () async {
      debugPrint('Renegotiation needed');
      // 仅在作为发起方且未在协商中时处理
      if (_state == WebRTCConnectionState.ready &&
          mediaType == WebRTCMediaType.video) {
        // 可以在这里触发重新协商
      }
    };

    // 数据通道（接收方）
    _pc!.onDataChannel = (channel) {
      debugPrint('Received data channel: ${channel.label}');
      _setupDataChannel(channel);
    };
  }

  /// 处理 ICE 连接状态
  void _handleIceConnectionState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _setState(WebRTCConnectionState.connected);
        break;

      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        _setState(WebRTCConnectionState.disconnected);
        break;

      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _setState(WebRTCConnectionState.failed);
        break;

      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        if (_state != WebRTCConnectionState.closed) {
          _setState(WebRTCConnectionState.closed);
        }
        break;

      default:
        break;
    }
  }

  /// 处理信令状态
  void _handleSignalingState(RTCSignalingState state) {
    switch (state) {
      case RTCSignalingState.RTCSignalingStateHaveLocalOffer:
      case RTCSignalingState.RTCSignalingStateHaveRemoteOffer:
        if (_state == WebRTCConnectionState.ready) {
          // 正常流程，不改变状态
        }
        break;

      case RTCSignalingState.RTCSignalingStateStable:
        if (_state == WebRTCConnectionState.connecting ||
            _state == WebRTCConnectionState.creatingOffer ||
            _state == WebRTCConnectionState.creatingAnswer) {
          _setState(WebRTCConnectionState.connecting);
        }
        break;

      default:
        break;
    }
  }

  /// 处理连接状态
  void _handleConnectionState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        // ICE 状态会处理
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _setState(WebRTCConnectionState.disconnected);
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _setState(WebRTCConnectionState.failed);
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        if (_state != WebRTCConnectionState.closed) {
          _setState(WebRTCConnectionState.closed);
        }
        break;

      default:
        break;
    }
  }

  /// 处理远程轨道
  void _handleRemoteTrack(RTCTrackEvent event) {
    if (event.streams.isNotEmpty) {
      _remoteStream = event.streams[0];
      _remoteStreamController.add(_remoteStream!);
    }
  }

  /// 获取 ICE 配置
  ///
  /// 注意：新架构应该通过 config.iceServers 传入从后端获取的 TURN 凭证
  /// 这里的默认配置只作为备用，不应在生产环境使用
  Future<Map<String, dynamic>> _getIceConfiguration() async {
    // 如果提供了自定义配置，使用它
    if (config.iceServers != null) {
      return config.iceServers!;
    }

    // 备用配置：仅用于开发测试
    // 生产环境必须通过 config.iceServers 传入后端获取的 TURN 凭证
    debugPrint(
      'WARNING: Using fallback ICE configuration without TURN servers',
    );
    return {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'iceCandidatePoolSize': 10,
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'balanced',
      'rtcpMuxPolicy': 'require',
      'sdpSemantics': 'unified-plan',
    };
  }

  /// 创建本地流
  Future<void> _createLocalStream() async {
    final constraints = config.getMediaConstraints(mediaType);
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      debugPrint('Failed to get user media: $e');
      rethrow;
    }
  }

  /// 创建数据通道
  Future<void> _createDataChannel() async {
    if (_pc == null) return;

    try {
      final dataChannelDict = RTCDataChannelInit()
        ..maxRetransmits = config.dataChannelMaxRetransmits;

      final channel = await _pc!.createDataChannel(
        config.dataChannelLabel,
        dataChannelDict,
      );

      _setupDataChannel(channel);
    } catch (e) {
      debugPrint('Failed to create data channel: $e');
      // 数据通道创建失败不是致命错误
    }
  }

  /// 设置数据通道
  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;

    channel.onDataChannelState = (state) {
      debugPrint('Data channel state: $state');
      // 数据通道状态变化时通知外部
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        debugPrint('Data channel is open and ready');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        debugPrint('Data channel is closed');
      }
    };

    channel.onMessage = (RTCDataChannelMessage data) {
      // 处理数据通道消息
      String message;
      if (data.isBinary) {
        // 二进制数据（用于文件传输）
        message = 'BINARY:${data.binary.length}';
      } else {
        // 文本消息（用于控制信令、心跳等）
        message = data.text;
      }

      // 将消息发送到流中，让外部处理
      if (!_dataChannelMessageController.isClosed) {
        _dataChannelMessageController.add(message);
      }
    };
  }

  /// 等待 ICE 收集完成
  Future<void> _waitForIceGathering() async {
    if (_iceGatheringComplete) return;

    // 等待最多 10 秒
    final completer = Completer<void>();
    late Timer timer;

    void checkIceState() {
      if (_iceGatheringComplete ||
          _state == WebRTCConnectionState.failed ||
          _state == WebRTCConnectionState.closed) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }

    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      checkIceState();
    });

    // 超时保护
    Timer(config.iceTimeout, () {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }

  /// 发送数据通道消息
  Future<void> sendDataChannelMessage(String message) async {
    if (_dataChannel == null) {
      throw StateError('Data channel not available');
    }

    if (_dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('Data channel not open');
    }

    _dataChannel!.send(RTCDataChannelMessage(message));
  }

  /// 切换摄像头
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    final track = videoTracks.first;
    await Helper.switchCamera(track);
  }

  /// 切换扬声器
  Future<void> switchSpeaker(bool enable) async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return;

    // 使用 flutter_webrtc 的 Helper.setSpeakerphoneOn 方法
    // 当 enable=true 时，使用扬声器；当 enable=false 时，使用听筒
    // 注意：如果连接了蓝牙或有线耳机，会优先使用耳机
    await Helper.setSpeakerphoneOn(enable);
  }

  /// 静音/取消静音麦克风
  bool toggleMicrophone() {
    if (_localStream == null) return false;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return false;

    final track = audioTracks.first;
    final newState = !track.enabled;
    track.enabled = newState;
    return newState;
  }

  /// 开启/关闭摄像头
  bool toggleCamera() {
    if (_localStream == null) return false;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return false;

    final track = videoTracks.first;
    final newState = !track.enabled;
    track.enabled = newState;
    return newState;
  }

  /// 释放资源
  @mustCallSuper
  Future<void> dispose() async {
    await close(reason: 'dispose');
  }
}
