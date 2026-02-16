/// WebRTC 信令模型测试
///
/// 测试信令消息模型解析和构建
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/signaling/signaling_models.dart';
import 'package:imboy/component/webrtc/signaling/signaling_v2.dart';

void main() {
  group('WebRTCSignalingModel', () {
    test('should parse offer signaling from JSON', () {
      final json = {
        'id': 'msg-123',
        'type': 'webrtc_offer',
        'from': 'user1',
        'to': 'user2',
        'ts': 1707550800000,
        'session_id': 'session-abc',
        'payload': {
          'media': 'video',
          'sd': {
            'sdp': 'test-sdp',
            'type': 'offer',
          },
        },
      };

      final signaling = WebRTCSignalingModel.fromJson(json);

      expect(signaling.msgId, equals('msg-123'));
      expect(signaling.type, equals(WebRTCSignalingType.offer));
      expect(signaling.from, equals('user1'));
      expect(signaling.to, equals('user2'));
      expect(signaling.sessionId, equals('session-abc'));
      expect(signaling.payload['media'], equals('video'));
    });

    test('should serialize to JSON', () {
      final model = WebRTCSignalingModel(
        msgId: 'msg-456',
        sessionId: 'session-xyz',
        type: WebRTCSignalingType.offer,
        from: 'user1',
        to: 'user2',
        payload: {'test': 'data'},
        timestamp: 1707550800000,
      );

      final json = model.toJson();

      expect(json['id'], equals('msg-456'));
      expect(json['type'], equals('webrtc_offer'));
      expect(json['session_id'], equals('session-xyz'));
      expect(json['from'], equals('user1'));
      expect(json['to'], equals('user2'));
    });

    test('should get message priority', () {
      final offerModel = WebRTCSignalingModel(
        msgId: 'msg-789',
        type: WebRTCSignalingType.offer,
        from: 'user1',
        to: 'user2',
        payload: {},
        timestamp: 0,
      );

      final byeModel = WebRTCSignalingModel(
        msgId: 'msg-999',
        type: WebRTCSignalingType.bye,
        from: 'user1',
        to: 'user2',
        payload: {},
        timestamp: 0,
      );

      expect(
        offerModel.messagePriority,
        equals(WebRTCMessagePriority.high),
      );

      expect(
        byeModel.messagePriority,
        equals(WebRTCMessagePriority.urgent),
      );
    });

    test('should check if requires ACK', () {
      final offerModel = WebRTCSignalingModel(
        msgId: 'msg-1',
        type: WebRTCSignalingType.offer,
        from: 'user1',
        to: 'user2',
        payload: {},
        timestamp: 0,
      );

      final heartbeatModel = WebRTCSignalingModel(
        msgId: 'msg-2',
        type: WebRTCSignalingType.heartbeat,
        from: 'user1',
        to: 'user2',
        payload: {},
        timestamp: 0,
      );

      expect(offerModel.requiresAck, isTrue);
      expect(heartbeatModel.requiresAck, isFalse);
    });

    test('should check if is control message', () {
      final heartbeatModel = WebRTCSignalingModel(
        msgId: 'msg-1',
        type: WebRTCSignalingType.heartbeat,
        from: 'user1',
        to: 'user2',
        payload: {},
        timestamp: 0,
      );

      final offerModel = WebRTCSignalingModel(
        msgId: 'msg-2',
        type: WebRTCSignalingType.offer,
        from: 'user1',
        to: 'user2',
        payload: {},
        timestamp: 0,
      );

      expect(heartbeatModel.isControlMessage, isTrue);
      expect(offerModel.isControlMessage, isFalse);
    });
  });

  group('WebRTCQualityStatsData', () {
    test('should parse quality stats from JSON', () {
      final json = {
        'rtt': 150,
        'packetLoss': 2,
        'jitter': 30,
        'bitrate': 1500000,
        'width': 1280,
        'height': 720,
        'frameRate': 30,
        'codec': 'H264',
        'audioLevel': 1000,
        'timestamp': 1707550800000,
      };

      final stats = WebRTCQualityStatsData.fromJson(json);

      expect(stats.rtt, equals(150));
      expect(stats.packetLoss, equals(2));
      expect(stats.jitter, equals(30));
      expect(stats.bitrate, equals(1500000));
      expect(stats.width, equals(1280));
      expect(stats.height, equals(720));
      expect(stats.frameRate, equals(30));
      expect(stats.codec, equals('H264'));
    });

    test('should calculate quality score', () {
      // 优秀
      final excellentStats = WebRTCQualityStatsData(
        rtt: 50,
        packetLoss: 0,
        jitter: 10,
        bitrate: 2000000,
        width: 1280,
        height: 720,
        frameRate: 30,
        codec: 'H264',
        audioLevel: 1000,
        timestamp: 0,
      );

      final excellentScore = excellentStats.calculateScore();
      expect(excellentScore, greaterThanOrEqualTo(80));

      // 较差
      final poorStats = WebRTCQualityStatsData(
        rtt: 400,
        packetLoss: 10,
        jitter: 60,
        bitrate: 500000,
        width: 640,
        height: 480,
        frameRate: 15,
        codec: 'VP8',
        audioLevel: 500,
        timestamp: 0,
      );

      final poorScore = poorStats.calculateScore();
      expect(poorScore, lessThan(40));
    });

    test('should create empty stats', () {
      final emptyStats = WebRTCQualityStatsData.empty();

      expect(emptyStats.rtt, equals(0));
      expect(emptyStats.packetLoss, equals(0));
      expect(emptyStats.jitter, equals(0));
      expect(emptyStats.bitrate, equals(0));
      expect(emptyStats.frameRate, equals(0));
    });
  });

  group('WebRTCErrorCode', () {
    test('should get error descriptions', () {
      expect(
        WebRTCErrorCode.getDescription(WebRTCErrorCode.connectionFailed),
        equals('连接失败'),
      );

      expect(
        WebRTCErrorCode.getDescription(WebRTCErrorCode.permissionDenied),
        equals('权限被拒绝'),
      );

      expect(
        WebRTCErrorCode.getDescription(WebRTCErrorCode.callRejected),
        equals('通话被拒绝'),
      );
    });

    test('should check if error is retryable', () {
      expect(
        WebRTCErrorCode.isRetryable(WebRTCErrorCode.networkError),
        isTrue,
      );

      expect(
        WebRTCErrorCode.isRetryable(WebRTCErrorCode.permissionDenied),
        isFalse,
      );
    });

    test('should check if error is fatal', () {
      expect(
        WebRTCErrorCode.isFatal(WebRTCErrorCode.permissionDenied),
        isTrue,
      );

      expect(
        WebRTCErrorCode.isFatal(WebRTCErrorCode.networkError),
        isFalse,
      );
    });
  });

  group('WebRTCSignalingBuilder', () {
    test('should build offer message', () {
      final message = WebRTCSignalingBuilder.buildOffer(
        msgId: 'msg-offer',
        from: 'user1',
        to: 'user2',
        sdp: {'sdp': 'test', 'type': 'offer'},
        mediaType: 'video',
        sessionId: 'session-123',
      );

      expect(message['id'], equals('msg-offer'));
      expect(message['type'], equals('webrtc_offer'));
      expect(message['session_id'], equals('session-123'));
      expect(message['payload']['media'], equals('video'));
    });

    test('should build heartbeat message', () {
      final message = WebRTCSignalingBuilder.buildHeartbeat(
        msgId: 'msg-hb',
        from: 'user1',
        to: 'user2',
        sessionId: 'session-123',
      );

      expect(message['type'], equals('webrtc_heartbeat'));
      expect(message['payload']['timestamp'], isNotNull);
    });

    test('should build bye message', () {
      final message = WebRTCSignalingBuilder.buildBye(
        msgId: 'msg-bye',
        from: 'user1',
        to: 'user2',
        sessionId: 'session-123',
        reason: '通话结束',
      );

      expect(message['type'], equals('webrtc_bye'));
      expect(message['payload']['sid'], equals('session-123'));
      expect(message['payload']['reason'], equals('通话结束'));
    });
  });

  group('WebRTCMessagePriority', () {
    test('should have correct weight values', () {
      expect(WebRTCMessagePriority.low.weight, equals(1));
      expect(WebRTCMessagePriority.normal.weight, equals(2));
      expect(WebRTCMessagePriority.high.weight, equals(3));
      expect(WebRTCMessagePriority.urgent.weight, equals(4));
    });
  });

  group('WebRTCSessionState', () {
    test('should have all states', () {
      expect(WebRTCSessionState.values.length, equals(8));

      expect(WebRTCSessionState.initializing, isNotNull);
      expect(WebRTCSessionState.ringing, isNotNull);
      expect(WebRTCSessionState.connecting, isNotNull);
      expect(WebRTCSessionState.connected, isNotNull);
      expect(WebRTCSessionState.reconnecting, isNotNull);
      expect(WebRTCSessionState.paused, isNotNull);
      expect(WebRTCSessionState.ended, isNotNull);
      expect(WebRTCSessionState.failed, isNotNull);
    });
  });
}
