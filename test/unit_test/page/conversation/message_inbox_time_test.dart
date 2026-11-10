import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/message_inbox_time.dart';

void main() {
  group('formatMessageInboxTime', () {
    test('missing timestamps stay empty', () {
      expect(formatMessageInboxTime(0), isEmpty);
      expect(formatMessageInboxTime(-1), isEmpty);
    });

    test('today uses a zero-padded local clock', () {
      expect(
        formatMessageInboxTime(
          DateTime(2026, 11, 9, 6, 3).millisecondsSinceEpoch,
          now: DateTime(2026, 11, 9, 23, 58),
        ),
        '06:03',
      );
    });

    test(
      'yesterday follows the calendar even when only minutes have passed',
      () {
        expect(
          formatMessageInboxTime(
            DateTime(2026, 11, 8, 23, 55).millisecondsSinceEpoch,
            now: DateTime(2026, 11, 9, 0, 5),
            yesterdayLabel: '昨日',
          ),
          '昨日',
        );
      },
    );

    test('yesterday still applies after more than 24 elapsed hours', () {
      expect(
        formatMessageInboxTime(
          DateTime(2026, 11, 8, 0, 5).millisecondsSinceEpoch,
          now: DateTime(2026, 11, 9, 23, 55),
        ),
        t.common.yesterday,
      );
    });

    test('yesterday takes priority at a year boundary', () {
      expect(
        formatMessageInboxTime(
          DateTime(2025, 12, 31, 23, 55).millisecondsSinceEpoch,
          now: DateTime(2026, 1, 1, 0, 5),
          yesterdayLabel: 'Yesterday',
        ),
        'Yesterday',
      );
    });

    test('leap-day yesterday uses the real calendar', () {
      expect(
        formatMessageInboxTime(
          DateTime(2024, 2, 29, 8).millisecondsSinceEpoch,
          now: DateTime(2024, 3, 1, 22),
          yesterdayLabel: 'Yesterday',
        ),
        'Yesterday',
      );
    });

    test('older messages omit the year only within the current year', () {
      final now = DateTime(2026, 11, 9);
      expect(
        formatMessageInboxTime(
          DateTime(2026, 10, 28).millisecondsSinceEpoch,
          now: now,
        ),
        '10/28',
      );
      expect(
        formatMessageInboxTime(
          DateTime(2025, 10, 28).millisecondsSinceEpoch,
          now: now,
        ),
        '2025/10/28',
      );
    });

    test('an injected UTC clock is normalized to the local calendar', () {
      final local = DateTime(2026, 11, 9, 0, 5);
      expect(
        formatMessageInboxTime(
          local.millisecondsSinceEpoch,
          now: local.toUtc(),
        ),
        '00:05',
      );
    });
  });
}
