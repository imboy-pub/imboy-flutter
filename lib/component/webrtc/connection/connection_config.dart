/// WebRTC 连接配置
///
/// 定义连接所需的各种配置参数
library;

import '../reconnect/reconnect_config.dart';
import '../quality/quality_config.dart';

/// 媒体类型
enum WebRTCMediaType {
  /// 仅音频
  audio,

  /// 音视频
  video,

  /// 数据通道
  data,

  /// 屏幕共享
  screenShare,
}

/// 扩展媒体类型的辅助方法
extension WebRTCMediaTypeExtension on WebRTCMediaType {
  /// 是否需要视频
  bool get requiresVideo {
    return this == WebRTCMediaType.video || this == WebRTCMediaType.screenShare;
  }

  /// 是否需要音频
  bool get requiresAudio {
    return this == WebRTCMediaType.audio || this == WebRTCMediaType.video;
  }

  /// 是否为屏幕共享
  bool get isScreenShare {
    return this == WebRTCMediaType.screenShare;
  }

  /// 获取媒体类型名称
  String get name {
    switch (this) {
      case WebRTCMediaType.audio:
        return 'audio';
      case WebRTCMediaType.video:
        return 'video';
      case WebRTCMediaType.data:
        return 'data';
      case WebRTCMediaType.screenShare:
        return 'screenShare';
    }
  }

  /// 从字符串创建媒体类型
  static WebRTCMediaType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'audio':
        return WebRTCMediaType.audio;
      case 'video':
        return WebRTCMediaType.video;
      case 'data':
        return WebRTCMediaType.data;
      case 'screenshare':
      case 'screen_share':
        return WebRTCMediaType.screenShare;
      default:
        return WebRTCMediaType.video;
    }
  }
}

/// WebRTC 连接配置
class WebRTCConnectionConfig {
  /// SDP Offer 约束
  final Map<String, dynamic> offerConstraints;

  /// SDP Answer 约束
  final Map<String, dynamic> answerConstraints;

  /// 重连配置
  final WebRTCReconnectConfig reconnectConfig;

  /// 质量监控配置
  final WebRTCQualityConfig qualityConfig;

  /// 连接超时时间
  final Duration connectionTimeout;

  /// ICE 连接超时时间
  final Duration iceTimeout;

  /// ICE 服务器配置（如果为 null，使用默认配置）
  final Map<String, dynamic>? iceServers;

  /// 是否启用数据通道
  final bool enableDataChannel;

  /// 数据通道标签
  final String dataChannelLabel;

  /// 数据通道最大重传次数
  final int dataChannelMaxRetransmits;

  const WebRTCConnectionConfig({
    this.offerConstraints = const {
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    },
    this.answerConstraints = const {},
    this.reconnectConfig = const WebRTCReconnectConfig(),
    this.qualityConfig = const WebRTCQualityConfig(),
    this.connectionTimeout = const Duration(seconds: 30),
    this.iceTimeout = const Duration(seconds: 15),
    this.iceServers,
    this.enableDataChannel = false,
    this.dataChannelLabel = 'fileTransfer',
    this.dataChannelMaxRetransmits = 30,
  });

  /// 创建默认配置
  factory WebRTCConnectionConfig.defaultConfig() {
    return WebRTCConnectionConfig(
      offerConstraints: {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      },
      answerConstraints: {
        'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      },
      reconnectConfig: WebRTCReconnectConfig.defaultConfig(),
      qualityConfig: WebRTCQualityConfig.defaultConfig(),
      connectionTimeout: const Duration(seconds: 30),
      iceTimeout: const Duration(seconds: 15),
    );
  }

  /// 创建音频通话配置
  factory WebRTCConnectionConfig.audioOnly() {
    return WebRTCConnectionConfig(
      offerConstraints: {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      },
      answerConstraints: {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
        },
      },
    );
  }

  /// 创建视频通话配置
  factory WebRTCConnectionConfig.videoCall() {
    return WebRTCConnectionConfig.defaultConfig();
  }

  /// 创建屏幕共享配置
  factory WebRTCConnectionConfig.screenShare() {
    return WebRTCConnectionConfig(
      offerConstraints: {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      },
      answerConstraints: {
        'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      },
      connectionTimeout: const Duration(seconds: 45),
      iceTimeout: const Duration(seconds: 20),
    );
  }

  /// 根据媒体类型获取媒体约束
  Map<String, dynamic> getMediaConstraints(WebRTCMediaType mediaType) {
    switch (mediaType) {
      case WebRTCMediaType.audio:
        return {'audio': true, 'video': false};

      case WebRTCMediaType.video:
        return {
          'audio': true,
          'video': {
            'mandatory': {
              'minWidth': 1280,
              'minHeight': 720,
              'minFrameRate': '30',
            },
            'facingMode': 'user',
            'optional': <Map<String, dynamic>>[],
          },
        };

      case WebRTCMediaType.data:
        return {'audio': false, 'video': false};

      case WebRTCMediaType.screenShare:
        return {
          'audio': true,
          'video': {
            'mandatory': {
              'minWidth': 1280,
              'minHeight': 720,
              'minFrameRate': '30',
              'chromeMediaSource': 'screen',
            },
          },
        };
    }
  }

  /// 复制并修改部分配置
  WebRTCConnectionConfig copyWith({
    Map<String, dynamic>? offerConstraints,
    Map<String, dynamic>? answerConstraints,
    WebRTCReconnectConfig? reconnectConfig,
    WebRTCQualityConfig? qualityConfig,
    Duration? connectionTimeout,
    Duration? iceTimeout,
    Map<String, dynamic>? iceServers,
    bool? enableDataChannel,
    String? dataChannelLabel,
    int? dataChannelMaxRetransmits,
  }) {
    return WebRTCConnectionConfig(
      offerConstraints: offerConstraints ?? this.offerConstraints,
      answerConstraints: answerConstraints ?? this.answerConstraints,
      reconnectConfig: reconnectConfig ?? this.reconnectConfig,
      qualityConfig: qualityConfig ?? this.qualityConfig,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      iceTimeout: iceTimeout ?? this.iceTimeout,
      iceServers: iceServers ?? this.iceServers,
      enableDataChannel: enableDataChannel ?? this.enableDataChannel,
      dataChannelLabel: dataChannelLabel ?? this.dataChannelLabel,
      dataChannelMaxRetransmits:
          dataChannelMaxRetransmits ?? this.dataChannelMaxRetransmits,
    );
  }

  @override
  String toString() {
    return 'WebRTCConnectionConfig('
        'connectionTimeout: $connectionTimeout, '
        'iceTimeout: $iceTimeout, '
        'enableDataChannel: $enableDataChannel'
        ')';
  }
}
