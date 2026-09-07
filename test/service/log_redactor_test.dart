import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/log_redactor.dart';

/// V-02 日志与崩溃脱敏回归语料
///
/// 覆盖计划测试条款：嵌套 map、headers、URL、异常文本、E2EE 明文/密文、
/// 支付回调；断言原始秘密在清洗产物中缺席。
void main() {
  group('scrubText 值模式', () {
    test('URL query 中的 token 被清值，参数名与非敏感参数保留', () {
      final out = LogRedactor.scrubText(
        'GET https://pro.imboy.pub/api/v1/user?token=abc123&uid=7',
      );
      expect(out, isNot(contains('abc123')));
      expect(out, contains('token=[REDACTED]'));
      expect(out, contains('uid=7'));
    });

    test('异常文本中的 JWT 被剥离', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      final out = LogRedactor.scrubText('auth failed with JWT $jwt');
      expect(out, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(out, contains('[REDACTED]'));
    });

    test('Bearer 凭据被剥离（大小写不敏感）', () {
      final out = LogRedactor.scrubText(
        'request header authorization: Bearer sk_live_9f8e7d',
      );
      expect(out, isNot(contains('sk_live_9f8e7d')));
    });

    test('手机号与邮箱被剥离，相邻字符不吞', () {
      final out = LogRedactor.scrubText(
        'user 13812345678 mail foo.bar@example.com ok',
      );
      expect(out, isNot(contains('13812345678')));
      expect(out, isNot(contains('foo.bar@example.com')));
      expect(out, contains('user [REDACTED] mail'));
    });

    test('支付回调 URL 的 sign 参数被清值', () {
      final out = LogRedactor.scrubText(
        'notify https://pro.imboy.pub/callback/alipay?sign=SECRETVALUE&ts=1',
      );
      expect(out, isNot(contains('SECRETVALUE')));
      expect(out, contains('sign=[REDACTED]'));
    });

    test('无秘密的普通文本原样保留（E2EE 密文 blob 可诊断）', () {
      const plain = '消息发送成功 msg_id=42 ciphertext=base64blob';
      expect(LogRedactor.scrubText(plain), plain);
    });
  });

  group('scrubDynamic 键+值双层', () {
    test('嵌套 map 里的 headers/token 逐层剥离', () {
      final out = LogRedactor.scrubDynamic(
        {
              'uid': 7,
              'req': {
                'headers': {
                  'Authorization': 'Bearer abc.def',
                  'cookie': 'sid=1',
                  'content-type': 'application/json',
                },
                'body': {'access_token': 'tok', 'nickname': 'n'},
              },
            }
            as Map,
      );
      final headers = out['req']['headers'] as Map;
      expect(headers['Authorization'], '[REDACTED]');
      expect(headers['cookie'], '[REDACTED]');
      expect(headers['content-type'], 'application/json');
      final body = out['req']['body'] as Map;
      expect(body['access_token'], '[REDACTED]');
      expect(body['nickname'], 'n');
    });

    test('E2EE 明文键被剥离，密文保留可诊断', () {
      final out = LogRedactor.scrubDynamic(
        {'plaintext': '你好，这是明文消息', 'ciphertext': 'base64blob'} as Map,
      );
      expect(out['plaintext'], '[REDACTED]');
      expect(out['ciphertext'], 'base64blob');
    });

    test('支付回调载荷：sign/openid 剥离，订单号保留', () {
      final out = LogRedactor.scrubDynamic(
        {
              'out_trade_no': 'T123',
              'sign': 'ABCD1234',
              'openid': 'oX-123456',
              'total_fee': 100,
            }
            as Map,
      );
      expect(out['out_trade_no'], 'T123');
      expect(out['sign'], '[REDACTED]');
      expect(out['openid'], '[REDACTED]');
      expect(out['total_fee'], 100);
    });

    test('键精确匹配：design/assignment 不误伤', () {
      final out = LogRedactor.scrubDynamic(
        {'design': 'ok', 'assignment': 1, 'sign': 'x'} as Map,
      );
      expect(out['design'], 'ok');
      expect(out['assignment'], 1);
      expect(out['sign'], '[REDACTED]');
    });

    test('list 内字符串值也过值模式', () {
      final out = LogRedactor.scrubDynamic(
        ['ok', 'call 13812345678 now'] as List,
      );
      expect(out[0], 'ok');
      expect(out[1] as String, isNot(contains('13812345678')));
    });
  });

  group('scrubMaybeJson 内嵌 JSON', () {
    test('JSON 字符串展开后做键级清洗再序列化', () {
      const input = '{"body":{"password":"hunter2","nickname":"n"},"ts":123}';
      final out = LogRedactor.scrubMaybeJson(input);
      final decoded = jsonDecode(out) as Map;
      expect(decoded['body']['password'], '[REDACTED]');
      expect(decoded['body']['nickname'], 'n');
    });

    test('非 JSON 字符串退回纯文本值模式', () {
      final out = LogRedactor.scrubMaybeJson('failed: Bearer abc123def456');
      expect(out, isNot(contains('abc123def456')));
    });
  });
}
