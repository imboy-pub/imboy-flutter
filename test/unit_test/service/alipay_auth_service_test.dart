import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/alipay_auth_service.dart';

/// alipay_auth_service 纯函数测试（支付宝 SDK 回调解析，不触原生）
void main() {
  group('parseAlipayAuthResponse', () {
    test('9000 + Android query-string result → 提取 auth_code', () {
      final res = parseAlipayAuthResponse({
        'resultStatus': '9000',
        'result':
            'success=true&result_code=200&auth_code=authcode123&user_id=2088xxxx',
        'memo': '处理成功',
      });
      expect(res, isA<AlipayAuthSuccess>());
      expect((res as AlipayAuthSuccess).authCode, 'authcode123');
    });

    test('9000 + iOS Map result → 提取 auth_code', () {
      final res = parseAlipayAuthResponse({
        'resultStatus': '9000',
        'result': {'auth_code': 'ioscode456', 'success': 'true'},
        'memo': '',
      });
      expect(res, isA<AlipayAuthSuccess>());
      expect((res as AlipayAuthSuccess).authCode, 'ioscode456');
    });

    test('9000 但缺 auth_code → Failure', () {
      final res = parseAlipayAuthResponse({
        'resultStatus': '9000',
        'result': 'success=true&result_code=200',
        'memo': '',
      });
      expect(res, isA<AlipayAuthFailure>());
    });

    test('6001 用户取消 → Cancelled', () {
      final res = parseAlipayAuthResponse({
        'resultStatus': '6001',
        'result': '',
        'memo': '用户取消',
      });
      expect(res, isA<AlipayAuthCancelled>());
    });

    test('6002 网络错误 → Failure 提示网络', () {
      final res = parseAlipayAuthResponse({
        'resultStatus': '6002',
        'result': '',
        'memo': '',
      });
      expect(res, isA<AlipayAuthFailure>());
      expect((res as AlipayAuthFailure).message, contains('网络'));
    });

    test('其他状态码 → Failure 透出 memo', () {
      final res = parseAlipayAuthResponse({
        'resultStatus': '4000',
        'result': '',
        'memo': '系统异常',
      });
      expect(res, isA<AlipayAuthFailure>());
      expect((res as AlipayAuthFailure).message, '系统异常');
    });

    test('memo 为空 → Failure 兜底文案带状态码', () {
      final res = parseAlipayAuthResponse({
        'resultStatus': '8000',
        'result': '',
        'memo': '',
      });
      expect(res, isA<AlipayAuthFailure>());
      expect((res as AlipayAuthFailure).message, contains('8000'));
    });
  });
}
