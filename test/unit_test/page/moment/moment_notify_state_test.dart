import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_state.dart';
import 'package:imboy/store/model/moment_notify_model.dart';

MomentNotifyModel _model(int id, {bool isRead = false}) => MomentNotifyModel(
  id: id,
  userId: '100',
  action: 'moment_like',
  momentId: 'm$id',
  fromUid: '200',
  isRead: isRead,
  createdAt: 1000 + id,
);

void main() {
  group('MomentNotifyState defaults', () {
    test('default constructor yields empty/loading-false state', () {
      const s = MomentNotifyState();
      expect(s.items, isEmpty);
      expect(s.isLoading, isFalse);
      expect(s.hasMore, isTrue);
      expect(s.unreadCount, 0);
      expect(s.page, 0);
      expect(s.errorMessage, isNull);
    });
  });

  group('MomentNotifyState copyWith', () {
    test('overrides only the passed fields', () {
      const base = MomentNotifyState();
      final next = base.copyWith(
        items: [_model(1)],
        isLoading: true,
        unreadCount: 5,
        page: 2,
      );
      expect(next.items.length, 1);
      expect(next.isLoading, isTrue);
      expect(next.unreadCount, 5);
      expect(next.page, 2);
      // unchanged
      expect(next.hasMore, isTrue);
      // 入参未变（不可变）
      expect(base.items, isEmpty);
      expect(base.unreadCount, 0);
    });

    test('errorMessage retains old value when null is passed', () {
      const base = MomentNotifyState(errorMessage: 'boom');
      final next = base.copyWith(isLoading: true);
      expect(next.errorMessage, 'boom');
    });

    test('clearError=true wipes errorMessage even if errorMessage passed', () {
      const base = MomentNotifyState(errorMessage: 'boom');
      final next = base.copyWith(errorMessage: 'ignored', clearError: true);
      expect(next.errorMessage, isNull);
    });

    test('errorMessage can be set to a new value', () {
      const base = MomentNotifyState();
      final next = base.copyWith(errorMessage: 'refresh_failed');
      expect(next.errorMessage, 'refresh_failed');
    });
  });
}
