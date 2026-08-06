import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/passport_state.dart';

void main() {
  group('PassportState defaults', () {
    test('default values match expected initial passport form state', () {
      final ctl = TextEditingController();
      addTearDown(ctl.dispose);
      final s = PassportState(loginAccountCtl: ctl);
      expect(s.accountType, 'account');
      expect(s.loginPwdObscure, isTrue);
      expect(s.mobileValidated, isFalse);
      expect(s.showSignupContinue, isFalse);
      expect(s.error, '');
      expect(s.loginHistory, isEmpty);
      expect(s.signupAccount, isNull);
    });
  });

  group('PassportState copyWith', () {
    test('overrides only the passed fields, preserves others', () {
      final ctl = TextEditingController();
      addTearDown(ctl.dispose);
      final base = PassportState(loginAccountCtl: ctl);
      final next = base.copyWith(
        accountType: 'mobile',
        mobileValidated: true,
        error: 'bad',
      );
      expect(next.accountType, 'mobile');
      expect(next.mobileValidated, isTrue);
      expect(next.error, 'bad');
      // preserved
      expect(next.loginPwdObscure, isTrue);
      expect(identical(next.loginAccountCtl, ctl), isTrue);
      // base untouched (immutable)
      expect(base.accountType, 'account');
      expect(base.error, '');
    });

    test('toggling obscure flags works independently', () {
      final ctl = TextEditingController();
      addTearDown(ctl.dispose);
      final base = PassportState(loginAccountCtl: ctl);
      final next = base.copyWith(loginPwdObscure: false);
      expect(next.loginPwdObscure, isFalse);
      expect(next.newPwdObscure, isTrue);
      expect(next.retypePwdObscure, isTrue);
    });

    test('signup temp fields propagate via copyWith', () {
      final ctl = TextEditingController();
      addTearDown(ctl.dispose);
      final base = PassportState(loginAccountCtl: ctl);
      final next = base.copyWith(
        signupAccount: 'alice',
        signupAccountType: 'email',
        signupNickname: 'Alice',
      );
      expect(next.signupAccount, 'alice');
      expect(next.signupAccountType, 'email');
      expect(next.signupNickname, 'Alice');
    });
  });
}
