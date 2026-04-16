/// channel_detail_page 纯函数契约测试（CD-1 ~ CD-5）
///
/// 覆盖从 channel_detail_page.dart 提取的 5 个纯决策函数：
///   CD-1  isPaidChannelLocked   — 付费频道锁定判断
///   CD-2  shouldShowDateDivider — 消息列表日期分割线决策
///   CD-3  formatChannelNumber   — 大数字格式化（K/M）
///   CD-4  formatFileSize        — 字节数格式化（B/KB/MB/GB）
///   CD-5  formatMessageTime     — 消息相对时间格式化
library;

import 'package:flutter_test/flutter_test.dart';
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
  required ChannelType type,
  bool isSubscribed = false,
  ChannelUserRole userRole = ChannelUserRole.none,
}) => ChannelModel(
      id: 1,
      name: 'test',
      type: type,
      creatorId: 0,
      createdAt: _epoch,
      updatedAt: _epoch,
      isSubscribed: isSubscribed,
      userRole: userRole,
    );

void main() {
  // ─── CD-1  isPaidChannelLocked ────────────────────────────────────────────
  group('CD-1 isPaidChannelLocked', () {
    test('null channel → false（安全默认）', () {
      expect(isPaidChannelLocked(null), isFalse);
    });

    test('public channel, not subscribed → false', () {
      expect(isPaidChannelLocked(_channel(type: ChannelType.public)), isFalse);
    });

    test('private channel, not subscribed → false（仅 paid 才锁）', () {
      expect(isPaidChannelLocked(_channel(type: ChannelType.private)), isFalse);
    });

    test('paid channel, not subscribed, not managed → true', () {
      expect(isPaidChannelLocked(_channel(type: ChannelType.paid)), isTrue);
    });

    test('paid channel, isSubscribed=true → false（已订阅解锁）', () {
      expect(
        isPaidChannelLocked(
          _channel(type: ChannelType.paid, isSubscribed: true),
        ),
        isFalse,
      );
    });

    test('paid channel, userRole=admin (isManaged) → false（管理员解锁）', () {
      expect(
        isPaidChannelLocked(
          _channel(type: ChannelType.paid, userRole: ChannelUserRole.admin),
        ),
        isFalse,
      );
    });

    test('paid channel, userRole=creator (isManaged) → false', () {
      expect(
        isPaidChannelLocked(
          _channel(type: ChannelType.paid, userRole: ChannelUserRole.creator),
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
      expect(shouldShowDateDivider([_msgAt(day1), _msgAt(day1Later)], 1), isFalse);
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
    test('1000000 → "1.0M"', () => expect(formatChannelNumber(1000000), '1.0M'));
    test('2500000 → "2.5M"', () => expect(formatChannelNumber(2500000), '2.5M'));
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
