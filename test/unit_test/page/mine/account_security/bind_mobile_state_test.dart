import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/account_security/bind_mobile_provider.dart';

/// BindMobileState.copyWith + getRegionCodeList 纯逻辑单测
///
/// State 类为纯内存对象，copyWith 不触发任何单例（UserRepoLocal 仅在
/// Notifier 方法中访问），可直接 new 测试。
void main() {
  group('BindMobileState defaults', () {
    test('默认值正确', () {
      const s = BindMobileState();
      expect(s.mobile, '');
      expect(s.code, '');
      expect(s.mobileLength, 0);
      expect(s.codeLength, 0);
      expect(s.mobileOk, false);
      expect(s.codeOk, false);
      expect(s.seconds, 0);
      expect(s.canSendCode, false);
      expect(s.canSubmit, false);
    });
  });

  group('BindMobileState.copyWith', () {
    test('更新 mobile 与 mobileOk，其余字段保持不变', () {
      const s = BindMobileState(code: '654321', codeOk: true);
      final next = s.copyWith(
        mobile: '13800138000',
        mobileLength: 11,
        mobileOk: true,
      );

      expect(next.mobile, '13800138000');
      expect(next.mobileLength, 11);
      expect(next.mobileOk, true);
      expect(next.code, '654321');
      expect(next.codeOk, true);
    });

    test('未传参时返回等价新副本', () {
      const s = BindMobileState(mobile: '111', seconds: 30, canSubmit: true);
      final copy = s.copyWith();

      expect(copy.mobile, '111');
      expect(copy.seconds, 30);
      expect(copy.canSubmit, true);
      expect(identical(copy, s), false);
    });

    test('可单独更新倒计时 seconds', () {
      const s = BindMobileState(seconds: 60);
      final next = s.copyWith(seconds: 59);
      expect(next.seconds, 59);
    });
  });

  group('getRegionCodeList', () {
    test('返回非空常用国家代码列表且包含 CN', () {
      final list = getRegionCodeList('signup');
      expect(list, isNotEmpty);
      expect(list, contains('CN'));
    });
  });
}
