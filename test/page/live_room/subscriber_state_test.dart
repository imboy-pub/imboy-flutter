import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/live_room/subscriber/subscriber_provider.dart';

/// SubscriberState.copyWith 纯逻辑单测
///
/// State 类为纯内存对象，copyWith 不触发 SharedPreferences / WebRTC
/// （仅 Notifier.build()->_loadSettings 才访问），可直接 new 测试。
void main() {
  group('SubscriberState defaults', () {
    test('默认值正确', () {
      const s = SubscriberState();
      expect(s.stateStr, 'idle');
      expect(s.serverUrl, '');
      expect(s.isConnecting, false);
      expect(s.preferences, isNull);
    });
  });

  group('SubscriberState.copyWith', () {
    test('更新 serverUrl 保留其它字段', () {
      const s = SubscriberState(stateStr: 'playing');
      final next = s.copyWith(serverUrl: 'https://pull');
      expect(next.serverUrl, 'https://pull');
      expect(next.stateStr, 'playing');
    });

    test('更新 stateStr 与 isConnecting', () {
      const s = SubscriberState();
      final next = s.copyWith(stateStr: 'connecting', isConnecting: true);
      expect(next.stateStr, 'connecting');
      expect(next.isConnecting, true);
      expect(next.serverUrl, '');
    });

    test('未传参返回等价新副本（不可变）', () {
      const s = SubscriberState(serverUrl: 'u', isConnecting: true);
      final copy = s.copyWith();
      expect(copy.serverUrl, 'u');
      expect(copy.isConnecting, true);
      expect(identical(copy, s), false);
    });
  });
}
