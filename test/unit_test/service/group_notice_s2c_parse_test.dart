/// 钉住 S2C `group_notice_published` payload 的纯函数解析契约 —— W1.1 RED。
///
/// 后端合约（`imboy/src/logic/group_notice_logic:publish_notice/3` 将广播）：
///   Payload = #{
///     <<"gid">>                => Gid,               % int
///     <<"notice_id">>          => NoticeId,          % int
///     <<"publisher_id">>       => Uid,               % int
///     <<"publisher_nickname">> => <<"Alice">>,       % binary
///     <<"title">>              => <<"新公告">>,       % binary
///     <<"body">>               => <<"...">>,          % binary
///     <<"expired_at">>         => ExpiredAtMs,       % int ms or 0
///     <<"published_at">>       => Now                % int ms
///   }
///
/// 契约：
///   1. `gid` 必需：int 或可转 int 的 String，<= 0 或缺失 → `invalid_gid`
///   2. `notice_id` 必需：同上，<= 0 或缺失 → `invalid_notice_id`
///   3. `publisher_id` 必需，同上 → `invalid_publisher_id`
///   4. 文本字段（title / body / publisher_nickname）缺失 → 默认空串
///   5. `expired_at` / `published_at`：int / 数字 String → 毫秒；非法 → 0
///   6. `expired_at == 0` → null（永不过期语义，与 announcement_model 对齐）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_notice_s2c.dart';

void main() {
  group('parseGroupNoticePublishedPayload — 必需字段校验', () {
    test('全字段合法 → success', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 100,
        'notice_id': 999,
        'publisher_id': 7,
        'publisher_nickname': 'Alice',
        'title': '新公告',
        'body': '放假通知',
        'expired_at': 1768957192053,
        'published_at': 1768957192000,
      });
      expect(r, isA<GroupNoticePublishedPayload>());
      final p = r as GroupNoticePublishedPayload;
      expect(p.gid, 100);
      expect(p.noticeId, 999);
      expect(p.publisherId, 7);
      expect(p.publisherNickname, 'Alice');
      expect(p.title, '新公告');
      expect(p.body, '放假通知');
      expect(p.expiredAt, 1768957192053);
      expect(p.publishedAt, 1768957192000);
    });

    test('gid 为数字 String → 正确强转', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': '123',
        'notice_id': '456',
        'publisher_id': '7',
      });
      expect(r, isA<GroupNoticePublishedPayload>());
      final p = r as GroupNoticePublishedPayload;
      expect(p.gid, 123);
      expect(p.noticeId, 456);
      expect(p.publisherId, 7);
    });

    test('gid 缺失 → invalid_gid', () {
      final r = parseGroupNoticePublishedPayload({
        'notice_id': 1,
        'publisher_id': 7,
      });
      expect(r, isA<GroupNoticeParseError>());
      expect((r as GroupNoticeParseError).reason, 'invalid_gid');
    });

    test('gid <= 0 → invalid_gid', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 0,
        'notice_id': 1,
        'publisher_id': 7,
      });
      expect(r, isA<GroupNoticeParseError>());
      expect((r as GroupNoticeParseError).reason, 'invalid_gid');
    });

    test('notice_id 缺失 → invalid_notice_id', () {
      final r = parseGroupNoticePublishedPayload({'gid': 1, 'publisher_id': 7});
      expect(r, isA<GroupNoticeParseError>());
      expect((r as GroupNoticeParseError).reason, 'invalid_notice_id');
    });

    test('notice_id <= 0 → invalid_notice_id', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 0,
        'publisher_id': 7,
      });
      expect((r as GroupNoticeParseError).reason, 'invalid_notice_id');
    });

    test('publisher_id 缺失 → invalid_publisher_id', () {
      final r = parseGroupNoticePublishedPayload({'gid': 1, 'notice_id': 2});
      expect((r as GroupNoticeParseError).reason, 'invalid_publisher_id');
    });

    test('publisher_id <= 0 → invalid_publisher_id', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 0,
      });
      expect((r as GroupNoticeParseError).reason, 'invalid_publisher_id');
    });
  });

  group('parseGroupNoticePublishedPayload — 文本字段默认值', () {
    test('缺 title/body/nickname → 均为空串', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 3,
      });
      final p = r as GroupNoticePublishedPayload;
      expect(p.title, '');
      expect(p.body, '');
      expect(p.publisherNickname, '');
    });

    test('title/body 为 null → 空串', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 3,
        'title': null,
        'body': null,
      });
      final p = r as GroupNoticePublishedPayload;
      expect(p.title, '');
      expect(p.body, '');
    });

    test('title/body 为数字 → toString', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 3,
        'title': 42,
      });
      final p = r as GroupNoticePublishedPayload;
      expect(p.title, '42');
    });
  });

  group('parseGroupNoticePublishedPayload — 时间戳处理', () {
    test('expired_at=0 → null（永不过期语义）', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 3,
        'expired_at': 0,
      });
      final p = r as GroupNoticePublishedPayload;
      expect(p.expiredAt, isNull);
    });

    test('expired_at 缺失 → null', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 3,
      });
      final p = r as GroupNoticePublishedPayload;
      expect(p.expiredAt, isNull);
    });

    test('published_at 缺失 → 0（非 null，时间轴类字段用 0 标记"未知"）', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 3,
      });
      final p = r as GroupNoticePublishedPayload;
      expect(p.publishedAt, 0);
    });

    test('published_at 为数字 String → 正确强转', () {
      final r = parseGroupNoticePublishedPayload({
        'gid': 1,
        'notice_id': 2,
        'publisher_id': 3,
        'published_at': '1700000000000',
      });
      final p = r as GroupNoticePublishedPayload;
      expect(p.publishedAt, 1700000000000);
    });
  });

  group('parseGroupNoticePublishedPayload — sealed 穷尽', () {
    test('switch 必须覆盖 Payload 和 Error', () {
      final results = <GroupNoticeParseResult>[
        parseGroupNoticePublishedPayload({
          'gid': 1,
          'notice_id': 2,
          'publisher_id': 3,
        }),
        parseGroupNoticePublishedPayload({}),
      ];
      for (final r in results) {
        final label = switch (r) {
          GroupNoticePublishedPayload(:final gid) => 'ok:$gid',
          GroupNoticeParseError(:final reason) => 'err:$reason',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
