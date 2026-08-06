import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/live_room/publisher/publisher_provider.dart';

/// PublisherState.copyWith 纯逻辑单测
///
/// State 类为纯内存对象，copyWith 不触发 SharedPreferences / WebRTC
/// （仅 Notifier.build()->_loadSettings 才访问），可直接 new 测试。
void main() {
  group('PublisherState defaults', () {
    test('默认值正确', () {
      const s = PublisherState();
      expect(s.stateStr, 'idle');
      expect(s.serverUrl, '');
      expect(s.isConnecting, false);
      expect(s.roomId, '');
      expect(s.preferences, isNull);
    });
  });

  group('PublisherState.copyWith', () {
    test('更新 serverUrl 保留其它字段', () {
      const s = PublisherState(roomId: 'r1', stateStr: 'connected');
      final next = s.copyWith(serverUrl: 'https://push');
      expect(next.serverUrl, 'https://push');
      expect(next.roomId, 'r1');
      expect(next.stateStr, 'connected');
    });

    test('更新 roomId 与 isConnecting', () {
      const s = PublisherState();
      final next = s.copyWith(roomId: 'room-99', isConnecting: true);
      expect(next.roomId, 'room-99');
      expect(next.isConnecting, true);
      expect(next.stateStr, 'idle');
    });

    test('未传参返回等价新副本（不可变）', () {
      const s = PublisherState(serverUrl: 'u', roomId: 'r', isConnecting: true);
      final copy = s.copyWith();
      expect(copy.serverUrl, 'u');
      expect(copy.roomId, 'r');
      expect(copy.isConnecting, true);
      expect(identical(copy, s), false);
    });
  });
}
