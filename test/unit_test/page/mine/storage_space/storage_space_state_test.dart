import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/storage_space/storage_space_provider.dart';

void main() {
  group('StorageSpaceState defaults', () {
    test('all numeric fields default to 0 and not loading', () {
      const s = StorageSpaceState();
      expect(s.totalDiskSpace, 0);
      expect(s.freeDiskSpace, 0);
      expect(s.usedDiskSpace, 0);
      expect(s.appBytes, 0);
      expect(s.cacheBytes, 0);
      expect(s.dataBytes, 0);
      expect(s.chatHistoryBytes, 0);
      expect(s.appAllBytes, 0);
      expect(s.isLoading, isFalse);
    });
  });

  group('StorageSpaceState.copyWith', () {
    test('overrides only provided fields', () {
      const base = StorageSpaceState(totalDiskSpace: 100, freeDiskSpace: 40);
      final next = base.copyWith(isLoading: true, appBytes: 7);
      expect(next.isLoading, isTrue);
      expect(next.appBytes, 7);
      // preserved
      expect(next.totalDiskSpace, 100);
      expect(next.freeDiskSpace, 40);
    });

    test('null arguments preserve existing values', () {
      const base = StorageSpaceState(
        usedDiskSpace: 60,
        cacheBytes: 12,
        appAllBytes: 99,
      );
      final next = base.copyWith();
      expect(next.usedDiskSpace, 60);
      expect(next.cacheBytes, 12);
      expect(next.appAllBytes, 99);
    });

    test('returns a new instance, original unchanged', () {
      const base = StorageSpaceState(dataBytes: 5);
      final next = base.copyWith(dataBytes: 50);
      expect(identical(base, next), isFalse);
      expect(base.dataBytes, 5);
      expect(next.dataBytes, 50);
    });
  });
}
