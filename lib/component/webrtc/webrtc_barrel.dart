/// WebRTC 模块
///
/// 完整的 WebRTC 音视频通话解决方案
library;

// 连接管理
export 'connection/connection_barrel.dart';

// 重连机制
export 'reconnect/reconnect_barrel.dart';

// 质量监控 (包含 WebRTCNetworkQuality 枚举定义)
export 'quality/quality_barrel.dart';

// 状态机
export 'state/state_barrel.dart';

// 信令协议
export 'signaling/signaling_v2.dart';

// 信令消息模型 (排除重复定义，使用 quality_config.dart 中的定义)
export 'signaling/signaling_models.dart'
    hide WebRTCNetworkQuality,
         WebRTCNetworkQualityExtension;
