/// AC-06 — 重发路径降级密文闸门测试。
///
/// 发送侧固定套件策略（C02 FixedSuitePolicy）已由
/// `c2c_fanout_suite_policy_wiring_test.dart` 证明接入生产加密链；本文件
/// 证明**重发路径**同样经过保护：加密必需策略下，
/// - 明文行 → 由既有明文闸门拦（`shouldBlockPlaintextRetry`）；
/// - 带 e2ee 元数据但套件非 scope required（存量 RSA legacy 密文）→
///   由 `isDowngradedCipherRetryBlocked` 拦，落终态 error，不重发出网；
/// - 合规密文（c2c→olm / c2g→megolm）→ 放行。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_retry.dart';

void main() {
  group('isDowngradedCipherRetryBlocked（AC-06 重试防降级）', () {
    test('加密必需 + C2C 行套件为 olm → 放行', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2C',
          e2ee: {
            'meta_version': 3,
            'protocol': 'olm',
            'fan_out': 'per_device',
            'devices': <String, dynamic>{},
          },
        ),
        isFalse,
      );
    });

    test('加密必需 + C2C 行套件为 RSA legacy（e2ee_ver 1 wire）→ 拦截', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2C',
          e2ee: {
            'e2ee': true,
            'e2ee_ver': 1,
            'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
          },
        ),
        isTrue,
      );
    });

    test('加密必需 + C2G 行套件为 megolm → 放行', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2G',
          e2ee: {'meta_version': 3, 'protocol': 'megolm'},
        ),
        isFalse,
      );
    });

    test('加密必需 + C2G 行套件为 olm（scope 错配）→ 拦截', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2G',
          e2ee: {'protocol': 'olm'},
        ),
        isTrue,
      );
    });

    test('加密必需 + 元数据无法判读套件（protocol/e2ee_suite 均缺）→ fail-closed 拦截', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2C',
          e2ee: {'meta_version': 2},
        ),
        isTrue,
      );
    });

    test('策略不要求加密（明文部署）→ 不拦密文行（降级判定只在加密必需下生效）', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: false,
          chatType: 'C2C',
          e2ee: {'e2ee_ver': 1, 'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM'},
        ),
        isFalse,
      );
    });

    test('e2ee 为空/null → 不属于本闸门（由明文闸门处理）', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2C',
          e2ee: null,
        ),
        isFalse,
      );
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2C',
          e2ee: const <String, dynamic>{},
        ),
        isFalse,
      );
    });

    test('v2 双写形态（protocol 三元组 + legacy e2ee_suite）优先按 protocol 判读', () {
      expect(
        isDowngradedCipherRetryBlocked(
          encryptionRequired: true,
          chatType: 'C2C',
          e2ee: {'protocol': 'olm', 'version': 1, 'e2ee_suite': 'OLM.V1'},
        ),
        isFalse,
      );
    });
  });
}
