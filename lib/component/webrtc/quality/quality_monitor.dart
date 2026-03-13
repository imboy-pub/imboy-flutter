/// WebRTC 网络质量监控器
///
/// 监控网络连接质量并自适应调整码率
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../connection/connection.dart';
import 'quality_config.dart';

/// WebRTC 网络质量监控器
///
/// 收集 WebRTC 统计信息并计算质量评分
class WebRTCNetworkQualityMonitor {
  /// 连接实例
  final WebRTCConnection connection;

  /// 质量配置
  final WebRTCQualityConfig config;

  /// 监控定时器
  Timer? _monitorTimer;

  /// 当前统计信息
  WebRTCQualityStats _currentStats = WebRTCQualityStats.empty();

  /// 质量评分 (0-100)
  int _qualityScore = 100;

  /// 质量统计流控制器
  final StreamController<WebRTCQualityStats> _statsController =
      StreamController<WebRTCQualityStats>.broadcast();

  /// 质量评分流控制器
  final StreamController<int> _qualityScoreController =
      StreamController<int>.broadcast();

  /// 网络质量等级流控制器
  final StreamController<WebRTCNetworkQuality> _qualityController =
      StreamController<WebRTCNetworkQuality>.broadcast();

  /// 质量统计流
  Stream<WebRTCQualityStats> get statsStream => _statsController.stream;

  /// 质量评分流
  Stream<int> get qualityScoreStream => _qualityScoreController.stream;

  /// 网络质量等级流
  Stream<WebRTCNetworkQuality> get qualityStream => _qualityController.stream;

  /// 当前统计信息
  WebRTCQualityStats get currentStats => _currentStats;

  /// 当前质量评分
  int get qualityScore => _qualityScore;

  /// 当前网络质量等级
  WebRTCNetworkQuality get currentQuality =>
      config.getNetworkQuality(_qualityScore);

  /// 创建质量监控器
  WebRTCNetworkQualityMonitor({
    required this.connection,
    required this.config,
  });

  /// 开始监控
  void startMonitoring() {
    if (_monitorTimer != null) {
      debugPrint('Quality monitoring already started');
      return;
    }

    if (!config.enabled) {
      debugPrint('Quality monitoring disabled');
      return;
    }

    debugPrint('Starting WebRTC quality monitoring (interval: ${config.monitorInterval})');

    // 立即收集一次统计
    _collectStats();

    // 定期收集统计
    _monitorTimer = Timer.periodic(config.monitorInterval, (_) {
      _collectStats();
    });
  }

  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    debugPrint('Stopped WebRTC quality monitoring');
  }

  /// 收集统计信息
  Future<void> _collectStats() async {
    final pc = connection.peerConnection;
    if (pc == null) {
      debugPrint('PeerConnection is null, skipping stats collection');
      return;
    }

    try {
      // 获取 WebRTC 统计报告
      final stats = await pc.getStats() as Map<dynamic, dynamic>;
      _currentStats = _parseStats(stats);

      // 计算质量评分
      final newScore = config.calculateQualityScore(
        rtt: _currentStats.rtt,
        packetLoss: _currentStats.packetLoss,
        jitter: _currentStats.jitter,
        bitrate: _currentStats.bitrate,
        frameRate: _currentStats.frameRate,
      );

      // 检测质量评分变化
      if (newScore != _qualityScore) {
        _qualityScore = newScore;
        _qualityScoreController.add(_qualityScore);

        // 通知质量等级变化
        final quality = config.getNetworkQuality(_qualityScore);
        _qualityController.add(quality);

        debugPrint('Quality score changed to $_qualityScore ($quality)');
      }

      // 发布统计更新
      _statsController.add(_currentStats);

      // 根据质量调整码率
      if (config.enableAdaptiveBitrate) {
        _adjustBitrate();
      }
    } catch (e, s) {
      debugPrint('Failed to collect WebRTC stats: $e\n$s');
    }
  }

  /// 解析统计信息
  WebRTCQualityStats _parseStats(Map<dynamic, dynamic> stats) {
    int rtt = 0;
    int packetLoss = 0;
    int jitter = 0;
    int bitrate = 0;
    int width = 0;
    int height = 0;
    int frameRate = 0;
    String codec = '';
    int audioLevel = 0;

    // 遍历统计报告
    for (final entry in stats.entries) {
      final report = entry.value;
      if (report is! Map) continue;

      final type = report['type'] as String?;

      switch (type) {
        case 'candidate-pair':
          // RTT 和连接状态
          if (report['state'] == 'succeeded') {
            rtt = (report['currentRoundTripTime'] as num?)?.toInt() ?? 0;
          }
          break;

        case 'inbound-rtp':
        case 'outbound-rtp':
          final kind = report['kind'] as String?;

          if (kind == 'video') {
            // 视频统计
            width = (report['frameWidth'] as num?)?.toInt() ?? 0;
            height = (report['frameHeight'] as num?)?.toInt() ?? 0;

            // 帧率
            frameRate = (report['framesPerSecond'] as num?)?.toInt() ?? 0;

            // 码率
            final bytesSent = (report['bytesSent'] as num?)?.toInt() ?? 0;
            final bytesReceived = (report['bytesReceived'] as num?)?.toInt() ?? 0;
            bitrate = ((bytesSent + bytesReceived) * 8).toInt();

            // 编解码器
            codec = report['codecId'] as String? ?? '';
          } else if (kind == 'audio') {
            // 音频统计
            audioLevel =
                ((report['audioLevel'] as num?)?.toDouble() ?? 0.0 * 32767)
                    .toInt();

            // 音频丢包
            final packetsLost = (report['packetsLost'] as num?)?.toInt() ?? 0;
            final packets = (report['packetsReceived'] as num?)?.toInt() ?? 0;
            if (packets > 0) {
              packetLoss = (packetsLost / packets * 100).toInt();
            }

            // 音频抖动
            jitter = (report['jitter'] as num?)?.toInt() ?? 0;
          }
          break;

        default:
          break;
      }
    }

    return WebRTCQualityStats(
      rtt: rtt,
      packetLoss: packetLoss.clamp(0, 100),
      jitter: jitter,
      bitrate: bitrate,
      width: width,
      height: height,
      frameRate: frameRate,
      codec: codec,
      audioLevel: audioLevel,
      timestamp: DateTime.now(),
    );
  }

  /// 调整码率
  void _adjustBitrate() {
    final quality = config.getNetworkQuality(_qualityScore);
    final targetBitrate = config.calculateTargetBitrate(_qualityScore);

    debugPrint('Adjusting bitrate: $quality -> $targetBitrate bps');

    // TODO(WebRTC内部): 通过 RTP 发送者动态设置码率
    // 需要访问 RTCPeerConnection 的 senders 并设置 encoding 参数
    // 注意：此功能需要 flutter_webrtc 包的完整 API 支持
    try {
      final pc = connection.peerConnection;
      if (pc == null) return;

      // 获取所有 RTP 发送者并设置码率
      // pc.getSenders().then((senders) {
      //   for (final sender in senders) {
      //     if (sender.track != null && sender.track!.kind == 'video') {
      //       // 设置码率参数
      //       final parameters = sender.getParameters();
      //       parameters.encodings.forEach((encoding) {
      //         encoding.maxBitrate = targetBitrate;
      //       });
      //       sender.setParameters(parameters);
      //     }
      //   }
      // });
    } catch (e, s) {
      debugPrint('Failed to adjust bitrate: $e\n$s');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    stopMonitoring();
    await _statsController.close();
    await _qualityScoreController.close();
    await _qualityController.close();
    debugPrint('WebRTC quality monitor disposed');
  }
}

/// WebRTC 质量统计
class WebRTCQualityStats {
  /// 往返时延 (ms)
  final int rtt;

  /// 丢包率 (0-100)
  final int packetLoss;

  /// 抖动 (ms)
  final int jitter;

  /// 比特率 (bps)
  final int bitrate;

  /// 视频宽度
  final int width;

  /// 视频高度
  final int height;

  /// 帧率 (fps)
  final int frameRate;

  /// 编解码器
  final String codec;

  /// 音频电平 (0-32767)
  final int audioLevel;

  /// 统计时间戳
  final DateTime timestamp;

  const WebRTCQualityStats({
    required this.rtt,
    required this.packetLoss,
    required this.jitter,
    required this.bitrate,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.codec,
    required this.audioLevel,
    required this.timestamp,
  });

  /// 创建空的统计信息
  factory WebRTCQualityStats.empty() {
    return WebRTCQualityStats(
      rtt: 0,
      packetLoss: 0,
      jitter: 0,
      bitrate: 0,
      width: 0,
      height: 0,
      frameRate: 0,
      codec: '',
      audioLevel: 0,
      timestamp: DateTime.now(),
    );
  }

  /// 是否为有效统计
  bool get isValid => rtt > 0 || bitrate > 0;

  /// 视频分辨率
  String get resolution => '${width}x$height';

  /// 格式化比特率
  String get formattedBitrate {
    if (bitrate < 1000) {
      return '$bitrate bps';
    } else if (bitrate < 1000000) {
      return '${(bitrate / 1000).toStringAsFixed(1)} Kbps';
    } else {
      return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
    }
  }

  @override
  String toString() {
    return 'WebRTCQualityStats('
        'rtt: ${rtt}ms, '
        'packetLoss: $packetLoss%, '
        'jitter: ${jitter}ms, '
        'bitrate: $formattedBitrate, '
        'resolution: $resolution, '
        'frameRate: $frameRate fps, '
        'codec: $codec'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRTCQualityStats &&
        other.rtt == rtt &&
        other.packetLoss == packetLoss &&
        other.jitter == jitter &&
        other.bitrate == bitrate &&
        other.width == width &&
        other.height == height &&
        other.frameRate == frameRate &&
        other.codec == codec &&
        other.audioLevel == audioLevel;
  }

  @override
  int get hashCode {
    return Object.hash(
      rtt,
      packetLoss,
      jitter,
      bitrate,
      width,
      height,
      frameRate,
      codec,
      audioLevel,
    );
  }
}
