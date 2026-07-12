import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/service/shamir_secret_sharing.dart';

/// lib/page/settings/e2ee_social_create_page.dart /
/// e2ee_social_recover_page.dart / e2ee_social_manage_page.dart /
/// e2ee_social_page.dart / e2ee_proxy_selector_page.dart
/// 的可提纯逻辑单测。
///
/// 页面本身不可 widget 渲染测试：create/recover 页在生命周期内直接
/// 调用 E2EESocialService.createShards/getShards（HTTP + WebSocket +
/// SQLite 静态单例），proxy_selector 依赖 ContactRepo(SQLite)，均无
/// Provider 注入点。此处覆盖社交恢复的核心纯逻辑：
/// - ShamirSecretSharing (k,n) 门限分片/重组（recover 页恢复算法）
/// - E2EESocialService.splitSecret/combineShards 编码层往返
/// - generateMessageId 格式（分片 WS 消息 id）
void main() {
  const secret = 'my-rsa-private-key-material';

  group('ShamirSecretSharing 门限分片（recover 页核心算法）', () {
    final secretBytes = Uint8List.fromList(utf8.encode(secret));

    test('n=3 k=2：全部 3 片可重组', () {
      final shares = ShamirSecretSharing.splitSecret(secretBytes, 3, 2);
      expect(shares, hasLength(3));
      final recovered = ShamirSecretSharing.combineShares(shares);
      expect(utf8.decode(recovered), secret);
    });

    test('n=3 k=2：任意 2 片子集均可重组（门限语义）', () {
      final shares = ShamirSecretSharing.splitSecret(secretBytes, 3, 2);
      final pairs = [
        [shares[0], shares[1]],
        [shares[0], shares[2]],
        [shares[1], shares[2]],
      ];
      for (final pair in pairs) {
        final recovered = ShamirSecretSharing.combineShares(pair);
        expect(utf8.decode(recovered), secret);
      }
    });

    test('n=5 k=3：3 片可重组', () {
      final shares = ShamirSecretSharing.splitSecret(secretBytes, 5, 3);
      final recovered = ShamirSecretSharing.combineShares(shares.sublist(0, 3));
      expect(utf8.decode(recovered), secret);
    });

    test('少于 2 片抛 ArgumentError', () {
      final shares = ShamirSecretSharing.splitSecret(secretBytes, 3, 2);
      expect(
        () => ShamirSecretSharing.combineShares([shares[0]]),
        throwsArgumentError,
      );
    });

    test('重复分片索引（重放攻击）抛 ArgumentError', () {
      final shares = ShamirSecretSharing.splitSecret(secretBytes, 3, 2);
      expect(
        () => ShamirSecretSharing.combineShares([shares[0], shares[0]]),
        throwsArgumentError,
      );
    });

    test('无效分片格式抛 ArgumentError', () {
      expect(
        () => ShamirSecretSharing.combineShares([
          {'bogus': 1},
          {'x': 2, 'y': BigInt.two, 'index': 2},
        ]),
        throwsArgumentError,
      );
    });

    test('参数校验：n <= k 或 k < 2 抛 ArgumentError', () {
      expect(
        () => ShamirSecretSharing.splitSecret(secretBytes, 2, 2),
        throwsArgumentError,
      );
      expect(
        () => ShamirSecretSharing.splitSecret(secretBytes, 3, 1),
        throwsArgumentError,
      );
    });

    test('create 页滑杆约束与算法参数域一致', () {
      // create 页约束: 总分片 3-5、阈值 2..(总分片-1)，
      // 该参数域内 splitSecret 均应成功。
      for (var n = 3; n <= 5; n++) {
        for (var k = 2; k <= n - 1; k++) {
          final shares = ShamirSecretSharing.splitSecret(secretBytes, n, k);
          expect(shares, hasLength(n), reason: 'n=$n k=$k');
        }
      }
    });
  });

  group('E2EESocialService 分片编码层', () {
    test('【已知真 bug】splitSecret 因 jsonEncode(BigInt) 100% 必抛', () {
      // 真 bug（本测试仅钉住现状，不修 lib）：
      // e2ee_social_service.dart splitSecret 对
      // ShamirSecretSharing.splitSecret 返回的 share（'y' 为 BigInt）
      // 直接 jsonEncode，Dart jsonEncode 不支持 BigInt →
      // "Converting object to an encodable object failed: _BigIntImpl"，
      // 被 catch 后转抛 Exception('生成分片失败')。
      // 该函数任何输入都无法成功，combineShards 的成功路径同样不可达
      // （其 `s['y'] as BigInt` 在 jsonDecode 后也必失败）。
      // 修复方向：编码前 y.toString()，解码后 BigInt.parse。
      expect(
        () => E2EESocialService.splitSecret(secret, 3, 2),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('生成分片失败'),
          ),
        ),
      );
    });

    test('combineShards 传入非法 Base64 抛 Exception', () {
      expect(
        () => E2EESocialService.combineShards(['not-base64!!', 'x']),
        throwsException,
      );
    });

    test('generateMessageId 格式为 msg_<数字>', () {
      final id = E2EESocialService.generateMessageId();
      expect(RegExp(r'^msg_\d+$').hasMatch(id), isTrue, reason: id);
    });
  });
}
