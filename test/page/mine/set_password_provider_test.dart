import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/change_password/set_password_provider.dart';

ProviderContainer _makeContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

SetPassword _notifier(ProviderContainer c) =>
    c.read(setPasswordProvider.notifier);

SetPasswordState _state(ProviderContainer c) =>
    c.read(setPasswordProvider);

void main() {
  group('SetPasswordState.copyWith', () {
    test('preserves unmodified fields', () {
      const state = SetPasswordState(
        newPwd: 'hello',
        newPwdObscure: false,
      );
      final next = state.copyWith(retypePwd: 'world');
      expect(next.newPwd, 'hello');
      expect(next.newPwdObscure, isFalse);
      expect(next.retypePwd, 'world');
    });

    test('default state has empty passwords and obscure=true', () {
      const state = SetPasswordState();
      expect(state.newPwd, '');
      expect(state.retypePwd, '');
      expect(state.newPwdObscure, isTrue);
      expect(state.retypePwdObscure, isTrue);
    });

    test('can override all fields at once', () {
      const state = SetPasswordState();
      final next = state.copyWith(
        newPwd: 'a',
        retypePwd: 'b',
        newPwdObscure: false,
        retypePwdObscure: false,
      );
      expect(next.newPwd, 'a');
      expect(next.retypePwd, 'b');
      expect(next.newPwdObscure, isFalse);
      expect(next.retypePwdObscure, isFalse);
    });
  });

  group('SetPassword notifier state management', () {
    test('initial state is empty and obscured', () {
      final c = _makeContainer();
      final s = _state(c);
      expect(s.newPwd, '');
      expect(s.retypePwd, '');
      expect(s.newPwdObscure, isTrue);
      expect(s.retypePwdObscure, isTrue);
    });

    test('updateNewPassword updates newPwd', () {
      final c = _makeContainer();
      _notifier(c).updateNewPassword('test1234');
      expect(_state(c).newPwd, 'test1234');
      expect(_state(c).retypePwd, ''); // unchanged
    });

    test('updateRetypePassword updates retypePwd', () {
      final c = _makeContainer();
      _notifier(c).updateRetypePassword('test1234');
      expect(_state(c).retypePwd, 'test1234');
      expect(_state(c).newPwd, ''); // unchanged
    });

    test('toggleNewPwdObscure flips only newPwdObscure', () {
      final c = _makeContainer();
      _notifier(c).toggleNewPwdObscure();
      expect(_state(c).newPwdObscure, isFalse);
      expect(_state(c).retypePwdObscure, isTrue);
    });

    test('toggleRetypePwdObscure flips only retypePwdObscure', () {
      final c = _makeContainer();
      _notifier(c).toggleRetypePwdObscure();
      expect(_state(c).retypePwdObscure, isFalse);
      expect(_state(c).newPwdObscure, isTrue);
    });

    test('double toggle restores original obscure value', () {
      final c = _makeContainer();
      _notifier(c).toggleNewPwdObscure();
      _notifier(c).toggleNewPwdObscure();
      expect(_state(c).newPwdObscure, isTrue);
    });
  });

  group('SetPassword.passwordValidator', () {
    test('returns non-null error for null input', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator(null);
      expect(result, isNotNull);
    });

    test('returns non-null error for empty string', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('');
      expect(result, isNotNull);
    });

    test('returns non-null error for whitespace-only string', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('   ');
      expect(result, isNotNull);
    });

    test('returns non-null error for 3-char password (too short)', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('abc');
      expect(result, isNotNull);
    });

    test('returns null for 4-char password (minimum valid)', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('abcd');
      expect(result, isNull);
    });

    test('returns null for 32-char password (maximum valid)', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('a' * 32);
      expect(result, isNull);
    });

    test('returns non-null error for 33-char password (too long)', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('a' * 33);
      expect(result, isNotNull);
    });

    test('returns null for typical valid password', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('myPass123');
      expect(result, isNull);
    });

    test('returns non-null error for 1-char password', () {
      final c = _makeContainer();
      final result = _notifier(c).passwordValidator('x');
      expect(result, isNotNull);
    });
  });
}
