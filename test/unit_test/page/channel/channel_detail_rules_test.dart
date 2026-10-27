/// channel_detail_page 纯函数契约测试（CD-1 ~ CD-5）
///
/// 覆盖从 channel_detail_page.dart 提取的 5 个纯决策函数：
///   CD-1  isPaidChannelLocked   — 付费频道锁定判断
///   CD-2  shouldShowDateDivider — 消息列表日期分割线决策
///   CD-3  formatChannelNumber   — 大数字格式化（K/M）
///   CD-4  formatFileSize        — 字节数格式化（B/KB/MB/GB）
///   CD-5  formatMessageTime     — 消息相对时间格式化
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_rules.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';

// ─── 辅助：快速构造 ChannelMessageModel（仅填 createdAt）────────────────────
ChannelMessageModel _msgAt(DateTime dt) => ChannelMessageModel(
  id: 0,
  channelId: 1,
  content: '',
  msgType: 'channel_text',
  createdAt: dt,
);

final _epoch = DateTime(2025, 1, 1);

// ─── 辅助：快速构造 ChannelModel ─────────────────────────────────────────────
ChannelModel _channel({
  int visibility = 0,
  int accessType = 0,
  int? joinPolicy,
  bool isSubscribed = false,
  bool hasPurchased = false,
  ChannelUserRole userRole = ChannelUserRole.none,
}) => ChannelModel(
  id: 1,
  name: 'test',
  visibility: visibility,
  accessType: accessType,
  joinPolicy: joinPolicy ?? (accessType == 1 ? 3 : (visibility == 1 ? 1 : 0)),
  creatorId: 0,
  createdAt: _epoch,
  updatedAt: _epoch,
  isSubscribed: isSubscribed,
  hasPurchased: hasPurchased,
  userRole: userRole,
);

void main() {
  group('local calendar day boundaries', () {
    test('one minute across midnight is yesterday', () {
      expect(
        formatChannelDateDivider(
          DateTime(2026, 10, 22, 23, 59),
          t,
          now: DateTime(2026, 10, 23, 0, 0),
        ),
        t.channel.yesterday,
      );
    });
    test(
      'a future calendar date is explicit, not today or negative days ago',
      () {
        expect(
          formatChannelDateDivider(
            DateTime(2026, 10, 24),
            t,
            now: DateTime(2026, 10, 23),
          ),
          '2026-10-24',
        );
      },
    );
    test('equivalent UTC and local representations stay in one date group', () {
      for (final hour in [0, 23]) {
        final instant = DateTime(2026, 10, 23, hour, 15);
        expect(
          shouldShowDateDivider([_msgAt(instant), _msgAt(instant.toUtc())], 1),
          isFalse,
        );
      }
    });

    // R13-5：当天终点与次日开头无重漏 —— 同一时刻的两种边界表示
    // （今天 23:59:59.999 / 明天 00:00）各自落组，互不重叠。
    test(
      'R13-5 last instant of today is today, first of tomorrow yesterday',
      () {
        expect(
          formatChannelDateDivider(
            DateTime(2026, 10, 23, 23, 59, 59, 999),
            t,
            now: DateTime(2026, 10, 23, 12),
          ),
          t.channel.today,
        );
        expect(
          formatChannelDateDivider(
            DateTime(2026, 10, 23, 23, 59, 59, 999),
            t,
            now: DateTime(2026, 10, 24, 0, 0),
          ),
          t.channel.yesterday,
        );
        expect(
          formatChannelDateDivider(
            DateTime(2026, 10, 24, 0, 0),
            t,
            now: DateTime(2026, 10, 24, 0, 0),
          ),
          t.channel.today,
        );
      },
    );

    // R13-3：跨年日界按日历日计。
    test('R13-3 across new year boundary is one calendar day', () {
      expect(
        formatChannelDateDivider(
          DateTime(2026, 12, 31, 23, 59),
          t,
          now: DateTime(2027, 1, 1, 0, 1),
        ),
        t.channel.yesterday,
      );
      // 跨年 3 个日历日（非 3×24h 滚动）。
      expect(
        formatChannelDateDivider(
          DateTime(2026, 12, 30, 1),
          t,
          now: DateTime(2027, 1, 2, 1),
        ),
        contains('3'),
      );
    });

    // R13-3：闰日参与日历日差（2024 为闰年）。
    test('R13-3 leap day boundary counts as calendar days', () {
      expect(
        formatChannelDateDivider(
          DateTime(2024, 2, 29, 12),
          t,
          now: DateTime(2024, 3, 1, 12),
        ),
        t.channel.yesterday,
      );
      // 02-28 → 03-01 在闰年是 2 个日历日（经过 02-29）。
      expect(
        formatChannelDateDivider(
          DateTime(2024, 2, 28),
          t,
          now: DateTime(2024, 3, 1),
        ),
        contains('2'),
      );
      // 非闰年 2026 没有 02-29：02-28 → 03-01 恰为 1 个日历日。
      expect(
        formatChannelDateDivider(
          DateTime(2026, 2, 28, 23, 59),
          t,
          now: DateTime(2026, 3, 1, 0, 1),
        ),
        t.channel.yesterday,
      );
    });
    if (Platform.environment['TZ'] == 'America/New_York') {
      test('spring forward 23-hour previous day is yesterday', () {
        final previous = DateTime(2026, 3, 7, 12);
        final now = DateTime(2026, 3, 8, 12);
        expect(now.difference(previous).inHours, 23);
        expect(
          formatChannelDateDivider(previous, t, now: now),
          t.channel.yesterday,
        );
      });
      test('fall back 25-hour previous day is yesterday', () {
        final previous = DateTime(2026, 10, 31, 12);
        final now = DateTime(2026, 11, 1, 12);
        expect(now.difference(previous).inHours, 25);
        expect(
          formatChannelDateDivider(previous, t, now: now),
          t.channel.yesterday,
        );
      });
      test('fall back same civil day can exceed 24 hours and stays today', () {
        final previous = DateTime(2026, 11, 1, 0, 15);
        final now = DateTime(2026, 11, 1, 23, 45);
        expect(now.difference(previous).inHours, 24);
        expect(
          formatChannelDateDivider(previous, t, now: now),
          t.channel.today,
        );
      });
    }
  });

  // ─── CD-1  isPaidChannelLocked ────────────────────────────────────────────
  group('CD-1 isPaidChannelLocked', () {
    test('null channel → false（安全默认）', () {
      expect(isPaidChannelLocked(null), isFalse);
    });

    test('缺失或未支持访问策略 → 非管理员锁定（fail-closed）', () {
      expect(
        isPaidChannelLocked(
          _channel(
            visibility: ChannelModel.unknownAccessPolicy,
            accessType: ChannelModel.unknownAccessPolicy,
            joinPolicy: ChannelModel.unknownAccessPolicy,
          ),
        ),
        isTrue,
      );
      expect(
        isPaidChannelLocked(
          _channel(visibility: 0, accessType: 1, joinPolicy: 0),
        ),
        isTrue,
      );
    });

    test('public channel, not subscribed → false', () {
      expect(isPaidChannelLocked(_channel(accessType: 0)), isFalse);
    });

    test('private channel, not subscribed → false（仅 paid 才锁）', () {
      expect(
        isPaidChannelLocked(_channel(visibility: 1, accessType: 0)),
        isFalse,
      );
    });

    test('paid channel, not subscribed, not managed → true', () {
      expect(isPaidChannelLocked(_channel(accessType: 1)), isTrue);
    });

    test('paid channel, only isSubscribed=true → true（订阅不能替代购买）', () {
      expect(
        isPaidChannelLocked(_channel(accessType: 1, isSubscribed: true)),
        isTrue,
      );
    });

    test('paid channel, hasPurchased=true → false（已购买解锁）', () {
      expect(
        isPaidChannelLocked(_channel(accessType: 1, hasPurchased: true)),
        isFalse,
      );
    });

    test('paid channel, userRole=admin (isManaged) → false（管理员解锁）', () {
      expect(
        isPaidChannelLocked(
          _channel(accessType: 1, userRole: ChannelUserRole.admin),
        ),
        isFalse,
      );
    });

    test('paid channel, userRole=creator (isManaged) → false', () {
      expect(
        isPaidChannelLocked(
          _channel(accessType: 1, userRole: ChannelUserRole.creator),
        ),
        isFalse,
      );
    });
  });

  // ─── CD-1b hasChannelContentAccess ───────────────────────────────────────
  group('CD-1b hasChannelContentAccess', () {
    test('null channel → false', () {
      expect(hasChannelContentAccess(null), isFalse);
    });

    test('public channel keeps visitor CTA until followed', () {
      expect(hasChannelContentAccess(_channel(accessType: 0)), isFalse);
      expect(
        hasChannelContentAccess(_channel(accessType: 0, isSubscribed: true)),
        isTrue,
      );
    });

    test('private channel requires subscription', () {
      expect(
        hasChannelContentAccess(_channel(visibility: 1, accessType: 0)),
        isFalse,
      );
      expect(
        hasChannelContentAccess(
          _channel(visibility: 1, accessType: 0, isSubscribed: true),
        ),
        isTrue,
      );
    });

    test('paid channel requires purchase even when subscribed', () {
      expect(
        hasChannelContentAccess(_channel(accessType: 1, isSubscribed: true)),
        isFalse,
      );
      expect(
        hasChannelContentAccess(_channel(accessType: 1, hasPurchased: true)),
        isTrue,
      );
    });

    test('managed channel is handled by the editor empty state', () {
      expect(
        hasChannelContentAccess(
          _channel(accessType: 1, userRole: ChannelUserRole.admin),
        ),
        isFalse,
      );
    });
  });

  // ─── CD-2  shouldShowDateDivider ──────────────────────────────────────────
  group('CD-2 shouldShowDateDivider', () {
    final day1 = DateTime(2025, 1, 1, 10, 0);
    final day1Later = DateTime(2025, 1, 1, 22, 30);
    final day2 = DateTime(2025, 1, 2, 8, 0);

    test('index == 0 → 始终显示', () {
      expect(shouldShowDateDivider([_msgAt(day1)], 0), isTrue);
    });

    test('相同日期的相邻消息 → 不显示', () {
      expect(
        shouldShowDateDivider([_msgAt(day1), _msgAt(day1Later)], 1),
        isFalse,
      );
    });

    test('跨天的相邻消息 → 显示', () {
      expect(shouldShowDateDivider([_msgAt(day1), _msgAt(day2)], 1), isTrue);
    });

    test('跨多天中间某条 → 正确判断与前一条的差异', () {
      final msgs = [
        _msgAt(DateTime(2025, 1, 1)),
        _msgAt(DateTime(2025, 1, 1)),
        _msgAt(DateTime(2025, 1, 3)),
      ];
      expect(shouldShowDateDivider(msgs, 1), isFalse); // 同天
      expect(shouldShowDateDivider(msgs, 2), isTrue); // 跨天
    });

    test('单条消息列表 index=0 → 显示', () {
      expect(shouldShowDateDivider([_msgAt(day1)], 0), isTrue);
    });
  });

  // ─── CD-3  formatChannelNumber ────────────────────────────────────────────
  group('CD-3 formatChannelNumber', () {
    test('0 → "0"', () => expect(formatChannelNumber(0), '0'));
    test('999 → "999"（不到 1K）', () => expect(formatChannelNumber(999), '999'));
    test('1000 → "1.0K"', () => expect(formatChannelNumber(1000), '1.0K'));
    test('1500 → "1.5K"', () => expect(formatChannelNumber(1500), '1.5K'));
    test('999999 → "1000.0K"（K 区间上限）', () {
      expect(formatChannelNumber(999999), '1000.0K');
    });
    test(
      '1000000 → "1.0M"',
      () => expect(formatChannelNumber(1000000), '1.0M'),
    );
    test(
      '2500000 → "2.5M"',
      () => expect(formatChannelNumber(2500000), '2.5M'),
    );
  });

  // ─── CD-4  formatFileSize ─────────────────────────────────────────────────
  group('CD-4 formatFileSize', () {
    test('0 → "0 B"', () => expect(formatFileSize(0), '0 B'));
    test('1023 → "1023 B"', () => expect(formatFileSize(1023), '1023 B'));
    test('1024 → "1.0 KB"', () => expect(formatFileSize(1024), '1.0 KB'));
    test('1536 → "1.5 KB"', () => expect(formatFileSize(1536), '1.5 KB'));
    test('1048575 → stays in KB range', () {
      final s = formatFileSize(1048575);
      expect(s.endsWith('KB'), isTrue);
    });
    test('1048576 (1 MB) → "1.0 MB"', () {
      expect(formatFileSize(1048576), '1.0 MB');
    });
    test('1073741823 (just under 1 GB) → ends with MB', () {
      final s = formatFileSize(1073741823);
      expect(s.endsWith('MB'), isTrue);
    });
    test('1073741824 (1 GB) → "1.0 GB"', () {
      expect(formatFileSize(1073741824), '1.0 GB');
    });
  });

  // ─── CD-5  formatMessageTime ─────────────────────────────────────────────
  group('CD-5 formatMessageTime', () {
    // 以固定 now 作为参考，避免真实时钟干扰
    final now = DateTime(2025, 6, 15, 12, 0, 0);

    test('30 分钟前 → "30m ago"', () {
      final time = now.subtract(const Duration(minutes: 30));
      expect(formatMessageTime(time, now: now), '30m ago');
    });

    test('59 分钟前 → "59m ago"（< 60 分钟边界）', () {
      final time = now.subtract(const Duration(minutes: 59));
      expect(formatMessageTime(time, now: now), '59m ago');
    });

    test('60 分钟前 → 进入小时分支（>= 60 分钟）', () {
      final time = now.subtract(const Duration(minutes: 60));
      expect(formatMessageTime(time, now: now), '1h ago');
    });

    test('3 小时前 → "3h ago"', () {
      final time = now.subtract(const Duration(hours: 3));
      expect(formatMessageTime(time, now: now), '3h ago');
    });

    test('23 小时前 → "23h ago"（< 24 小时边界）', () {
      final time = now.subtract(const Duration(hours: 23));
      expect(formatMessageTime(time, now: now), '23h ago');
    });

    test('24 小时前 → 进入天分支（>= 24 小时）', () {
      final time = now.subtract(const Duration(hours: 24));
      expect(formatMessageTime(time, now: now), '1d ago');
    });

    test('6 天前 → "6d ago"（< 7 天边界）', () {
      final time = now.subtract(const Duration(days: 6));
      expect(formatMessageTime(time, now: now), '6d ago');
    });

    test('7 天前 → 进入日期格式（>= 7 天）', () {
      final time = now.subtract(const Duration(days: 7));
      final result = formatMessageTime(time, now: now);
      // 2025-06-08 12:00 → "06-08 12:00"
      expect(result, '06-08 12:00');
    });

    test('30 天前 → 日期格式（MM-dd HH:mm）', () {
      final time = now.subtract(const Duration(days: 30));
      final result = formatMessageTime(time, now: now);
      expect(result, '05-16 12:00');
    });

    test('0 分钟前（刚发送）→ "0m ago"', () {
      expect(formatMessageTime(now, now: now), '0m ago');
    });
  });
}
