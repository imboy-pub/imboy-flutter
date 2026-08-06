import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/logout_account/logout_account_page.dart';

/// LogoutAccountState 纯内存单测（直接 new，不依赖单例/API）。
void main() {
  group('LogoutAccountState defaults', () {
    test(
      'default constructor: not loading, null error, empty selectedValue',
      () {
        const state = LogoutAccountState();
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        expect(state.selectedValue, '');
      },
    );
  });

  group('LogoutAccountState copyWith', () {
    const base = LogoutAccountState();

    test('copyWith updates isLoading + selectedValue', () {
      final next = base.copyWith(isLoading: true, selectedValue: 'reason1');
      expect(next.isLoading, isTrue);
      expect(next.selectedValue, 'reason1');
    });

    test('copyWith sets error string', () {
      final next = base.copyWith(error: 'failed');
      expect(next.error, 'failed');
    });

    test(
      'copyWith clears error when not provided (intentional non-?? semantic)',
      () {
        final withError = base.copyWith(error: 'failed');
        final cleared = withError.copyWith(isLoading: true);
        expect(cleared.error, isNull);
        expect(cleared.isLoading, isTrue);
      },
    );
  });
}
