/// Web 平台 WebRTC 服务
///
/// 提供视频通话和屏幕共享功能：
/// - 点对点视频通话
/// - 音频通话
/// - 屏幕共享
/// - 媒体流管理
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'webrtc_service.g.dart';

/// WebRTC 连接状态
enum WebRTCConnectionState {
  /// 未连接
  disconnected,

  /// 正在连接
  connecting,

  /// 已连接
  connected,

  /// 连接失败
  failed,

  /// 正在重连
  reconnecting,
}

/// 媒体类型
enum MediaType {
  /// 音频
  audio,

  /// 视频
  video,

  /// 屏幕共享
  screen,
}

/// 通话类型
enum CallType {
  /// 音频通话
  audio,

  /// 视频通话
  video,
}

/// WebRTC 状态
class WebRTCState {
  final WebRTCConnectionState connectionState;
  final String? localStreamId;
  final String? remoteStreamId;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isScreenSharing;
  final String? currentCallId;
  final String? callerId;
  final String? calleeId;
  final CallType? callType;
  final Duration? callDuration;
  final String? errorMessage;

  const WebRTCState({
    this.connectionState = WebRTCConnectionState.disconnected,
    this.localStreamId,
    this.remoteStreamId,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isScreenSharing = false,
    this.currentCallId,
    this.callerId,
    this.calleeId,
    this.callType,
    this.callDuration,
    this.errorMessage,
  });

  WebRTCState copyWith({
    WebRTCConnectionState? connectionState,
    String? localStreamId,
    String? remoteStreamId,
    bool? isAudioEnabled,
    bool? isVideoEnabled,
    bool? isScreenSharing,
    String? currentCallId,
    String? callerId,
    String? calleeId,
    CallType? callType,
    Duration? callDuration,
    String? errorMessage,
    bool clearError = false,
    bool clearCallDuration = false,
  }) {
    return WebRTCState(
      connectionState: connectionState ?? this.connectionState,
      localStreamId: localStreamId ?? this.localStreamId,
      remoteStreamId: remoteStreamId ?? this.remoteStreamId,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      currentCallId: currentCallId ?? this.currentCallId,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      callType: callType ?? this.callType,
      callDuration: clearCallDuration ? null : (callDuration ?? this.callDuration),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isInCall => connectionState == WebRTCConnectionState.connected;
  bool get isConnecting => connectionState == WebRTCConnectionState.connecting;
}

/// WebRTC 信令消息
class WebRTCSignalingMessage {
  final String type;
  final Map<String, dynamic> payload;
  final String from;
  final String to;
  final int timestamp;

  const WebRTCSignalingMessage({
    required this.type,
    required this.payload,
    required this.from,
    required this.to,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
        'from': from,
        'to': to,
        'timestamp': timestamp,
      };

  factory WebRTCSignalingMessage.fromJson(Map<String, dynamic> json) {
    return WebRTCSignalingMessage(
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      from: json['from'] as String,
      to: json['to'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}

/// WebRTC 服务
class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  WebRTCState _state = const WebRTCState();
  WebRTCState get state => _state;

  final StreamController<WebRTCState> _stateController =
      StreamController<WebRTCState>.broadcast();
  Stream<WebRTCState> get stateStream => _stateController.stream;

  final StreamController<WebRTCSignalingMessage> _signalingController =
      StreamController<WebRTCSignalingMessage>.broadcast();
  Stream<WebRTCSignalingMessage> get signalingStream => _signalingController.stream;

  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  /// 初始化 WebRTC
  Future<bool> initialize() async {
    if (!kIsWeb) {
      debugPrint('WebRTCService: 仅支持 Web 平台');
      return false;
    }

    try {
      // 检查 WebRTC 支持
      final supported = await _checkWebRTCSupport();
      if (!supported) {
        debugPrint('WebRTCService: 浏览器不支持 WebRTC');
        return false;
      }

      debugPrint('WebRTCService: 初始化完成');
      return true;
    } catch (e) {
      debugPrint('WebRTCService: 初始化失败 - $e');
      return false;
    }
  }

  /// 检查 WebRTC 支持
  Future<bool> _checkWebRTCSupport() async {
    if (!kIsWeb) return false;

    // 在实际实现中，检查 RTCPeerConnection 是否可用
    return true;
  }

  /// 发起视频通话
  Future<void> startVideoCall({
    required String callId,
    required String calleeId,
    required String callerId,
  }) async {
    if (!kIsWeb) return;

    _updateState(_state.copyWith(
      connectionState: WebRTCConnectionState.connecting,
      currentCallId: callId,
      calleeId: calleeId,
      callerId: callerId,
      callType: CallType.video,
      isVideoEnabled: true,
      isAudioEnabled: true,
    ));

    try {
      // 获取本地媒体流
      await _getLocalMediaStream(video: true, audio: true);

      // 创建 PeerConnection
      await _createPeerConnection();

      // 创建 Offer
      await _createOffer();

      // 发送信令消息
      _sendSignalingMessage(
        type: 'call_offer',
        payload: {
          'callId': callId,
          'callType': 'video',
        },
        from: callerId,
        to: calleeId,
      );

      debugPrint('WebRTCService: 发起视频通话 $callId');
    } catch (e) {
      debugPrint('WebRTCService: 发起视频通话失败 - $e');
      _updateState(_state.copyWith(
        connectionState: WebRTCConnectionState.failed,
        errorMessage: '发起通话失败: $e',
      ));
    }
  }

  /// 发起音频通话
  Future<void> startAudioCall({
    required String callId,
    required String calleeId,
    required String callerId,
  }) async {
    if (!kIsWeb) return;

    _updateState(_state.copyWith(
      connectionState: WebRTCConnectionState.connecting,
      currentCallId: callId,
      calleeId: calleeId,
      callerId: callerId,
      callType: CallType.audio,
      isVideoEnabled: false,
      isAudioEnabled: true,
    ));

    try {
      // 获取本地媒体流
      await _getLocalMediaStream(video: false, audio: true);

      // 创建 PeerConnection
      await _createPeerConnection();

      // 创建 Offer
      await _createOffer();

      // 发送信令消息
      _sendSignalingMessage(
        type: 'call_offer',
        payload: {
          'callId': callId,
          'callType': 'audio',
        },
        from: callerId,
        to: calleeId,
      );

      debugPrint('WebRTCService: 发起音频通话 $callId');
    } catch (e) {
      debugPrint('WebRTCService: 发起音频通话失败 - $e');
      _updateState(_state.copyWith(
        connectionState: WebRTCConnectionState.failed,
        errorMessage: '发起通话失败: $e',
      ));
    }
  }

  /// 接听通话
  Future<void> answerCall({
    required String callId,
    required String callerId,
    required String calleeId,
  }) async {
    if (!kIsWeb) return;

    _updateState(_state.copyWith(
      connectionState: WebRTCConnectionState.connecting,
      currentCallId: callId,
      callerId: callerId,
      calleeId: calleeId,
    ));

    try {
      // 获取本地媒体流
      await _getLocalMediaStream(
        video: _state.callType == CallType.video,
        audio: true,
      );

      // 创建 PeerConnection
      await _createPeerConnection();

      // 创建 Answer
      await _createAnswer();

      // 发送信令消息
      _sendSignalingMessage(
        type: 'call_answer',
        payload: {'callId': callId},
        from: calleeId,
        to: callerId,
      );

      debugPrint('WebRTCService: 接听通话 $callId');
    } catch (e) {
      debugPrint('WebRTCService: 接听通话失败 - $e');
      _updateState(_state.copyWith(
        connectionState: WebRTCConnectionState.failed,
        errorMessage: '接听通话失败: $e',
      ));
    }
  }

  /// 拒绝通话
  Future<void> rejectCall({
    required String callId,
    required String callerId,
    required String calleeId,
  }) async {
    _sendSignalingMessage(
      type: 'call_reject',
      payload: {'callId': callId},
      from: calleeId,
      to: callerId,
    );

    _endCall();
    debugPrint('WebRTCService: 拒绝通话 $callId');
  }

  /// 结束通话
  Future<void> endCall() async {
    if (_state.currentCallId == null) return;

    final callId = _state.currentCallId!;
    final peerId = _state.calleeId ?? _state.callerId;

    // 发送结束信令
    if (peerId != null) {
      _sendSignalingMessage(
        type: 'call_end',
        payload: {'callId': callId},
        from: _state.callerId ?? _state.calleeId ?? '',
        to: peerId,
      );
    }

    _endCall();
    debugPrint('WebRTCService: 结束通话 $callId');
  }

  /// 内部结束通话
  void _endCall() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDuration = Duration.zero;

    _updateState(const WebRTCState());
  }

  /// 切换音频
  Future<void> toggleAudio() async {
    if (!_state.isInCall) return;

    final newEnabled = !_state.isAudioEnabled;
    await _setMediaEnabled(MediaType.audio, newEnabled);

    _updateState(_state.copyWith(isAudioEnabled: newEnabled));
    debugPrint('WebRTCService: 音频 ${newEnabled ? '开启' : '关闭'}');
  }

  /// 切换视频
  Future<void> toggleVideo() async {
    if (!_state.isInCall) return;

    final newEnabled = !_state.isVideoEnabled;
    await _setMediaEnabled(MediaType.video, newEnabled);

    _updateState(_state.copyWith(isVideoEnabled: newEnabled));
    debugPrint('WebRTCService: 视频 ${newEnabled ? '开启' : '关闭'}');
  }

  /// 开始屏幕共享
  Future<void> startScreenShare() async {
    if (!kIsWeb || _state.isScreenSharing) return;

    try {
      // 获取屏幕共享流
      await _getScreenShareStream();

      _updateState(_state.copyWith(isScreenSharing: true));
      debugPrint('WebRTCService: 开始屏幕共享');
    } catch (e) {
      debugPrint('WebRTCService: 开始屏幕共享失败 - $e');
    }
  }

  /// 停止屏幕共享
  Future<void> stopScreenShare() async {
    if (!_state.isScreenSharing) return;

    try {
      // 停止屏幕共享流
      await _stopScreenShareStream();

      _updateState(_state.copyWith(isScreenSharing: false));
      debugPrint('WebRTCService: 停止屏幕共享');
    } catch (e) {
      debugPrint('WebRTCService: 停止屏幕共享失败 - $e');
    }
  }

  /// 处理信令消息
  Future<void> handleSignalingMessage(WebRTCSignalingMessage message) async {
    debugPrint('WebRTCService: 收到信令消息 ${message.type}');

    switch (message.type) {
      case 'call_offer':
        // 收到通话请求
        _updateState(_state.copyWith(
          callerId: message.from,
          callType: message.payload['callType'] == 'video'
              ? CallType.video
              : CallType.audio,
        ));
        break;

      case 'call_answer':
        // 对方接听
        await _handleAnswer(message.payload);
        break;

      case 'call_reject':
        // 对方拒绝
        _endCall();
        break;

      case 'call_end':
        // 对方挂断
        _endCall();
        break;

      case 'ice_candidate':
        // ICE Candidate
        await _handleIceCandidate(message.payload);
        break;

      default:
        debugPrint('WebRTCService: 未知信令消息类型 ${message.type}');
    }
  }

  // ============ 私有方法 ============

  void _updateState(WebRTCState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  Future<void> _getLocalMediaStream({
    required bool video,
    required bool audio,
  }) async {
    // 实际实现需要使用 Web API
    debugPrint('WebRTCService: 获取本地媒体流 video=$video, audio=$audio');
  }

  Future<void> _createPeerConnection() async {
    // 实际实现需要使用 RTCPeerConnection
    debugPrint('WebRTCService: 创建 PeerConnection');
  }

  Future<void> _createOffer() async {
    // 实际实现需要创建 SDP Offer
    debugPrint('WebRTCService: 创建 Offer');
  }

  Future<void> _createAnswer() async {
    // 实际实现需要创建 SDP Answer
    debugPrint('WebRTCService: 创建 Answer');
  }

  Future<void> _setMediaEnabled(MediaType type, bool enabled) async {
    // 实际实现需要控制媒体轨道
    debugPrint('WebRTCService: 设置媒体 $type enabled=$enabled');
  }

  Future<void> _getScreenShareStream() async {
    // 实际实现需要使用 getDisplayMedia
    debugPrint('WebRTCService: 获取屏幕共享流');
  }

  Future<void> _stopScreenShareStream() async {
    // 实际实现需要停止屏幕共享轨道
    debugPrint('WebRTCService: 停止屏幕共享流');
  }

  Future<void> _handleAnswer(Map<String, dynamic> payload) async {
    // 处理 Answer
    _updateState(_state.copyWith(
      connectionState: WebRTCConnectionState.connected,
    ));
    _startCallTimer();
    debugPrint('WebRTCService: 处理 Answer，通话建立');
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> payload) async {
    // 处理 ICE Candidate
    debugPrint('WebRTCService: 处理 ICE Candidate');
  }

  void _sendSignalingMessage({
    required String type,
    required Map<String, dynamic> payload,
    required String from,
    required String to,
  }) {
    final message = WebRTCSignalingMessage(
      type: type,
      payload: payload,
      from: from,
      to: to,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _signalingController.add(message);
  }

  void _startCallTimer() {
    _callDuration = Duration.zero;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration += const Duration(seconds: 1);
      _updateState(_state.copyWith(callDuration: _callDuration));
    });
  }

  /// 销毁服务
  void dispose() {
    _callTimer?.cancel();
    _stateController.close();
    _signalingController.close();
  }
}

/// WebRTC 服务 Provider
@riverpod
class WebRTCNotifier extends _$WebRTCNotifier {
  final WebRTCService _service = WebRTCService();

  @override
  WebRTCState build() {
    _service.initialize();
    ref.onDispose(() => _service.dispose());

    // 监听状态变化
    _service.stateStream.listen((state) {
      this.state = state;
    });

    return _service.state;
  }

  Future<void> startVideoCall({
    required String callId,
    required String calleeId,
    required String callerId,
  }) async {
    await _service.startVideoCall(
      callId: callId,
      calleeId: calleeId,
      callerId: callerId,
    );
  }

  Future<void> startAudioCall({
    required String callId,
    required String calleeId,
    required String callerId,
  }) async {
    await _service.startAudioCall(
      callId: callId,
      calleeId: calleeId,
      callerId: callerId,
    );
  }

  Future<void> answerCall({
    required String callId,
    required String callerId,
    required String calleeId,
  }) async {
    await _service.answerCall(
      callId: callId,
      callerId: callerId,
      calleeId: calleeId,
    );
  }

  Future<void> rejectCall({
    required String callId,
    required String callerId,
    required String calleeId,
  }) async {
    await _service.rejectCall(
      callId: callId,
      callerId: callerId,
      calleeId: calleeId,
    );
  }

  Future<void> endCall() async {
    await _service.endCall();
  }

  Future<void> toggleAudio() async {
    await _service.toggleAudio();
  }

  Future<void> toggleVideo() async {
    await _service.toggleVideo();
  }

  Future<void> startScreenShare() async {
    await _service.startScreenShare();
  }

  Future<void> stopScreenShare() async {
    await _service.stopScreenShare();
  }

  void handleSignalingMessage(WebRTCSignalingMessage message) {
    _service.handleSignalingMessage(message);
  }
}

/// 全局实例
final webrtcService = WebRTCService();

/// 视频通话界面组件
class VideoCallWidget extends ConsumerWidget {
  final String callId;
  final String peerId;
  final String peerName;
  final String peerAvatar;
  final CallType callType;

  const VideoCallWidget({
    super.key,
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.callType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webrtcState = ref.watch(webRTCNotifierProvider);

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 远程视频（全屏）
          _buildRemoteVideo(webrtcState),

          // 本地视频（小窗）
          _buildLocalVideo(webrtcState),

          // 顶部信息栏
          _buildTopBar(context, webrtcState),

          // 底部控制栏
          _buildBottomControls(context, ref, webrtcState),
        ],
      ),
    );
  }

  Widget _buildRemoteVideo(WebRTCState state) {
    return Positioned.fill(
      child: state.remoteStreamId != null
          ? Container(
              color: Colors.grey.shade900,
              child: const Center(
                child: Icon(Icons.videocam, size: 64, color: Colors.white54),
              ),
            )
          : Container(
              color: Colors.grey.shade900,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: peerAvatar.isNotEmpty
                          ? NetworkImage(peerAvatar) as ImageProvider
                          : null,
                      child: peerAvatar.isEmpty
                          ? Text(
                              peerName.isNotEmpty ? peerName[0] : '?',
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusText(state),
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocalVideo(WebRTCState state) {
    if (!state.isVideoEnabled) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Center(
          child: Icon(Icons.videocam, size: 32, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WebRTCState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(180),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            Text(
              _formatDuration(state.callDuration ?? Duration.zero),
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const Spacer(),
            if (state.isScreenSharing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.screen_share, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '共享中',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    WidgetRef ref,
    WebRTCState state,
  ) {
    final notifier = ref.read(webRTCNotifierProvider.notifier);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          bottom: MediaQuery.of(context).padding.bottom + 32,
          top: 32,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withAlpha(180),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 音频开关
            _buildControlButton(
              icon: state.isAudioEnabled ? Icons.mic : Icons.mic_off,
              label: state.isAudioEnabled ? '静音' : '取消静音',
              backgroundColor:
                  state.isAudioEnabled ? Colors.white24 : Colors.red,
              onPressed: notifier.toggleAudio,
            ),

            // 视频开关（仅视频通话）
            if (callType == CallType.video)
              _buildControlButton(
                icon: state.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                label: state.isVideoEnabled ? '关闭视频' : '开启视频',
                backgroundColor:
                    state.isVideoEnabled ? Colors.white24 : Colors.red,
                onPressed: notifier.toggleVideo,
              ),

            // 屏幕共享
            _buildControlButton(
              icon: state.isScreenSharing
                  ? Icons.stop_screen_share
                  : Icons.screen_share,
              label: state.isScreenSharing ? '停止共享' : '共享屏幕',
              backgroundColor:
                  state.isScreenSharing ? const Color(0xFF00A884) : Colors.white24,
              onPressed: state.isScreenSharing
                  ? notifier.stopScreenShare
                  : notifier.startScreenShare,
            ),

            // 挂断
            _buildControlButton(
              icon: Icons.call_end,
              label: '挂断',
              backgroundColor: Colors.red,
              onPressed: notifier.endCall,
              isLarge: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    final size = isLarge ? 64.0 : 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isLarge ? 28 : 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  String _getStatusText(WebRTCState state) {
    switch (state.connectionState) {
      case WebRTCConnectionState.connecting:
        return '正在连接...';
      case WebRTCConnectionState.connected:
        return '通话中';
      case WebRTCConnectionState.failed:
        return '连接失败';
      case WebRTCConnectionState.reconnecting:
        return '正在重连...';
      case WebRTCConnectionState.disconnected:
        return '通话结束';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
