/// EPGZ-06 W1 — OA WebView exact-origin 策略单测（plan §7.2）
///
/// 覆盖 scheme / host / port 三元组的 allow/deny 判定矩阵：
/// 域名跳转、子域、前缀仿冒、端口差异、默认端口归一、scheme 降级、
/// 非 http(s) scheme（javascript:/file:/intent:/data:）、userinfo 伪装、
/// 畸形 URL、策略自身非法 fail-closed，及导航回调合同。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_oa/public.dart';

const allowed = 'https://oa.example.com';

void main() {
  group('normalizeOrigin', () {
    test('默认端口归一：:443 省略，非默认端口保留', () {
      expect(
        normalizeOrigin('https://oa.example.com'),
        'https://oa.example.com',
      );
      expect(
        normalizeOrigin('https://oa.example.com:443'),
        'https://oa.example.com',
      );
      expect(
        normalizeOrigin('https://oa.example.com:8443'),
        'https://oa.example.com:8443',
      );
      expect(
        normalizeOrigin('HTTP://OA.Example.COM:80'),
        'http://oa.example.com',
      );
    });

    test('path/query/fragment 剥除；userinfo 不进 origin', () {
      expect(
        normalizeOrigin('https://oa.example.com/workflow/center?x=1#f'),
        'https://oa.example.com',
      );
    });

    test('非法输入返回 null', () {
      expect(normalizeOrigin(''), isNull);
      expect(normalizeOrigin('not a url'), isNull);
      expect(normalizeOrigin('javascript:alert(1)'), isNull);
      expect(normalizeOrigin('ftp://oa.example.com'), isNull);
      expect(normalizeOrigin('https://'), isNull); // 无 host
    });
  });

  group('evaluateOrigin allow 分支', () {
    test('同 origin 任意 path/query 放行', () {
      expect(
        evaluateOrigin(allowed, 'https://oa.example.com'),
        OaOriginVerdict.allow,
      );
      expect(
        evaluateOrigin(allowed, 'https://oa.example.com/oa/login?next=/x'),
        OaOriginVerdict.allow,
      );
      expect(
        evaluateOrigin(allowed, 'HTTPS://OA.EXAMPLE.COM/sso'),
        OaOriginVerdict.allow,
      );
    });

    test('默认端口显式写出视为同 origin（:443 归一）', () {
      expect(
        evaluateOrigin(allowed, 'https://oa.example.com:443/home'),
        OaOriginVerdict.allow,
      );
    });

    test('userinfo 伪装按 host 判定（@ 前部分不是 host）', () {
      expect(
        evaluateOrigin(allowed, 'https://evil.com@oa.example.com/'),
        OaOriginVerdict.allow,
      );
      expect(
        evaluateOrigin(allowed, 'https://oa.example.com@evil.com/'),
        OaOriginVerdict.denyHostMismatch,
      );
    });
  });

  group('evaluateOrigin deny 分支 —— 域名跳转', () {
    test('完全不同 host', () {
      expect(
        evaluateOrigin(allowed, 'https://evil.com/phish'),
        OaOriginVerdict.denyHostMismatch,
      );
    });

    test('子域不算 exact（oa.example.com 的子域被拒）', () {
      expect(
        evaluateOrigin(allowed, 'https://static.oa.example.com/'),
        OaOriginVerdict.denyHostMismatch,
      );
    });

    test('前缀/后缀仿冒全部拒绝', () {
      expect(
        evaluateOrigin(allowed, 'https://oa.example.com.evil.com/'),
        OaOriginVerdict.denyHostMismatch,
      );
      expect(
        evaluateOrigin(allowed, 'https://evil-oa.example.com/'),
        OaOriginVerdict.denyHostMismatch,
      );
      expect(
        evaluateOrigin(allowed, 'https://oa-example.com/'),
        OaOriginVerdict.denyHostMismatch,
      );
    });
  });

  group('evaluateOrigin deny 分支 —— scheme 与端口', () {
    test('http 降级拒绝', () {
      expect(
        evaluateOrigin(allowed, 'http://oa.example.com/'),
        OaOriginVerdict.denySchemeMismatch,
      );
    });

    test('端口差异拒绝（含 8443/443 错位）', () {
      expect(
        evaluateOrigin(allowed, 'https://oa.example.com:8443/'),
        OaOriginVerdict.denyPortMismatch,
      );
      expect(
        evaluateOrigin(
          'https://oa.example.com:8443',
          'https://oa.example.com/',
        ),
        OaOriginVerdict.denyPortMismatch,
      );
      expect(
        evaluateOrigin(
          'https://oa.example.com:8443',
          'https://oa.example.com:8443/x',
        ),
        OaOriginVerdict.allow,
      );
    });

    test('非 http(s) scheme 拒绝（javascript/file/intent/data/ftp）', () {
      expect(
        evaluateOrigin(allowed, 'javascript:alert(document.cookie)'),
        OaOriginVerdict.denyUnsupportedScheme,
      );
      expect(
        evaluateOrigin(allowed, 'file:///data/local/tmp/secret'),
        OaOriginVerdict.denyUnsupportedScheme,
      );
      expect(
        evaluateOrigin(
          allowed,
          'intent:#Intent;action=android.intent.action.VIEW;end',
        ),
        OaOriginVerdict.denyUnsupportedScheme,
      );
      expect(
        evaluateOrigin(allowed, 'data:text/html,<script>1</script>'),
        OaOriginVerdict.denyUnsupportedScheme,
      );
      expect(
        evaluateOrigin(allowed, 'ftp://oa.example.com/'),
        OaOriginVerdict.denyUnsupportedScheme,
      );
    });

    test('畸形/空 URL 拒绝', () {
      expect(evaluateOrigin(allowed, ''), OaOriginVerdict.denyMalformedUrl);
      expect(evaluateOrigin(allowed, '   '), OaOriginVerdict.denyMalformedUrl);
      expect(
        evaluateOrigin(allowed, 'https://'),
        OaOriginVerdict.denyMalformedUrl,
      );
    });
  });

  group('策略自身非法 fail-closed', () {
    test('allowed origin 非 https → 拒绝一切（含看起来无害的 URL）', () {
      expect(
        evaluateOrigin('http://oa.example.com', 'https://oa.example.com/'),
        OaOriginVerdict.denyPolicyInvalid,
      );
      expect(
        evaluateOrigin('http://oa.example.com', 'http://oa.example.com/'),
        OaOriginVerdict.denyPolicyInvalid,
      );
    });

    test('allowed origin 畸形/为空 → 拒绝一切', () {
      expect(
        evaluateOrigin('', 'https://oa.example.com/'),
        OaOriginVerdict.denyPolicyInvalid,
      );
      expect(
        evaluateOrigin('javascript:alert(1)', 'https://oa.example.com/'),
        OaOriginVerdict.denyPolicyInvalid,
      );
    });
  });

  group('isMismatch 语义（originMismatch UI 状态触发面）', () {
    test('host/port/scheme 不一致都算 mismatch；其余 deny 不算', () {
      expect(OaOriginVerdict.denyHostMismatch.isMismatch, isTrue);
      expect(OaOriginVerdict.denyPortMismatch.isMismatch, isTrue);
      expect(OaOriginVerdict.denySchemeMismatch.isMismatch, isTrue);
      expect(OaOriginVerdict.denyUnsupportedScheme.isMismatch, isFalse);
      expect(OaOriginVerdict.denyMalformedUrl.isMismatch, isFalse);
      expect(OaOriginVerdict.denyPolicyInvalid.isMismatch, isFalse);
      expect(OaOriginVerdict.allow.isMismatch, isFalse);
    });
  });

  group('ExactOriginNavigationHandler 导航回调合同', () {
    const handler = ExactOriginNavigationHandler(allowedOrigin: allowed);

    test('allow → proceed', () {
      expect(
        handler.onNavigationRequested('https://oa.example.com/inbox'),
        OaNavigationAction.proceed,
      );
    });

    test('域名跳转 → cancelAsMismatch（宿主须置 originMismatch 状态）', () {
      expect(
        handler.onNavigationRequested('https://evil.com/'),
        OaNavigationAction.cancelAsMismatch,
      );
      expect(
        handler.onNavigationRequested('http://oa.example.com/'),
        OaNavigationAction.cancelAsMismatch,
      );
      expect(
        handler.onNavigationRequested('https://oa.example.com:8443/'),
        OaNavigationAction.cancelAsMismatch,
      );
    });

    test('危险 scheme / 畸形 URL / 非法策略 → cancel（不算 mismatch）', () {
      expect(
        handler.onNavigationRequested('javascript:alert(1)'),
        OaNavigationAction.cancel,
      );
      expect(handler.onNavigationRequested(''), OaNavigationAction.cancel);
    });

    test('策略非法时 handler 永远 cancel（fail-closed 落到回调层）', () {
      const bad = ExactOriginNavigationHandler(
        allowedOrigin: 'http://insecure.example.com',
      );
      expect(
        bad.onNavigationRequested('https://oa.example.com/'),
        OaNavigationAction.cancel,
      );
      expect(
        bad.onNavigationRequested('http://insecure.example.com/'),
        OaNavigationAction.cancel,
      );
    });
  });
}
