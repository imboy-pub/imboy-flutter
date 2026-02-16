/// WebRTC 连接状态测试
///
/// 测试连接状态定义和事件
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/connection/connection_state.dart';

void main() {
  group('WebRTCConnectionState', () {
    test('should have all required states', () {
      // 验证所有 12 种连接状态
      expect(WebRTCConnectionState.values.length, equals(12));

      // 关键状态存在性检查
      expect(WebRTCConnectionState.idle, isNotNull);
      expect(WebRTCConnectionState.initializing, isNotNull);
      expect(WebRTCConnectionState.ready, isNotNull);
      expect(WebRTCConnectionState.connecting, isNotNull);
      expect(WebRTCConnectionState.connected, isNotNull);
      expect(WebRTCConnectionState.disconnected, isNotNull);
      expect(WebRTCConnectionState.reconnecting, isNotNull);
      expect(WebRTCConnectionState.failed, isNotNull);
      expect(WebRTCConnectionState.closing, isNotNull);
      expect(WebRTCConnectionState.closed, isNotNull);
    });

    test('should check if state is active', () {
      expect(WebRTCConnectionState.connecting.isActive, isTrue);
      expect(WebRTCConnectionState.connected.isActive, isTrue);

      expect(WebRTCConnectionState.idle.isActive, isFalse);
      expect(WebRTCConnectionState.initializing.isActive, isFalse);
      expect(WebRTCConnectionState.ready.isActive, isFalse);
      expect(WebRTCConnectionState.closed.isActive, isFalse);
      expect(WebRTCConnectionState.failed.isActive, isFalse);
    });

    test('should check if state can reconnect', () {
      expect(WebRTCConnectionState.disconnected.canReconnect, isTrue);
      expect(WebRTCConnectionState.failed.canReconnect, isTrue);

      expect(WebRTCConnectionState.idle.canReconnect, isFalse);
      expect(WebRTCConnectionState.connected.canReconnect, isFalse);
      expect(WebRTCConnectionState.closed.canReconnect, isFalse);
    });

    test('should check if state is terminal', () {
      expect(WebRTCConnectionState.closed.isTerminal, isTrue);
      expect(WebRTCConnectionState.failed.isTerminal, isTrue);

      expect(WebRTCConnectionState.connected.isTerminal, isFalse);
      expect(WebRTCConnectionState.connecting.isTerminal, isFalse);
    });
  });

  group('WebRTCConnectionStateEvent', () {
    test('should create state event with all fields', () {
      final event = WebRTCConnectionStateEvent(
        state: WebRTCConnectionState.connected,
        previousState: WebRTCConnectionState.connecting,
        timestamp: DateTime(2026, 2, 10, 12, 0, 0),
        error: null,
        metadata: {'test': 'data'},
      );

      expect(event.state, equals(WebRTCConnectionState.connected));
      expect(event.previousState, equals(WebRTCConnectionState.connecting));
      expect(event.error, isNull);
      expect(event.metadata, equals({'test': 'data'}));
    });

    test('should create state event with error', () {
      final event = WebRTCConnectionStateEvent(
        state: WebRTCConnectionState.failed,
        previousState: WebRTCConnectionState.connecting,
        timestamp: DateTime.now(),
        error: 'Connection timeout',
        metadata: null,
      );

      expect(event.state, equals(WebRTCConnectionState.failed));
      expect(event.error, equals('Connection timeout'));
    });

    test('should create state event with metadata', () {
      final event = WebRTCConnectionStateEvent(
        state: WebRTCConnectionState.connected,
        previousState: WebRTCConnectionState.connecting,
        timestamp: DateTime(2026, 2, 10, 12, 0, 0),
        metadata: {'retryCount': 2, 'reason': 'ice-restart'},
      );

      expect(event.metadata, equals({'retryCount': 2, 'reason': 'ice-restart'}));
      expect(event.state, equals(WebRTCConnectionState.connected));
    });

    test('should support equality comparison', () {
      final event1 = WebRTCConnectionStateEvent(
        state: WebRTCConnectionState.connected,
        previousState: WebRTCConnectionState.connecting,
      );

      final event2 = WebRTCConnectionStateEvent(
        state: WebRTCConnectionState.connected,
        previousState: WebRTCConnectionState.connecting,
      );

      final event3 = WebRTCConnectionStateEvent(
        state: WebRTCConnectionState.failed,
        previousState: WebRTCConnectionState.connecting,
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });
  });
}
