import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/user_device/user_device_provider.dart';

void main() {
  group('UserDeviceState defaults', () {
    test('default values', () {
      const s = UserDeviceState();
      expect(s.deviceList, isEmpty);
      expect(s.currentDeviceId, '');
      expect(s.isLoading, isFalse);
      expect(s.activeSessions, isEmpty);
      expect(s.isLoadingSessions, isFalse);
    });
  });

  group('UserDeviceState.copyWith', () {
    test('overrides only provided fields', () {
      const base = UserDeviceState(currentDeviceId: 'dev-1');
      final next = base.copyWith(isLoading: true);
      expect(next.isLoading, isTrue);
      expect(next.currentDeviceId, 'dev-1');
      expect(next.deviceList, isEmpty);
    });

    test('null arguments preserve existing values', () {
      const base = UserDeviceState(
        currentDeviceId: 'dev-2',
        isLoadingSessions: true,
      );
      final next = base.copyWith();
      expect(next.currentDeviceId, 'dev-2');
      expect(next.isLoadingSessions, isTrue);
    });

    test('returns new instance, original unchanged', () {
      const base = UserDeviceState(currentDeviceId: 'a');
      final next = base.copyWith(currentDeviceId: 'b');
      expect(identical(base, next), isFalse);
      expect(base.currentDeviceId, 'a');
      expect(next.currentDeviceId, 'b');
    });

    test('activeSessions list can be replaced', () {
      const base = UserDeviceState();
      final next = base.copyWith(
        activeSessions: [
          {'id': 1},
        ],
      );
      expect(next.activeSessions.length, 1);
      expect(base.activeSessions, isEmpty);
    });
  });
}
