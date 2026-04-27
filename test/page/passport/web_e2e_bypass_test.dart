/// Step 2 RED — Web E2E 测试旁路决策纯函数
///
/// 决策语义：
/// - token 或 uid 为空 → BypassDisabled（走原 QR 流程）
/// - 两者都非空 → BypassEnabled（直接注入登录态）
/// - 不在测试 hook 内做副作用（saveToken / context.go），只决策
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/web_e2e_bypass.dart';

void main() {
  group('parseE2eBypassConfig — 禁用分支', () {
    test('token + uid 都为空 → BypassDisabled', () {
      final config = parseE2eBypassConfig(token: '', uid: '');
      expect(config, isA<BypassDisabled>());
    });

    test('仅 token 为空 → BypassDisabled', () {
      final config = parseE2eBypassConfig(token: '', uid: 'u-001');
      expect(config, isA<BypassDisabled>());
    });

    test('仅 uid 为空 → BypassDisabled', () {
      final config = parseE2eBypassConfig(token: 'tok-xxx', uid: '');
      expect(config, isA<BypassDisabled>());
    });
  });

  group('parseE2eBypassConfig — 启用分支', () {
    test('token + uid 都非空 → BypassEnabled', () {
      final config = parseE2eBypassConfig(token: 'tok-xxx', uid: 'u-001');
      expect(config, isA<BypassEnabled>());
      config as BypassEnabled;
      expect(config.token, 'tok-xxx');
      expect(config.uid, 'u-001');
    });

    test('token 含特殊字符（JWT base64）也透传', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOiIxMjMifQ.signature-x_y-z';
      final config = parseE2eBypassConfig(token: jwt, uid: 'u-002');
      expect((config as BypassEnabled).token, jwt);
    });
  });

  group('安全约束', () {
    test('token=" "（仅空格）应视为空，归 BypassDisabled', () {
      final config = parseE2eBypassConfig(token: '   ', uid: 'u-003');
      expect(config, isA<BypassDisabled>(),
          reason: '空白字符不应被当作合法 token，避免误开旁路');
    });

    test('uid=" "（仅空格）应视为空，归 BypassDisabled', () {
      final config = parseE2eBypassConfig(token: 'tok', uid: '   ');
      expect(config, isA<BypassDisabled>());
    });
  });

  group('sealed exhaustiveness', () {
    test('switch 必须穷尽两个变体', () {
      String describe(WebE2eBypassConfig c) {
        return switch (c) {
          BypassDisabled() => 'off',
          BypassEnabled() => 'on',
        };
      }

      expect(describe(parseE2eBypassConfig(token: '', uid: '')), 'off');
      expect(describe(parseE2eBypassConfig(token: 't', uid: 'u')), 'on');
    });
  });

  group('== / hashCode', () {
    test('BypassEnabled 同字段相等', () {
      const a = BypassEnabled(token: 't', uid: 'u');
      const b = BypassEnabled(token: 't', uid: 'u');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('BypassEnabled token 不同则不等', () {
      const a = BypassEnabled(token: 't1', uid: 'u');
      const b = BypassEnabled(token: 't2', uid: 'u');
      expect(a, isNot(b));
    });

    test('BypassDisabled 单例语义', () {
      const a = BypassDisabled();
      const b = BypassDisabled();
      expect(a, b);
    });
  });
}
