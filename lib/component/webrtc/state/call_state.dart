/// WebRTC 通话状态定义
///
/// 定义音视频通话的完整状态机
library;

/// WebRTC 通话状态
///
/// 定义从通话邀请到结束的完整生命周期
enum WebRTCCallState {
  /// 空闲 - 无通话
  idle,

  /// 发起中 - 发起方正在创建 offer
  inviting,

  /// 响铃中 - 对方收到邀请，正在等待接听
  ringing,

  /// 连接中 - 正在建立 WebRTC 连接
  connecting,

  /// 已连接 - 通话已接通，媒体流可用
  connected,

  /// 重连中 - 网络中断，正在重连
  reconnecting,

  /// 已暂停 - 通话已暂停（本地）
  paused,

  /// 已静音 - 对方已静音
  muted,

  /// 已拒绝 - 对方拒绝接听
  rejected,

  /// 忙碌 - 对方忙碌
  busy,

  /// 未接通 - 对方无响应
  unanswered,

  /// 已结束 - 通话已正常结束
  ended,

  /// 失败 - 通话失败
  failed,
}

/// 扩展通话状态的辅助方法
extension WebRTCCallStateExtension on WebRTCCallState {
  /// 是否为活跃状态（正在通话中）
  bool get isActive {
    return index >= WebRTCCallState.connecting.index &&
        index <= WebRTCCallState.connected.index;
  }

  /// 是否为终止状态（无法恢复）
  bool get isTerminal {
    return this == WebRTCCallState.rejected ||
        this == WebRTCCallState.busy ||
        this == WebRTCCallState.unanswered ||
        this == WebRTCCallState.ended ||
        this == WebRTCCallState.failed;
  }

  /// 是否可以重连
  bool get canReconnect {
    return this == WebRTCCallState.connecting ||
        this == WebRTCCallState.connected ||
        this == WebRTCCallState.reconnecting;
  }

  /// 是否为通话中的状态
  bool get isInCall {
    return this == WebRTCCallState.connected ||
        this == WebRTCCallState.reconnecting;
  }

  /// 是否为发起方相关状态
  bool get isCallerState {
    return this == WebRTCCallState.inviting || this == WebRTCCallState.ringing;
  }

  /// 是否为接收方相关状态
  bool get isCalleeState {
    return this == WebRTCCallState.ringing ||
        this == WebRTCCallState.connecting;
  }

  /// 状态的显示标签（用于 UI）
  String get label {
    switch (this) {
      case WebRTCCallState.idle:
        return '空闲';
      case WebRTCCallState.inviting:
        return '正在呼叫';
      case WebRTCCallState.ringing:
        return '正在响铃';
      case WebRTCCallState.connecting:
        return '连接中';
      case WebRTCCallState.connected:
        return '通话中';
      case WebRTCCallState.reconnecting:
        return '重连中';
      case WebRTCCallState.paused:
        return '已暂停';
      case WebRTCCallState.muted:
        return '已静音';
      case WebRTCCallState.rejected:
        return '已拒绝';
      case WebRTCCallState.busy:
        return '对方忙碌';
      case WebRTCCallState.unanswered:
        return '无响应';
      case WebRTCCallState.ended:
        return '已结束';
      case WebRTCCallState.failed:
        return '通话失败';
    }
  }

  /// 状态对应的图标名称
  String get iconName {
    switch (this) {
      case WebRTCCallState.idle:
        return 'phone_disabled';
      case WebRTCCallState.inviting:
        return 'phone_forwarded';
      case WebRTCCallState.ringing:
        return 'notifications_active';
      case WebRTCCallState.connecting:
        return 'sync';
      case WebRTCCallState.connected:
        return 'phone_in_talk';
      case WebRTCCallState.reconnecting:
        return 'sync_problem';
      case WebRTCCallState.paused:
        return 'pause_circle';
      case WebRTCCallState.muted:
        return 'mic_off';
      case WebRTCCallState.rejected:
        return 'call_missed';
      case WebRTCCallState.busy:
        return 'voice_over_off';
      case WebRTCCallState.unanswered:
        return 'call_missed_outgoing';
      case WebRTCCallState.ended:
        return 'call_end';
      case WebRTCCallState.failed:
        return 'error';
    }
  }

  /// 是否需要显示通话时长
  bool get shouldShowDuration {
    return this == WebRTCCallState.connected ||
        this == WebRTCCallState.reconnecting;
  }

  /// 是否允许挂断
  bool get canHangup {
    return !isTerminal && this != WebRTCCallState.idle;
  }

  /// 是否允许切换摄像头
  bool get canSwitchCamera {
    return this == WebRTCCallState.connected ||
        this == WebRTCCallState.reconnecting;
  }

  /// 是否允许切换麦克风
  bool get canToggleMicrophone {
    return this == WebRTCCallState.connected ||
        this == WebRTCCallState.reconnecting;
  }

  /// 是否允许切换扬声器
  bool get canToggleSpeaker {
    return this == WebRTCCallState.connected ||
        this == WebRTCCallState.reconnecting;
  }
}

/// WebRTC 通话状态变更事件
class WebRTCCallStateEvent {
  /// 新状态
  final WebRTCCallState state;

  /// 旧状态
  final WebRTCCallState? previousState;

  /// 时间戳
  final DateTime timestamp;

  /// 关联的错误信息（如果有）
  final String? error;

  /// 额外数据
  final Map<String, dynamic>? metadata;

  /// 会话 ID
  final String? sessionId;

  /// 用户 ID
  final String? userId;

  WebRTCCallStateEvent({
    required this.state,
    this.previousState,
    DateTime? timestamp,
    this.error,
    this.metadata,
    this.sessionId,
    this.userId,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 是否为错误状态
  bool get isError =>
      state == WebRTCCallState.failed ||
      (state == WebRTCCallState.rejected && error != null);

  @override
  String toString() {
    return 'CallStateEvent{state: $state, previous: $previousState, error: $error}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRTCCallStateEvent &&
        other.state == state &&
        other.previousState == previousState &&
        other.error == error &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode => Object.hash(state, previousState, error, sessionId);
}

/// WebRTC 通话方向
enum WebRTCCallDirection {
  /// 发起方
  outgoing,

  /// 接收方
  incoming,
}

/// WebRTC 通话类型
enum WebRTCCallType {
  /// 音频通话
  audio,

  /// 视频通话
  video,

  /// 屏幕共享
  screenShare,
}

/// 扩展通话类型的辅助方法
extension WebRTCCallTypeExtension on WebRTCCallType {
  /// 是否需要视频
  bool get requiresVideo {
    return this == WebRTCCallType.video || this == WebRTCCallType.screenShare;
  }

  /// 是否需要音频
  bool get requiresAudio {
    return this == WebRTCCallType.audio || this == WebRTCCallType.video;
  }

  /// 类型名称
  String get name {
    switch (this) {
      case WebRTCCallType.audio:
        return 'audio';
      case WebRTCCallType.video:
        return 'video';
      case WebRTCCallType.screenShare:
        return 'screenShare';
    }
  }

  /// 显示名称
  String get displayName {
    switch (this) {
      case WebRTCCallType.audio:
        return '语音通话';
      case WebRTCCallType.video:
        return '视频通话';
      case WebRTCCallType.screenShare:
        return '屏幕共享';
    }
  }

  /// 从字符串创建
  static WebRTCCallType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'audio':
        return WebRTCCallType.audio;
      case 'video':
        return WebRTCCallType.video;
      case 'screenshare':
      case 'screen_share':
        return WebRTCCallType.screenShare;
      default:
        return WebRTCCallType.video;
    }
  }
}

/// WebRTC 通话信息
class WebRTCCallInfo {
  /// 会话 ID
  final String sessionId;

  /// 通话 ID（消息 ID）
  final String callId;

  /// 对等端 ID
  final String peerId;

  /// 对等端显示名称
  final String? peerDisplayName;

  /// 对等端头像
  final String? peerAvatar;

  /// 通话类型
  final WebRTCCallType callType;

  /// 通话方向
  final WebRTCCallDirection direction;

  /// 当前状态
  final WebRTCCallState state;

  /// 开始时间
  final DateTime startTime;

  /// 连接时间（接通时间）
  DateTime? connectTime;

  /// 结束时间
  DateTime? endTime;

  /// 通话时长（秒）
  int get duration {
    final endTime = this.endTime ?? DateTime.now();
    final startTime = connectTime ?? this.startTime;
    return endTime.difference(startTime).inSeconds;
  }

  /// 是否已接通
  bool get isConnected => connectTime != null;

  WebRTCCallInfo({
    required this.sessionId,
    required this.callId,
    required this.peerId,
    this.peerDisplayName,
    this.peerAvatar,
    required this.callType,
    required this.direction,
    required this.state,
    required this.startTime,
    this.connectTime,
    this.endTime,
  });

  /// 复制并修改部分信息
  WebRTCCallInfo copyWith({
    String? sessionId,
    String? callId,
    String? peerId,
    String? peerDisplayName,
    String? peerAvatar,
    WebRTCCallType? callType,
    WebRTCCallDirection? direction,
    WebRTCCallState? state,
    DateTime? startTime,
    DateTime? connectTime,
    DateTime? endTime,
  }) {
    return WebRTCCallInfo(
      sessionId: sessionId ?? this.sessionId,
      callId: callId ?? this.callId,
      peerId: peerId ?? this.peerId,
      peerDisplayName: peerDisplayName ?? this.peerDisplayName,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      connectTime: connectTime ?? this.connectTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// 格式化通话时长
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'WebRTCCallInfo('
        'sessionId: $sessionId, '
        'peerId: $peerId, '
        'type: $callType, '
        'direction: $direction, '
        'state: $state, '
        'duration: $formattedDuration'
        ')';
  }
}
