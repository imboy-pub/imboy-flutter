/// T2.7 — WorkspaceInviteCode 模型测试
///
/// 覆盖：fromJson 解析（后端 expires_at 为毫秒时间戳，elib_cnv 统一口径）、
/// expiresAtLabel 时间戳 → `yyyy-MM-dd HH:mm` 可读格式、非数字原样返回。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/store/model/workspace_model.dart';

void main() {
  group('WorkspaceInviteCode', () {
    test('fromJson：code 与毫秒时间戳 expires_at（string 化）', () {
      final m = WorkspaceInviteCode.fromJson(const {
        'code': 'ABCD2345',
        'expires_at': 1788778686392,
      });

      expect(m.code, 'ABCD2345');
      expect(m.expiresAt, '1788778686392');
      expect(m.isValid, isTrue);
    });

    test('expiresAtLabel：毫秒时间戳 → yyyy-MM-dd HH:mm', () {
      final m = WorkspaceInviteCode.fromJson(const {
        'code': 'ABCD2345',
        'expires_at': 1788778686392,
      });

      // 1788778686392ms = 2026-10-07（本地时区）；格式与长度做结构断言，
      // 避免时区敏感的精确值断言（UTC vs +08:00 差 8 小时）
      expect(
        m.expiresAtLabel,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')),
      );
    });

    test('expiresAtLabel：非数字/空串原样返回', () {
      const text = WorkspaceInviteCode(
        code: 'ABCD2345',
        expiresAt: '2099-01-01T00:00:00Z',
      );
      const empty = WorkspaceInviteCode();

      expect(text.expiresAtLabel, '2099-01-01T00:00:00Z');
      expect(empty.expiresAtLabel, '');
      expect(empty.isValid, isFalse);
    });
  });
}
