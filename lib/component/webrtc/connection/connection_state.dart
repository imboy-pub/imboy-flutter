/// WebRTC 连接状态定义
///
/// 定义所有可能的连接状态，用于状态机管理
library;

/// WebRTC 连接状态
///
/// 完整的连接生命周期状态，从空闲到关闭
enum WebRTCConnectionState {
  /// 空闲状态 - 尚未初始化
  idle,

  /// 正在初始化 - 创建 PeerConnection 和媒体流
  initializing,

  /// 就绪状态 - 已初始化，可以创建 offer/answer
  ready,

  /// 正在创建 offer
  creatingOffer,

  /// 正在创建 answer
  creatingAnswer,

  /// 连接中 - 等待 ICE 连接建立
  connecting,

  /// 已连接 - ICE 连接成功，媒体流可用
  connected,

  /// 已断开 - ICE 连接断开，可能尝试重连
  disconnected,

  /// 重连中 - 正在尝试重新建立连接
  reconnecting,

  /// 连接失败 - 无法建立连接
  failed,

  /// 正在关闭 - 清理资源中
  closing,

  /// 已关闭 - 资源已释放
  closed,
}

/// 扩展连接状态的辅助方法
extension WebRTCConnectionStateExtension on WebRTCConnectionState {
  /// 是否为活跃状态（正在连接或已连接）
  bool get isActive {
    return index >= WebRTCConnectionState.connecting.index &&
        index <= WebRTCConnectionState.connected.index;
  }

  /// 是否为终止状态（无法恢复）
  bool get isTerminal {
    return this == WebRTCConnectionState.failed ||
        this == WebRTCConnectionState.closed;
  }

  /// 是否为可重连状态
  bool get canReconnect {
    return this == WebRTCConnectionState.disconnected ||
        this == WebRTCConnectionState.failed;
  }

  /// 是否需要清理资源
  bool get needsCleanup {
    return this == WebRTCConnectionState.failed ||
        this == WebRTCConnectionState.closed ||
        this == WebRTCConnectionState.closing;
  }

  /// 状态的显示标签（用于 UI）
  String get label {
    switch (this) {
      case WebRTCConnectionState.idle:
        return '空闲';
      case WebRTCConnectionState.initializing:
        return '初始化中';
      case WebRTCConnectionState.ready:
        return '就绪';
      case WebRTCConnectionState.creatingOffer:
        return '创建请求中';
      case WebRTCConnectionState.creatingAnswer:
        return '创建应答中';
      case WebRTCConnectionState.connecting:
        return '连接中';
      case WebRTCConnectionState.connected:
        return '已连接';
      case WebRTCConnectionState.disconnected:
        return '已断开';
      case WebRTCConnectionState.reconnecting:
        return '重连中';
      case WebRTCConnectionState.failed:
        return '连接失败';
      case WebRTCConnectionState.closing:
        return '关闭中';
      case WebRTCConnectionState.closed:
        return '已关闭';
    }
  }

  /// 状态对应的图标（用于 UI）
  /// 注意：这里返回字符串，实际使用时需要配合 IconData
  String get iconName {
    switch (this) {
      case WebRTCConnectionState.idle:
      case WebRTCConnectionState.ready:
        return 'video_call';
      case WebRTCConnectionState.initializing:
      case WebRTCConnectionState.creatingOffer:
      case WebRTCConnectionState.creatingAnswer:
      case WebRTCConnectionState.connecting:
        return 'sync';
      case WebRTCConnectionState.connected:
        return 'check_circle';
      case WebRTCConnectionState.disconnected:
        return 'link_off';
      case WebRTCConnectionState.reconnecting:
        return 'sync_problem';
      case WebRTCConnectionState.failed:
        return 'error';
      case WebRTCConnectionState.closing:
      case WebRTCConnectionState.closed:
        return 'cancel';
    }
  }
}

/// 连接状态变更事件
class WebRTCConnectionStateEvent {
  /// 新状态
  final WebRTCConnectionState state;

  /// 旧状态
  final WebRTCConnectionState? previousState;

  /// 时间戳
  final DateTime timestamp;

  /// 关联的错误信息（如果有）
  final String? error;

  /// 额外数据
  final Map<String, dynamic>? metadata;

  WebRTCConnectionStateEvent({
    required this.state,
    this.previousState,
    DateTime? timestamp,
    this.error,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ConnectionStateEvent{state: $state, previous: $previousState, error: $error}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRTCConnectionStateEvent &&
        other.state == state &&
        other.previousState == previousState &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(state, previousState, error);
}
