/// 钉住 `AnnouncementModel` 与 parse 辅助的解析契约 —— F3 RED。
///
/// 用例覆盖：
///   - 字段别名融合（id/notice_id、publisher_id/user_id、content/body、
///     publisher_name/creator_name）
///   - 数值类型容错：int / String 数字 / String ISO-8601 / null
///   - 时间戳单位自动放大（秒 → 毫秒）
///   - 缺失 publisher_name 回退到 publisher_id
///   - buildNoticeTitle 三段规则（空 / ≤20 / >20）
///   - toRfc3339 UTC 规范化
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/announcement/announcement_model.dart';

void main() {
  group('parseAnnouncementTimestamp', () {
    test('null → 0', () {
      expect(parseAnnouncementTimestamp(null), 0);
    });

    test('int 毫秒级（> 1e12）原样返回', () {
      expect(parseAnnouncementTimestamp(1_700_000_000_000), 1_700_000_000_000);
    });

    test('int 秒级（> 1e9 且 ≤ 1e12）→ ×1000', () {
      expect(parseAnnouncementTimestamp(1_700_000_000), 1_700_000_000_000);
    });

    test('int 小值（≤ 1e9）原样返回（视为相对时间戳或测试值）', () {
      expect(parseAnnouncementTimestamp(42), 42);
    });

    test('数字字符串 → 等同整数路径', () {
      expect(parseAnnouncementTimestamp('1700000000'), 1_700_000_000_000);
      expect(parseAnnouncementTimestamp('1700000000000'), 1_700_000_000_000);
    });

    test('ISO-8601 字符串 → millisecondsSinceEpoch', () {
      final expected = DateTime.utc(2026, 4, 15).millisecondsSinceEpoch;
      expect(parseAnnouncementTimestamp('2026-04-15T00:00:00Z'), expected);
    });

    test('无法解析 → 0', () {
      expect(parseAnnouncementTimestamp('not-a-date'), 0);
      expect(parseAnnouncementTimestamp(const Object()), 0);
    });
  });

  group('parseOptionalAnnouncementTimestamp', () {
    test('null → null', () {
      expect(parseOptionalAnnouncementTimestamp(null), isNull);
    });

    test('有效时间戳 → 非空', () {
      expect(
        parseOptionalAnnouncementTimestamp(1_700_000_000_000),
        1_700_000_000_000,
      );
    });

    test('无法解析 / 0 → null', () {
      expect(parseOptionalAnnouncementTimestamp('garbage'), isNull);
      expect(parseOptionalAnnouncementTimestamp(0), isNull);
    });
  });

  group('buildNoticeTitle', () {
    test('空内容 → 默认 "群公告"', () {
      expect(buildNoticeTitle(''), '群公告');
      expect(buildNoticeTitle('   '), '群公告');
      expect(buildNoticeTitle('\n\n'), '群公告');
    });

    test('首行 ≤ 20 字符 → 原样', () {
      expect(buildNoticeTitle('hello world'), 'hello world');
      expect(buildNoticeTitle('第一行\n第二行'), '第一行');
    });

    test('首行 > 20 字符 → 截取前 20 + "..."', () {
      final longLine = 'x' * 25;
      expect(buildNoticeTitle(longLine), '${'x' * 20}...');
    });

    test('首行有前后空白 → trim 后计算长度', () {
      expect(buildNoticeTitle('   hello   '), 'hello');
    });
  });

  group('toRfc3339', () {
    test('输出以 Z 结尾的 UTC 串', () {
      final result = toRfc3339(1_700_000_000_000);
      expect(result.endsWith('Z'), isTrue);
      // 不硬编码本地时区，但必须可被 DateTime.parse 解析回相同值
      expect(DateTime.parse(result).millisecondsSinceEpoch, 1_700_000_000_000);
    });
  });

  group('AnnouncementModel.fromJson — 字段别名', () {
    test('id 优先，fallback notice_id', () {
      expect(
        AnnouncementModel.fromJson({'id': 'a1'}).id,
        'a1',
      );
      expect(
        AnnouncementModel.fromJson({'notice_id': 'n1'}).id,
        'n1',
      );
      expect(
        AnnouncementModel.fromJson({'id': 'a1', 'notice_id': 'n1'}).id,
        'a1',
      );
    });

    test('publisher_id 优先，fallback user_id', () {
      expect(
        AnnouncementModel.fromJson({'publisher_id': 'p1'}).publisherId,
        'p1',
      );
      expect(
        AnnouncementModel.fromJson({'user_id': 'u1'}).publisherId,
        'u1',
      );
    });

    test('content 优先，fallback body', () {
      expect(
        AnnouncementModel.fromJson({'content': 'C'}).content,
        'C',
      );
      expect(
        AnnouncementModel.fromJson({'body': 'B'}).content,
        'B',
      );
    });

    test('publisher_name 优先，fallback creator_name', () {
      expect(
        AnnouncementModel.fromJson({'publisher_name': 'N'}).publisherName,
        'N',
      );
      expect(
        AnnouncementModel.fromJson({'creator_name': 'C'}).publisherName,
        'C',
      );
    });
  });

  group('AnnouncementModel.fromJson — 默认值与降级', () {
    test('空 map → 全默认不抛异常', () {
      final m = AnnouncementModel.fromJson({});
      expect(m.id, '');
      expect(m.groupId, '');
      expect(m.content, '');
      expect(m.publisherId, '');
      expect(m.publisherName, '');
      expect(m.createdAt, 0);
      expect(m.expiredAt, isNull);
    });

    test('publisher_name 缺失 → 回退到 publisher_id', () {
      final m = AnnouncementModel.fromJson({'publisher_id': 'uid-42'});
      expect(m.publisherName, 'uid-42');
    });

    test('publisher_name 空字符串 → 同样回退到 publisher_id', () {
      final m = AnnouncementModel.fromJson({
        'publisher_id': 'uid-42',
        'publisher_name': '',
      });
      expect(m.publisherName, 'uid-42');
    });

    test('数值 id / group_id 自动 toString', () {
      final m = AnnouncementModel.fromJson({
        'id': 123,
        'group_id': 456,
      });
      expect(m.id, '123');
      expect(m.groupId, '456');
    });

    test('expired_at 为 0 → 解析为 null（避免"永不过期"被误读为立即过期）', () {
      final m = AnnouncementModel.fromJson({'expired_at': 0});
      expect(m.expiredAt, isNull);
    });
  });

  group('AnnouncementModel — toJson', () {
    test('toJson 包含所有字段且可重建', () {
      const original = AnnouncementModel(
        id: 'a1',
        groupId: 'g1',
        content: 'hello',
        publisherId: 'u1',
        publisherName: 'Alice',
        createdAt: 1_700_000_000_000,
        expiredAt: 1_800_000_000_000,
      );
      final json = original.toJson();
      expect(json['id'], 'a1');
      expect(json['group_id'], 'g1');
      expect(json['content'], 'hello');
      expect(json['publisher_id'], 'u1');
      expect(json['publisher_name'], 'Alice');
      expect(json['created_at'], 1_700_000_000_000);
      expect(json['expired_at'], 1_800_000_000_000);
    });
  });
}
