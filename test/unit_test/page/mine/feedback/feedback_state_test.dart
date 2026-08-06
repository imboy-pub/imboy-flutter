import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/feedback/feedback_provider.dart';

/// FeedbackPageState 纯内存单测（直接 new，不依赖网络/API）。
void main() {
  group('FeedbackPageState defaults', () {
    test('default constructor yields empty lists, not loading, null error', () {
      const state = FeedbackPageState();
      expect(state.itemList, isEmpty);
      expect(state.pageReplyList, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });
  });

  group('FeedbackPageState copyWith', () {
    const base = FeedbackPageState();

    test('copyWith updates isLoading; lists stay unchanged', () {
      final next = base.copyWith(isLoading: true);
      expect(next.isLoading, isTrue);
      expect(next.itemList, isEmpty);
      expect(next.pageReplyList, isEmpty);
    });

    test('copyWith sets error string', () {
      final next = base.copyWith(error: 'boom');
      expect(next.error, 'boom');
      expect(next.isLoading, isFalse);
    });

    test(
      'copyWith clears error when not provided (intentional non-?? semantic)',
      () {
        final withError = base.copyWith(error: 'boom');
        // error 字段不带 ?? this.error，再次 copyWith 不传 error 会清空
        final cleared = withError.copyWith(isLoading: true);
        expect(cleared.error, isNull);
        expect(cleared.isLoading, isTrue);
      },
    );
  });
}
