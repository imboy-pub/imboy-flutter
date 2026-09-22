/// GZAPP-J11 — 企业邀请码 payload 解析（parseOrgJoinCode）单元测试。
///
/// 字符集口径与后端 organization_invite_code_pg 一致：
/// 8 位 A-Z2-9（排除 0/O/1/I 手抄混淆字符），大小写不敏感。
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/organization/presentation/org_join_scanner_page.dart';

void main() {
  group('parseOrgJoinCode（GZAPP-J11 payload 契约）', () {
    test('imboy://org/join?c=CODE 解析（大小写归一）', () {
      expect(parseOrgJoinCode('imboy://org/join?c=ABCD2345'), 'ABCD2345');
      expect(parseOrgJoinCode('IMBOY://ORG/JOIN?C=abcd2345'), 'ABCD2345');
    });

    test('容忍 code= 键名', () {
      expect(parseOrgJoinCode('imboy://org/join?code=ABCD2345'), 'ABCD2345');
    });

    test('裸 8 位明码（口令被系统相机/其他扫码器识别）', () {
      expect(parseOrgJoinCode(' abcd2345 '), 'ABCD2345');
      expect(parseOrgJoinCode('ZZZZ9999'), 'ZZZZ9999');
    });

    test('排除手抄混淆字符 I/O/0/1（与后端字符集同口径）', () {
      expect(parseOrgJoinCode('AI1BCD3O'), isNull);
      expect(parseOrgJoinCode('0BCD2345'), isNull);
      expect(parseOrgJoinCode('1BCD2345'), isNull);
    });

    test('长度非 8 → null', () {
      expect(parseOrgJoinCode('ABCD234'), isNull);
      expect(parseOrgJoinCode('ABCD23456'), isNull);
    });

    test('非邀请内容 → null（群二维码/链接/任意文本）', () {
      expect(parseOrgJoinCode('https://imboy.pub/xyz'), isNull);
      expect(parseOrgJoinCode('不是邀请码的文本'), isNull);
      expect(parseOrgJoinCode(null), isNull);
      expect(parseOrgJoinCode(''), isNull);
    });

    test('imboy 前缀但码缺失/非法 → null', () {
      expect(parseOrgJoinCode('imboy://org/join'), isNull);
      expect(parseOrgJoinCode('imboy://org/join?c=ZZZ'), isNull);
      expect(parseOrgJoinCode('imboy://org/join?x=ABCD2345'), isNull);
    });
  });
}
