/// WebRTC 质量配置测试
///
/// 测试网络质量评分算法和配置
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/quality/quality_config.dart';
import 'package:imboy/component/webrtc/connection/connection_config.dart';

void main() {
  group('WebRTCQualityConfig', () {
    late WebRTCQualityConfig config;

    setUp(() {
      config = WebRTCQualityConfig.defaultConfig();
    });

    test('should create default config', () {
      expect(config.enabled, isTrue);
      expect(config.monitorInterval, const Duration(seconds: 5));
      expect(config.enableAdaptiveBitrate, isTrue);
    });

    test('should calculate quality score correctly', () {
      // 优秀 (所有指标都很好)
      final excellentScore = config.calculateQualityScore(
        rtt: 50, // ms
        packetLoss: 0, // %
        jitter: 10, // ms
        bitrate: 2000000, // bps (2 Mbps)
        frameRate: 30, // fps
      );

      expect(excellentScore, greaterThanOrEqualTo(80));

      // 良好 (RTT 稍高)
      final goodScore = config.calculateQualityScore(
        rtt: 150,
        packetLoss: 1,
        jitter: 20,
        bitrate: 1500000,
        frameRate: 24,
      );

      expect(goodScore, greaterThanOrEqualTo(60));
      expect(goodScore, lessThan(80));

      // 一般 (RTT 高，丢包率低)
      final fairScore = config.calculateQualityScore(
        rtt: 250,
        packetLoss: 3,
        jitter: 40,
        bitrate: 1000000,
        frameRate: 20,
      );

      expect(fairScore, greaterThanOrEqualTo(40));
      expect(fairScore, lessThan(60));

      // 较差 (RTT 很高，丢包率高)
      final poorScore = config.calculateQualityScore(
        rtt: 400,
        packetLoss: 8,
        jitter: 60,
        bitrate: 500000,
        frameRate: 15,
      );

      expect(poorScore, lessThan(40));
      expect(poorScore, greaterThanOrEqualTo(0));
    });

    test('should clamp score to 0-100 range', () {
      // 极端情况：所有指标都很差
      final worstScore = config.calculateQualityScore(
        rtt: 1000,
        packetLoss: 50,
        jitter: 200,
        bitrate: 0,
        frameRate: 0,
      );

      expect(worstScore, equals(0));

      // 极端情况：所有指标都很好
      final bestScore = config.calculateQualityScore(
        rtt: 0,
        packetLoss: 0,
        jitter: 0,
        bitrate: 10000000,
        frameRate: 60,
      );

      expect(bestScore, equals(100));
    });

    test('should return correct quality level', () {
      expect(
        config.getNetworkQuality(90),
        equals(WebRTCNetworkQuality.excellent),
      );

      expect(
        config.getNetworkQuality(70),
        equals(WebRTCNetworkQuality.good),
      );

      expect(
        config.getNetworkQuality(50),
        equals(WebRTCNetworkQuality.fair),
      );

      expect(
        config.getNetworkQuality(30),
        equals(WebRTCNetworkQuality.poor),
      );
    });

    test('should calculate target bitrate correctly', () {
      final excellentBitrate = config.calculateTargetBitrate(90);
      expect(excellentBitrate, greaterThan(2000000)); // > 2 Mbps

      final goodBitrate = config.calculateTargetBitrate(70);
      expect(goodBitrate, greaterThan(1000000)); // > 1 Mbps

      final poorBitrate = config.calculateTargetBitrate(30);
      expect(poorBitrate, lessThan(500000)); // < 500 Kbps
    });

    test('should create audio-only config', () {
      final audioConfig = WebRTCConnectionConfig.audioOnly();

      expect(audioConfig.offerConstraints['offerToReceiveAudio'], isTrue);
      expect(audioConfig.offerConstraints['offerToReceiveVideo'], isFalse);
    });

    test('should create video call config', () {
      final videoConfig = WebRTCConnectionConfig.videoCall();

      expect(videoConfig.offerConstraints['offerToReceiveAudio'], isTrue);
      expect(videoConfig.offerConstraints['offerToReceiveVideo'], isTrue);
    });
  });

  group('WebRTCNetworkQuality', () {
    test('should have correct signal bars', () {
      expect(WebRTCNetworkQuality.excellent.signalBars, equals(4));
      expect(WebRTCNetworkQuality.good.signalBars, equals(3));
      expect(WebRTCNetworkQuality.fair.signalBars, equals(2));
      expect(WebRTCNetworkQuality.poor.signalBars, equals(1));
    });

    test('should check if quality is acceptable', () {
      expect(WebRTCNetworkQuality.excellent.isAcceptable, isTrue);
      expect(WebRTCNetworkQuality.good.isAcceptable, isTrue);
      expect(WebRTCNetworkQuality.fair.isAcceptable, isTrue);
      expect(WebRTCNetworkQuality.poor.isAcceptable, isFalse);
    });

    test('should check if quality is excellent', () {
      expect(WebRTCNetworkQuality.excellent.isExcellent, isTrue);
      expect(WebRTCNetworkQuality.good.isExcellent, isFalse);
      expect(WebRTCNetworkQuality.fair.isExcellent, isFalse);
      expect(WebRTCNetworkQuality.poor.isExcellent, isFalse);
    });
  });
}
