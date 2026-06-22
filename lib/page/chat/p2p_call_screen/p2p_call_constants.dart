/// P2P 音视频通话常量配置
///
/// 集中管理所有 WebRTC 相关的常量值，避免魔法数字
library;

/// 通话超时配置
class CallTimeoutConfig {
  /// 应答超时时间（秒）
  /// 超时后自动挂断，对方无响应
  static const int answerTimeout = 60;

  /// 挂断延迟时间（毫秒）
  /// 对方挂断后延迟关闭页面
  static const int hangupDelay = 2000;

  /// 重连间隔时间（秒）
  /// ICE 连接失败后重连间隔
  static const int reconnectInterval = 3;
}

/// 视频质量配置
class VideoQualityConfig {
  /// 最小视频宽度（像素）
  static const int minVideoWidth = 1280;

  /// 最小视频高度（像素）
  static const int minVideoHeight = 720;

  /// 最小帧率（fps）
  /// ⚠️ 不得超过 30：iOS AVCaptureDevice 前置相机仅支持 1-30fps，
  /// 设为 60 会触发 setActiveVideoMaxFrameDuration 崩溃（NSInvalidArgumentException）。
  static const int minFrameRate = 30;
}

/// DataChannel 配置
class DataChannelConfig {
  /// 最大重传次数
  /// 确保数据可靠传输
  static const int maxRetransmits = 30;

  /// 默认数据通道标签
  static const String defaultLabel = 'fileTransfer';
}

/// TURN 服务器配置
class TurnServerConfig {
  /// 默认 TTL（秒）
  /// 服务器凭证有效期
  static const int defaultTtl = 86400; // 24 小时
}

/// UI 布局配置
class CallUILayoutConfig {
  /// 本地视频初始 Y 坐标
  static const double localVideoInitialY = 30.0;

  /// 本地视频初始 X 偏移（从右侧计算）
  static const double localVideoOffsetX = 90.0;

  /// 对方信息顶部偏移（屏幕高度百分比）
  static const double peerInfoTopRatio = 0.3;

  /// 状态提示顶部偏移（屏幕高度百分比）
  static const double stateTipsTopRatio = 0.2;

  /// 工具栏底部间距
  static const double toolbarBottomSpacing = 20.0;

  /// 拖拽区域顶部间距
  static const double dragAreaTopSpacing = 30.0;

  /// 拖拽区域左侧间距
  static const double dragAreaLeftSpacing = 10.0;
}

/// 本地视频尺寸配置
class LocalVideoConfig {
  /// 本地视频宽度（像素）
  static const double width = 114.0;

  /// 本地视频高度（像素）
  static const double height = 72.0;

  /// 最小尺寸约束
  static const double minWidth = 80.0;

  /// 最小高度约束
  static const double minHeight = 80.0;
}

/// 通话状态码
class CallStateCode {
  /// 呼叫中（未接通）
  static const int calling = 0;

  /// 已接通
  static const int connected = 1;

  /// 未接通/拒绝
  static const int rejected = 2;

  /// 对方挂断
  static const int peerHungUp = 3;

  /// 己方挂断
  static const int localHungUp = 4;

  /// 忙碌
  static const int busy = 5;
}
