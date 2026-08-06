import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/account_security/bind_email_provider.dart';

/// BindEmailState.copyWith 纯逻辑单测
///
/// State 类为纯内存对象，copyWith 不触发任何单例（UserRepoLocal 仅在
/// Notifier 方法中访问），可直接 new 测试。
void main() {
  group('BindEmailState defaults', () {
    test('默认值正确', () {
      const s = BindEmailState();
      expect(s.email, '');
      expect(s.code, '');
      expect(s.emailLength, 0);
      expect(s.codeLength, 0);
      expect(s.emailOk, false);
      expect(s.codeOk, false);
      expect(s.seconds, 0);
      expect(s.isSendingCode, false);
      expect(s.isSubmitting, false);
      expect(s.canSendCode, false);
      expect(s.canSubmit, false);
    });
  });

  group('BindEmailState.copyWith', () {
    test('更新 email 与 emailOk，其余字段保持不变', () {
      const s = BindEmailState(code: '123456', codeOk: true);
      final next = s.copyWith(email: 'a@b.com', emailLength: 7, emailOk: true);

      expect(next.email, 'a@b.com');
      expect(next.emailLength, 7);
      expect(next.emailOk, true);
      // 未传入的字段保留原值
      expect(next.code, '123456');
      expect(next.codeOk, true);
    });

    test('未传参时返回等价副本', () {
      const s = BindEmailState(
        email: 'x@y.com',
        seconds: 42,
        isSubmitting: true,
      );
      final copy = s.copyWith();

      expect(copy.email, 'x@y.com');
      expect(copy.seconds, 42);
      expect(copy.isSubmitting, true);
      // 不可变：返回新实例
      expect(identical(copy, s), false);
    });

    test('可单独切换布尔标志位', () {
      const s = BindEmailState();
      final next = s.copyWith(
        canSendCode: true,
        canSubmit: true,
        isSendingCode: true,
      );

      expect(next.canSendCode, true);
      expect(next.canSubmit, true);
      expect(next.isSendingCode, true);
      expect(next.isSubmitting, false);
    });
  });
}
