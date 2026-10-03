import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/log_redactor.dart';

/// C05 日志边界：异常文本不得携带密钥 / pickle / 私钥 PEM / 明文消息片段。
/// 覆盖 [LogRedactor] 新增的 E2EE 密钥材料形态，以及 [AppLogger]
/// error/fatal 出口的脱敏接线（源码断言——生产日志唯一出口）。
void main() {
  const dbKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const pem =
      '-----BEGIN PRIVATE KEY-----\n'
      'MIIEvQIBADANBgkqhkiG9w0BAQEFAASC\n'
      '-----END PRIVATE KEY-----'; // gitleaks:allow

  test('64-hex 密钥（db_cipher_key 值形态）被脱敏', () {
    final out = LogRedactor.scrubText('open db failed with key=$dbKey');
    expect(out, isNot(contains(dbKey)));
    expect(out, contains('[REDACTED]'));
  });

  test('SQLCipher rawKey 字面量 x\'..\' 被脱敏', () {
    final out = LogRedactor.scrubText("PRAGMA key = x'$dbKey'");
    expect(out, isNot(contains(dbKey)));
  });

  test('PEM 私钥块整体被脱敏', () {
    final out = LogRedactor.scrubText('load identity failed: $pem retry');
    expect(out, isNot(contains('BEGIN PRIVATE KEY')));
    expect(out, isNot(contains('MIIEvQIB')));
    expect(out, contains('[REDACTED]'));
  });

  test('既有形态不回归：JWT / Bearer / 手机号 / 邮箱', () {
    expect(
      LogRedactor.scrubText(
        'jwt=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U', // gitleaks:allow
      ),
      isNot(contains('eyJhbGciOiJIUzI1NiJ9')),
    );
    expect(
      LogRedactor.scrubText('Authorization: Bearer abcdefghijklmn'),
      isNot(contains('abcdefghijklmn')),
    );
    expect(
      LogRedactor.scrubText('user 13800138000 called'),
      isNot(contains('13800138000')),
    );
    expect(
      LogRedactor.scrubText('mail from a.b@example.com ok'),
      isNot(contains('a.b@example.com')),
    );
  });

  test('不误伤：短 hex / 纯数字 TSID / 普通文本 / 哈希摘要（<64）', () {
    expect(
      LogRedactor.scrubText('msgId=900163840023741152 ok'),
      contains('900163840023741152'),
    );
    // 32-hex MD5 形态不受影响（不是 64-hex）
    const md5 = 'd41d8cd98f00b204e9800998ecf8427e';
    expect(LogRedactor.scrubText('etag $md5'), contains(md5));
    // 63-hex 不命中
    final hex63 = dbKey.substring(0, 63);
    expect(LogRedactor.scrubText('odd $hex63 end'), contains(hex63));
    expect(LogRedactor.scrubText('正常中文日志 line'), '正常中文日志 line');
  });

  test('scrubDynamic 嵌套结构中的密钥值同样脱敏', () {
    final out = LogRedactor.scrubDynamic({
      'db_key': dbKey,
      'nested': [
        {'pem': pem},
      ],
      'count': 3,
    }) as Map;
    expect(out['db_key'], isNot(contains(dbKey)));
    final nested = (out['nested'] as List).first as Map;
    expect(nested['pem'], isNot(contains('BEGIN PRIVATE KEY')));
    expect(out['count'], 3);
  });

  // ─── AppLogger 出口接线（源码断言） ────────────────────────────────────────

  test('AppLogger error/fatal 出口经过 LogRedactor.scrubText', () {
    final source = File('lib/service/app_logger.dart').readAsStringSync();
    expect(
      source.contains('import \'package:imboy/service/log_redactor.dart\';'),
      isTrue,
      reason: 'app_logger 未引入 LogRedactor（出口脱敏被移除）',
    );
    // error 与 fatal 都必须先 scrub 再输出/派发（出现次数 >= 2 处调用）
    expect(
      RegExp('LogRedactor\\.scrubText').allMatches(source).length,
      greaterThanOrEqualTo(3),
      reason: 'error/fatal 的 message 与 error 对象出口脱敏不完整',
    );
    // 事件派发不得绕过脱敏值
    expect(source, contains('message: safeMessage'));
  });

  test('logging_privacy_guard 红线不回归（E2EE 服务异常日志形态）', () {
    // C05 复核 finding 014：三个 E2EE 服务仍保持 runtimeType-only 形态
    const files = [
      'lib/service/olm_session_service.dart',
      'lib/service/group_session_service.dart',
      'lib/page/chat/chat/services/chat_network_service.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('runtimeType'), reason: path);
      // 不得回退为完整异常对象直传（e / $e 结尾的 error 打印形态）
      expect(source, isNot(contains('error: e,')));
      expect(source, isNot(contains(r"error: '$e'")));
    }
  });
}
