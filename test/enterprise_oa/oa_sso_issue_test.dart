/// EPGZ-06 W3 — OA SSO 签发域逻辑测试（纯函数）
///
/// 覆盖：nonce 生成/校验合同（A5：16..128、[A-Za-z0-9_-]、CSPRNG）、
/// launch URL 构造（code/state 原样附加、保留既有 query）、issue 侧
/// 错误码 → 状态机目标态映射矩阵。
library;

import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_oa/domain/oa_sso_issue.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';

void main() {
  group('generateOaSsoNonce — A5 合同形态', () {
    test('缺省 CSPRNG 生成的 nonce 合法且不可预测长度', () {
      for (int i = 0; i < 32; i++) {
        final nonce = generateOaSsoNonce();
        expect(isValidOaSsoNonce(nonce), isTrue, reason: nonce);
        expect(nonce.length, oaSsoNonceLength);
      }
    });

    test('两次生成不重复（CSPRNG）', () {
      final Set<String> seen = <String>{};
      for (int i = 0; i < 64; i++) {
        seen.add(generateOaSsoNonce());
      }
      expect(seen.length, 64);
    });

    test('注入固定随机源的确定性（测试专用）', () {
      final a = generateOaSsoNonce(Random(42));
      final b = generateOaSsoNonce(Random(42));
      expect(a, b);
      expect(isValidOaSsoNonce(a), isTrue);
    });
  });

  group('isValidOaSsoNonce — 合同区间与字符集', () {
    test('16 字符下界合法 / 15 字符非法', () {
      expect(isValidOaSsoNonce('a' * 16), isTrue);
      expect(isValidOaSsoNonce('a' * 15), isFalse);
    });

    test('128 字符上界合法 / 129 字符非法', () {
      expect(isValidOaSsoNonce('a' * 128), isTrue);
      expect(isValidOaSsoNonce('a' * 129), isFalse);
    });

    test('仅 [A-Za-z0-9_-]；空白与特殊字符非法', () {
      expect(isValidOaSsoNonce('ABCDabcd1234-_ABCD'), isTrue);
      expect(isValidOaSsoNonce('ABCD abcd1234ABCD'), isFalse);
      expect(isValidOaSsoNonce('ABCDabcd1234ABCD!'), isFalse);
      expect(isValidOaSsoNonce('ABCDabcd1234+ABD'), isFalse);
      expect(isValidOaSsoNonce('ABCDabcd1234=ABD'), isFalse);
    });

    test('空串非法', () {
      expect(isValidOaSsoNonce(''), isFalse);
    });
  });

  group('buildOaSsoLaunchUrl — redirect_uri?code&state', () {
    test('基础形态：无既有 query 的 redirect', () {
      final url = buildOaSsoLaunchUrl(
        redirectUri: 'https://oa.example.com/sso/landing',
        code: 'oa_sso_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvw',
        state: 'nonce-STATE_0123456789abcdef',
      );
      expect(url, startsWith('https://oa.example.com/sso/landing?'));
      final Uri uri = Uri.parse(url);
      expect(uri.queryParameters['code'], startsWith('oa_sso_'));
      expect(
        uri.queryParameters['state'],
        'nonce-STATE_0123456789abcdef',
        reason: 'state 必须原样回传（跨端点绑定链）',
      );
    });

    test('保留 redirect_uri 既有 query（code/state 附加不覆盖）', () {
      final url = buildOaSsoLaunchUrl(
        redirectUri: 'https://oa.example.com/landing?from=imboy&x=1',
        code: 'oa_sso_c',
        state: 'st',
      );
      final Uri uri = Uri.parse(url);
      expect(uri.queryParameters['from'], 'imboy');
      expect(uri.queryParameters['x'], '1');
      expect(uri.queryParameters['code'], 'oa_sso_c');
      expect(uri.queryParameters['state'], 'st');
    });

    test('code/state 中的保留字符被编码（注入防御）', () {
      final url = buildOaSsoLaunchUrl(
        redirectUri: 'https://oa.example.com/landing',
        code: 'oa_sso_a&b=c',
        state: 'st#frag',
      );
      final Uri uri = Uri.parse(url);
      expect(uri.queryParameters['code'], 'oa_sso_a&b=c');
      expect(uri.queryParameters['state'], 'st#frag');
      expect(Uri.parse(url).fragment, isEmpty, reason: 'state 不得逃逸成 fragment');
    });
  });

  group('targetStatusForIssueFailure — issue 侧错误映射矩阵', () {
    test('unauthorized → sessionExpired（重新单点登录动作）', () {
      expect(
        targetStatusForIssueFailure(OaSsoIssueFailureKind.unauthorized),
        OaTabStatus.sessionExpired,
      );
    });

    test('network/badRequest/forbidden/notFound/server/unknown → error', () {
      const kinds = <OaSsoIssueFailureKind>[
        OaSsoIssueFailureKind.network,
        OaSsoIssueFailureKind.badRequest,
        OaSsoIssueFailureKind.forbidden,
        OaSsoIssueFailureKind.notFound,
        OaSsoIssueFailureKind.server,
        OaSsoIssueFailureKind.unknown,
      ];
      for (final kind in kinds) {
        expect(targetStatusForIssueFailure(kind), OaTabStatus.error);
      }
    });

    test('wireName 稳定（对齐日志/后端排查面）', () {
      expect(OaSsoIssueFailureKind.network.wireName, 'network');
      expect(OaSsoIssueFailureKind.badRequest.wireName, 'badRequest');
      expect(OaSsoIssueFailureKind.unauthorized.wireName, 'unauthorized');
      expect(OaSsoIssueFailureKind.forbidden.wireName, 'forbidden');
      expect(OaSsoIssueFailureKind.notFound.wireName, 'notFound');
      expect(OaSsoIssueFailureKind.server.wireName, 'server');
      expect(OaSsoIssueFailureKind.unknown.wireName, 'unknown');
    });
  });

  group('OaSsoCodeIssued — 数据形态', () {
    test('字段直存', () {
      const issued = OaSsoCodeIssued(
        code: 'oa_sso_x',
        redirectUri: 'https://oa.example.com/landing',
        expiresInSeconds: 60,
      );
      expect(issued.code, 'oa_sso_x');
      expect(issued.expiresInSeconds, 60);
    });
  });
}
