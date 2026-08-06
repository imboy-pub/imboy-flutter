import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/payment_gateway.dart';
import 'package:imboy/service/payment_launcher.dart';

/// 可注入的 fake 网关，记录调用并返回预设结果，隔离真机原生 SDK。
class _FakeGateway implements PaymentSdkGateway {
  Map<dynamic, dynamic> aliPayReturn = const {'resultStatus': '9000'};
  bool wechatRegisteredReturn = true;
  int? wechatPayReturn = 0;

  int aliPayCalls = 0;
  int wechatPayCalls = 0;
  String? lastAliOrder;

  @override
  Future<Map<dynamic, dynamic>> aliPay(
    String orderStr, {
    String? universalLink,
  }) async {
    aliPayCalls++;
    lastAliOrder = orderStr;
    return aliPayReturn;
  }

  @override
  Future<bool> ensureWechatRegistered({
    required String appId,
    String? universalLink,
  }) async => wechatRegisteredReturn;

  @override
  Future<int?> wechatPay({
    required String appId,
    required String partnerId,
    required String prepayId,
    required String packageValue,
    required String nonceStr,
    required int timestamp,
    required String sign,
    String? signType,
  }) async {
    wechatPayCalls++;
    return wechatPayReturn;
  }
}

void main() {
  group('parseAlipayResult', () {
    test('9000 maps to success', () {
      expect(
        PaymentLauncher.parseAlipayResult({'resultStatus': '9000'}),
        PaymentLaunchResult.success,
      );
    });

    test('6001 maps to cancelled', () {
      expect(
        PaymentLauncher.parseAlipayResult({'resultStatus': '6001'}),
        PaymentLaunchResult.cancelled,
      );
    });

    test('other status maps to failed', () {
      expect(
        PaymentLauncher.parseAlipayResult({'resultStatus': '4000'}),
        PaymentLaunchResult.failed,
      );
    });

    test('missing status maps to failed', () {
      expect(
        PaymentLauncher.parseAlipayResult(const {}),
        PaymentLaunchResult.failed,
      );
    });

    test('numeric status is coerced and matched', () {
      expect(
        PaymentLauncher.parseAlipayResult({'resultStatus': 9000}),
        PaymentLaunchResult.success,
      );
    });
  });

  group('parseWechatResult', () {
    test('errCode 0 maps to success', () {
      expect(PaymentLauncher.parseWechatResult(0), PaymentLaunchResult.success);
    });

    test('errCode -2 maps to cancelled', () {
      expect(
        PaymentLauncher.parseWechatResult(-2),
        PaymentLaunchResult.cancelled,
      );
    });

    test('errCode -1 maps to failed', () {
      expect(PaymentLauncher.parseWechatResult(-1), PaymentLaunchResult.failed);
    });

    test('null errCode (no callback) maps to failed', () {
      expect(
        PaymentLauncher.parseWechatResult(null),
        PaymentLaunchResult.failed,
      );
    });
  });

  group('parseWechatParams', () {
    Map<String, dynamic> fullParams() => {
      'appid': 'wx_backend',
      'partnerid': '1900000109',
      'prepay_id': 'wx2017...',
      'package': 'Sign=WXPay',
      'noncestr': 'abc123',
      'timestamp': 1490840662,
      'sign': 'SIGNVALUE',
      'signtype': 'RSA',
    };

    test('full params produce fields', () {
      final fields = PaymentLauncher.parseWechatParams(
        fullParams(),
        'wx_config',
      );
      expect(fields, isNotNull);
      expect(fields!.appId, 'wx_backend'); // backend wins over config
      expect(fields.partnerId, '1900000109');
      expect(fields.prepayId, 'wx2017...');
      expect(fields.timestamp, 1490840662);
      expect(fields.signType, 'RSA');
    });

    test('falls back to config appId when backend omits it', () {
      final p = fullParams()..remove('appid');
      final fields = PaymentLauncher.parseWechatParams(p, 'wx_config');
      expect(fields, isNotNull);
      expect(fields!.appId, 'wx_config');
    });

    test('missing partnerid degrades to null', () {
      final p = fullParams()..remove('partnerid');
      expect(PaymentLauncher.parseWechatParams(p, 'wx_config'), isNull);
    });

    test('missing prepay_id degrades to null', () {
      final p = fullParams()..remove('prepay_id');
      expect(PaymentLauncher.parseWechatParams(p, 'wx_config'), isNull);
    });

    test('missing sign degrades to null', () {
      final p = fullParams()..remove('sign');
      expect(PaymentLauncher.parseWechatParams(p, 'wx_config'), isNull);
    });

    test('missing/zero timestamp degrades to null', () {
      final p = fullParams()..['timestamp'] = 0;
      expect(PaymentLauncher.parseWechatParams(p, 'wx_config'), isNull);
    });

    test('empty appId both sides degrades to null', () {
      final p = fullParams()..remove('appid');
      expect(PaymentLauncher.parseWechatParams(p, ''), isNull);
    });

    test('default package applied when omitted', () {
      final p = fullParams()..remove('package');
      final fields = PaymentLauncher.parseWechatParams(p, 'wx_config');
      expect(fields, isNotNull);
      expect(fields!.packageValue, 'Sign=WXPay');
    });

    test('string timestamp is coerced', () {
      final p = fullParams()..['timestamp'] = '1490840662';
      final fields = PaymentLauncher.parseWechatParams(p, 'wx_config');
      expect(fields, isNotNull);
      expect(fields!.timestamp, 1490840662);
    });

    test('accepts alternate key prepayid/nonce_str', () {
      final p = fullParams()
        ..remove('prepay_id')
        ..['prepayid'] = 'alt_prepay'
        ..remove('noncestr')
        ..['nonce_str'] = 'alt_nonce';
      final fields = PaymentLauncher.parseWechatParams(p, 'wx_config');
      expect(fields, isNotNull);
      expect(fields!.prepayId, 'alt_prepay');
      expect(fields.nonceStr, 'alt_nonce');
    });
  });

  group('launch dispatch / degradation', () {
    late _FakeGateway gateway;
    late PaymentLauncher launcher;

    setUp(() {
      gateway = _FakeGateway();
      launcher = PaymentLauncher(gateway: gateway);
    });

    test('unknown method degrades to notConfigured', () async {
      final r = await launcher.launch('paypal', const {});
      expect(r, PaymentLaunchResult.notConfigured);
    });

    test('wallet method (should not reach launcher) degrades', () async {
      final r = await launcher.launch('wallet', const {});
      expect(r, PaymentLaunchResult.notConfigured);
    });

    test('alipay without appId config degrades to notConfigured', () async {
      // PaymentConfig.alipayAppId 在测试环境（无 --dart-define）为空 → 降级
      final r = await launcher.launch('alipay', {
        'order_str': 'app_id=2021...&biz_content=...',
      });
      expect(r, PaymentLaunchResult.notConfigured);
      expect(gateway.aliPayCalls, 0); // 未配置时不触碰 SDK
    });

    test('wechat without appId config degrades to notConfigured', () async {
      final r = await launcher.launch('wechat', {
        'partnerid': '1900000109',
        'prepay_id': 'wx2017...',
        'noncestr': 'abc',
        'timestamp': 1490840662,
        'sign': 'SIG',
      });
      expect(r, PaymentLaunchResult.notConfigured);
      expect(gateway.wechatPayCalls, 0);
    });
  });
}
