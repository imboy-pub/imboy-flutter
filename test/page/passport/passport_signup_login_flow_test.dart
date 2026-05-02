import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/func.dart';

// ─── 纯函数验证规则（signup_page.dart 的客户端校验逻辑提取） ───

/// 模拟 signup_page.dart 邮箱注册 Tab 的"下一步"校验
/// 对应 signup_page.dart:220-246
String? validateEmailSignupStep({
  required String nickname,
  required String email,
  required String pwd,
}) {
  if (nickname.isEmpty) return 'nickname_empty';
  if (email.isEmpty || pwd.isEmpty) return 'email_or_pwd_empty';
  if (!isEmail(email)) return 'email_invalid';
  if (pwd.length < 4 || pwd.length > 32) return 'pwd_length_invalid';
  return null; // 通过
}

/// 模拟 signup_page.dart 手机注册 Tab 的"下一步"校验
/// 对应 signup_page.dart:322-351
String? validateMobileSignupStep({
  required String nickname,
  required String fullMobile,
  required String pwd,
}) {
  if (nickname.isEmpty) return 'nickname_empty';
  if (fullMobile.isEmpty || pwd.isEmpty) return 'mobile_or_pwd_empty';
  if (pwd.length < 4 || pwd.length > 32) return 'pwd_length_invalid';
  return null;
}

/// 模拟 passport_notifier.dart:280-292 userValidator
String? userValidator(String accountType, String value) {
  if (value.isEmpty) return 'error_empty';
  if (accountType == 'mobile' && !isPhone(value)) return 'mobile_invalid';
  if (accountType == 'email' && !isEmail(value)) return 'email_invalid';
  if (accountType == 'account' && value.length < 5) return 'account_invalid';
  return null;
}

/// 模拟 passport_notifier.dart:295-303 passwordValidator
String? passwordValidator(String? val) {
  if (strEmpty(val)) return 'pwd_empty';
  if (val!.length < 4 || val.length > 32) return 'pwd_length';
  return null;
}

/// 模拟 passport_notifier.dart:762-777 checkSignupContinue
bool checkSignupContinue({
  required String nickname,
  required bool mobileValidated,
  required String selectedAgreement,
  required String newPwd,
}) {
  final pwdValidated = passwordValidator(newPwd) == null;
  return nickname.length > 1 &&
      mobileValidated &&
      selectedAgreement == 'on' &&
      pwdValidated;
}

// ─── Tests ───

void main() {
  // ─── isEmail 基础校验 ───
  group('isEmail', () {
    test('valid email returns true', () {
      expect(isEmail('user@example.com'), isTrue);
    });

    test('valid email with subdomain returns true', () {
      expect(isEmail('user@mail.example.co.uk'), isTrue);
    });

    test('empty string returns false', () {
      expect(isEmail(''), isFalse);
    });

    test('missing @ returns false', () {
      expect(isEmail('userexample.com'), isFalse);
    });

    test('missing domain returns false', () {
      expect(isEmail('user@'), isFalse);
    });

    test('missing TLD returns false', () {
      expect(isEmail('user@example'), isFalse);
    });

    test('spaces in email returns false', () {
      expect(isEmail('user @example.com'), isFalse);
    });

    test('double @ returns false', () {
      expect(isEmail('user@@example.com'), isFalse);
    });
  });

  // ─── isPhone 基础校验 ───
  group('isPhone', () {
    test('Chinese mobile returns true', () {
      expect(isPhone('13800138000'), isTrue);
    });

    test('empty string returns false', () {
      expect(isPhone(''), isFalse);
    });

    test('letters return false', () {
      expect(isPhone('abcdefghijk'), isFalse);
    });

    test('too short returns false', () {
      expect(isPhone('138'), isFalse);
    });
  });

  // ─── userValidator ───
  group('userValidator', () {
    test('empty value returns error', () {
      expect(userValidator('account', ''), isNotNull);
    });

    test('account < 5 chars returns error', () {
      expect(userValidator('account', 'abc'), isNotNull);
    });

    test('account >= 5 chars passes', () {
      expect(userValidator('account', 'abcde'), isNull);
    });

    test('invalid email returns error', () {
      expect(userValidator('email', 'notanemail'), isNotNull);
    });

    test('valid email passes', () {
      expect(userValidator('email', 'user@example.com'), isNull);
    });

    test('invalid mobile returns error', () {
      expect(userValidator('mobile', '123'), isNotNull);
    });

    test('valid mobile passes', () {
      expect(userValidator('mobile', '13800138000'), isNull);
    });
  });

  // ─── passwordValidator ───
  group('passwordValidator', () {
    test('null returns error', () {
      expect(passwordValidator(null), isNotNull);
    });

    test('empty returns error', () {
      expect(passwordValidator(''), isNotNull);
    });

    test('3 chars returns error', () {
      expect(passwordValidator('abc'), isNotNull);
    });

    test('4 chars passes', () {
      expect(passwordValidator('abcd'), isNull);
    });

    test('32 chars passes', () {
      expect(passwordValidator('a' * 32), isNull);
    });

    test('33 chars returns error', () {
      expect(passwordValidator('a' * 33), isNotNull);
    });
  });

  // ─── validateEmailSignupStep ───
  group('Email signup step validation', () {
    test('empty nickname returns error', () {
      expect(
        validateEmailSignupStep(
          nickname: '',
          email: 'user@example.com',
          pwd: 'password123',
        ),
        'nickname_empty',
      );
    });

    test('empty email returns error', () {
      expect(
        validateEmailSignupStep(
          nickname: 'Alice',
          email: '',
          pwd: 'password123',
        ),
        'email_or_pwd_empty',
      );
    });

    test('empty password returns error', () {
      expect(
        validateEmailSignupStep(
          nickname: 'Alice',
          email: 'user@example.com',
          pwd: '',
        ),
        'email_or_pwd_empty',
      );
    });

    test('invalid email returns error', () {
      expect(
        validateEmailSignupStep(
          nickname: 'Alice',
          email: 'notanemail',
          pwd: 'password123',
        ),
        'email_invalid',
      );
    });

    test('password too short returns error', () {
      expect(
        validateEmailSignupStep(
          nickname: 'Alice',
          email: 'user@example.com',
          pwd: 'abc',
        ),
        'pwd_length_invalid',
      );
    });

    test('all valid returns null (pass)', () {
      expect(
        validateEmailSignupStep(
          nickname: 'Alice',
          email: 'user@example.com',
          pwd: 'password123',
        ),
        isNull,
      );
    });
  });

  // ─── validateMobileSignupStep ───
  group('Mobile signup step validation', () {
    test('empty nickname returns error', () {
      expect(
        validateMobileSignupStep(
          nickname: '',
          fullMobile: '+8613800138000',
          pwd: 'password123',
        ),
        'nickname_empty',
      );
    });

    test('empty mobile returns error', () {
      expect(
        validateMobileSignupStep(
          nickname: 'Alice',
          fullMobile: '',
          pwd: 'password123',
        ),
        'mobile_or_pwd_empty',
      );
    });

    test('password too short returns error', () {
      expect(
        validateMobileSignupStep(
          nickname: 'Alice',
          fullMobile: '+8613800138000',
          pwd: 'ab',
        ),
        'pwd_length_invalid',
      );
    });

    test('all valid returns null (pass)', () {
      expect(
        validateMobileSignupStep(
          nickname: 'Alice',
          fullMobile: '+8613800138000',
          pwd: 'password123',
        ),
        isNull,
      );
    });
  });

  // ─── checkSignupContinue ───
  group('checkSignupContinue', () {
    test('all conditions met returns true', () {
      expect(
        checkSignupContinue(
          nickname: 'Alice',
          mobileValidated: true,
          selectedAgreement: 'on',
          newPwd: 'password123',
        ),
        isTrue,
      );
    });

    test('nickname too short returns false', () {
      expect(
        checkSignupContinue(
          nickname: 'A',
          mobileValidated: true,
          selectedAgreement: 'on',
          newPwd: 'password123',
        ),
        isFalse,
      );
    });

    test('not validated returns false', () {
      expect(
        checkSignupContinue(
          nickname: 'Alice',
          mobileValidated: false,
          selectedAgreement: 'on',
          newPwd: 'password123',
        ),
        isFalse,
      );
    });

    test('agreement not accepted returns false', () {
      expect(
        checkSignupContinue(
          nickname: 'Alice',
          mobileValidated: true,
          selectedAgreement: '',
          newPwd: 'password123',
        ),
        isFalse,
      );
    });

    test('invalid password returns false', () {
      expect(
        checkSignupContinue(
          nickname: 'Alice',
          mobileValidated: true,
          selectedAgreement: 'on',
          newPwd: 'ab',
        ),
        isFalse,
      );
    });
  });
}
