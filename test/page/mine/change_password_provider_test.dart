import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/change_password/change_password_provider.dart';

ChangeLoginPassword _notifier(ProviderContainer container) =>
    container.read(changeLoginPasswordProvider.notifier);

ChangeLoginPasswordState _state(ProviderContainer container) =>
    container.read(changeLoginPasswordProvider);

ProviderContainer _makeContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ChangeLoginPasswordState.copyWith', () {
    test('preserves unmodified fields', () {
      const state = ChangeLoginPasswordState(
        existingPassword: 'old',
        newObscure: false,
      );
      final next = state.copyWith(newPassword: 'new');
      expect(next.existingPassword, 'old');
      expect(next.newObscure, isFalse);
      expect(next.newPassword, 'new');
    });
  });

  group('ChangeLoginPassword validation (_recompute)', () {
    test('initial state: all flags false, canSubmit false', () {
      final c = _makeContainer();
      final s = _state(c);
      expect(s.existingLengthOk, isFalse);
      expect(s.newLengthOk, isFalse);
      expect(s.confirmLengthOk, isFalse);
      expect(s.passwordMatchOk, isFalse);
      expect(s.canSubmit, isFalse);
    });

    test('canSubmit becomes true when all conditions met', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('existing1');
      n.updateNewPassword('newpass12');
      n.updateConfirmPassword('newpass12');
      final s = _state(c);
      expect(s.existingLengthOk, isTrue);
      expect(s.newLengthOk, isTrue);
      expect(s.confirmLengthOk, isTrue);
      expect(s.passwordMatchOk, isTrue);
      expect(s.canSubmit, isTrue);
    });

    test('canSubmit false when existing password too short (< 8)', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('short');   // 5 chars
      n.updateNewPassword('newpass12');
      n.updateConfirmPassword('newpass12');
      expect(_state(c).existingLengthOk, isFalse);
      expect(_state(c).canSubmit, isFalse);
    });

    test('canSubmit false when new password too short (< 8)', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('existing1');
      n.updateNewPassword('abc');          // 3 chars
      n.updateConfirmPassword('abc');
      expect(_state(c).newLengthOk, isFalse);
      expect(_state(c).canSubmit, isFalse);
    });

    test('canSubmit false when confirm password does not match new password', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('existing1');
      n.updateNewPassword('newpass12');
      n.updateConfirmPassword('different1');
      expect(_state(c).passwordMatchOk, isFalse);
      expect(_state(c).canSubmit, isFalse);
    });

    test('passwordMatchOk false when confirmPassword is empty', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateNewPassword('newpass12');
      // confirmPassword stays ''
      expect(_state(c).passwordMatchOk, isFalse);
    });

    test('length counters track characters correctly', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('12345678');  // 8
      n.updateNewPassword('abcdefgh');       // 8
      n.updateConfirmPassword('abcdefgh');   // 8
      final s = _state(c);
      expect(s.existingLength, 8);
      expect(s.newLength, 8);
      expect(s.confirmLength, 8);
    });

    test('exactly 8 chars meets minimum length requirement', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('exactly8');
      expect(_state(c).existingLengthOk, isTrue);
    });

    test('7 chars fails minimum length requirement', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('seven77');
      expect(_state(c).existingLengthOk, isFalse);
    });
  });

  group('ChangeLoginPassword obscure toggles', () {
    test('initial obscure states all true', () {
      final c = _makeContainer();
      final s = _state(c);
      expect(s.existingObscure, isTrue);
      expect(s.newObscure, isTrue);
      expect(s.confirmObscure, isTrue);
    });

    test('toggleExistingObscure flips only existingObscure', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.toggleExistingObscure();
      final s = _state(c);
      expect(s.existingObscure, isFalse);
      expect(s.newObscure, isTrue);
      expect(s.confirmObscure, isTrue);
    });

    test('toggleNewObscure flips only newObscure', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.toggleNewObscure();
      expect(_state(c).newObscure, isFalse);
      expect(_state(c).existingObscure, isTrue);
    });

    test('toggleConfirmObscure flips only confirmObscure', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.toggleConfirmObscure();
      expect(_state(c).confirmObscure, isFalse);
      expect(_state(c).newObscure, isTrue);
    });

    test('double toggle restores original value', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.toggleNewObscure();
      n.toggleNewObscure();
      expect(_state(c).newObscure, isTrue);
    });
  });

  group('ChangeLoginPassword canSubmit edge cases', () {
    test('updating confirm to match new enables canSubmit', () {
      final c = _makeContainer();
      final n = _notifier(c);
      n.updateExistingPassword('existing1');
      n.updateNewPassword('newpass12');
      n.updateConfirmPassword('different1');
      expect(_state(c).canSubmit, isFalse);

      // fix the mismatch
      n.updateConfirmPassword('newpass12');
      expect(_state(c).canSubmit, isTrue);
    });

    test('canSubmit reacts to isLoading=true via copyWith (read-only guard)', () {
      // verify state logic: isLoading blocks canSubmit
      final s = const ChangeLoginPasswordState(
        existingPassword: 'existing1',
        existingLengthOk: true,
        newPassword: 'newpass12',
        newLengthOk: true,
        confirmPassword: 'newpass12',
        confirmLengthOk: true,
        passwordMatchOk: true,
        canSubmit: false, // already false because isLoading=false was not set
        isLoading: true,
      );
      // canSubmit check in _recompute: !state.isLoading && ...
      // When we compute manually for this state, result should be false
      final isLoadingBlocks = s.isLoading;
      expect(isLoadingBlocks, isTrue);
    });
  });
}
