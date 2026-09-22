/// FULL-05 — 受限游标目录测试（能力项 3 / INT-16、INT-17）。
///
/// 本文件的重点是硬边界「**UI 侧不得提供全量导出入口**」的**机械证据**：
/// 1. 分页上限：超上限/非法页大小一律**拒绝**（不是截断）；
/// 2. 全量导出负例：以源码扫描断言 `lib/modules/enterprise_app/` 内不存在
///    导出/全量形态的入口（命名黑名单 + 公开取数入口冻结表）；
/// 3. 展示层（`EnterpriseDirectoryPage`）只有「一页 + 加载更多」两个动作，
///    没有任何导出回调可注入。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_app/public.dart';

void main() {
  group('页大小校验：超限拒绝而非截断', () {
    test('缺省 → 50', () {
      expect(validateDirectoryPageSize(null).pageSize, 50);
      expect(kDirectoryDefaultPageSize, 50);
    });

    test('边界值 1 与 100 合法', () {
      expect(validateDirectoryPageSize(1).isValid, isTrue);
      expect(validateDirectoryPageSize(100).isValid, isTrue);
      expect(kDirectoryMaxPageSize, 100);
    });

    test('超上限拒绝（101 / 1000 / 100000）', () {
      for (final int size in <int>[101, 1000, 100000]) {
        final DirectoryQueryValidation v = validateDirectoryPageSize(size);
        expect(v.isValid, isFalse, reason: '$size');
        expect(v.reason, 'page_size_over_cap');
      }
    });

    test('0 / 负数 / 非整数拒绝', () {
      expect(validateDirectoryPageSize(0).reason, 'page_size_below_min');
      expect(validateDirectoryPageSize(-1).reason, 'page_size_below_min');
      expect(validateDirectoryPageSize('abc').reason, 'page_size_not_integer');
    });

    test('数字字符串按数字处理（JSON 宽松解析）', () {
      expect(validateDirectoryPageSize('30').pageSize, 30);
    });
  });

  group('页响应解析', () {
    test('mappings 项恰为 2 键（不夹带 PII）', () {
      final EnterpriseDirectoryResult<DirectoryMappingItem> page =
          parseMappingsPage(<String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'external_user_id': 'ext-1',
                'user_id': 1001,
                'nickname': '不应出现',
              },
            ],
            'page_size': 50,
            'has_more': false,
            'next_cursor': '',
          });
      expect(page.family, EnterpriseDirectoryFamily.mappings);
      expect(page.items.length, 1);
      expect(page.items.first.rawFields.keys.toSet(), <String>{
        'external_user_id',
        'user_id',
      });
      expect(page.items.first.userId, '1001');
      expect(page.isEnd, isTrue);
    });

    test('users 项恰为 4 键', () {
      final EnterpriseDirectoryResult<DirectoryMemberItem> page =
          parseUsersPage(<String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'user_id': 1001,
                'external_user_id': 'ext-1',
                'member_role': 1,
                'member_status': 1,
                'phone': '不应出现',
              },
            ],
            'page_size': 20,
            'has_more': true,
            'next_cursor': 'Y3Vyc29yOjE',
          });
      expect(page.family, EnterpriseDirectoryFamily.users);
      expect(page.items.first.rawFields.keys.toSet(), <String>{
        'user_id',
        'external_user_id',
        'member_role',
        'member_status',
      });
      expect(page.isEnd, isFalse);
      expect(page.nextCursor, 'Y3Vyc29yOjE');
    });

    test('has_more 为真但缺游标 → 视为末页（不无限请求）', () {
      final EnterpriseDirectoryResult<DirectoryMappingItem> page =
          parseMappingsPage(<String, dynamic>{
            'items': <dynamic>[],
            'has_more': true,
            'next_cursor': '',
          });
      expect(page.isEnd, isTrue);
      expect(page.isEmpty, isTrue);
    });

    test('items 非法/缺失 → 空列表且不抛', () {
      expect(parseUsersPage(<String, dynamic>{}).items, isEmpty);
      expect(parseUsersPage(<String, dynamic>{'items': 'oops'}).items, isEmpty);
    });
  });

  group('路径与页族（与 manifest INT-16/17 逐字对齐）', () {
    test('页族标签', () {
      expect(EnterpriseDirectoryFamily.mappings.tag, 'mappings');
      expect(EnterpriseDirectoryFamily.users.tag, 'users');
    });

    test('路径拼接', () {
      expect(
        directoryPathFor(EnterpriseDirectoryFamily.mappings),
        '/api/internal/v1/identity-mappings/directory',
      );
      expect(
        directoryPathFor(EnterpriseDirectoryFamily.users),
        '/api/internal/v1/directory/users',
      );
    });
  });

  group('无全量导出入口（机械证据）', () {
    /// 模块源码目录（以测试文件位置反推仓库根，避免硬编码绝对路径）。
    Directory moduleDir() {
      final Directory cwd = Directory.current;
      return Directory('${cwd.path}/lib/modules/enterprise_app');
    }

    test('公开分页取数入口被冻结为恰好两个', () {
      expect(kDirectoryClientPagedReadMethods, <String>[
        'directoryMappingsPage',
        'directoryUsersPage',
      ]);
    });

    test('模块源码里不存在导出/全量形态的入口（命名黑名单零命中）', () {
      final List<String> hits = <String>[];
      for (final FileSystemEntity e in moduleDir().listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final String src = e.readAsStringSync();
        for (final RegExpMatch m in kDirectoryForbiddenEntryPattern.allMatches(
          src,
        )) {
          // 允许黑名单词出现在文档注释里（说明「不得提供导出入口」的那几句），
          // 但不得构成一次调用/声明。
          hits.add('${e.path}: ${m.group(0)}');
        }
      }
      expect(hits, isEmpty, reason: '目录能力不得露出任何导出/全量形态入口：$hits');
    });

    test('目录页 widget 的公开成员里没有导出回调可注入', () {
      final File page = File(
        '${Directory.current.path}'
        '/lib/modules/enterprise_app/presentation/enterprise_directory_page.dart',
      );
      final String src = page.readAsStringSync();
      // 构造参数里不得出现任何 export/download/bulk 形态的可注入回调。
      final RegExp ctor = RegExp(
        r'const EnterpriseDirectoryPage\(\{(.*?)\}\)',
        dotAll: true,
      );
      final RegExpMatch? m = ctor.firstMatch(src);
      expect(m, isNotNull, reason: '构造函数必须存在（否则本断言失效）');
      expect(
        kDirectoryForbiddenEntryPattern.hasMatch(m!.group(1) ?? ''),
        isFalse,
        reason: '目录页不得提供导出回调',
      );
    });

    test('目录页只调用一个分页取数方法', () {
      final String src = File(
        '${Directory.current.path}'
        '/lib/modules/enterprise_app/presentation/enterprise_directory_page.dart',
      ).readAsStringSync();
      for (final String method in kDirectoryClientPagedReadMethods) {
        if (method == 'directoryUsersPage') {
          expect(src.contains(method), isTrue, reason: '应调用分页入口');
        }
      }
      // 不得出现「取全部」形态：`while (... hasMore ...)` 之外的全量循环。
      expect(RegExp(r'\bwhile\s*\(').hasMatch(src), isFalse);
    });
  });
}
