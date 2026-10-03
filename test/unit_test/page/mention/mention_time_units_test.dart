import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mention/mention_list_page.dart';
import 'package:imboy/service/mention_service.dart';
import 'package:imboy/store/api/mention_api.dart';

class _Service extends MentionService {
  _Service(this.timestamp) : super.withApi(MentionApi());
  final Object? timestamp;
  @override
  Future<int> getUnreadCount({String? groupId}) async => 0;
  @override
  Future<Map<String, dynamic>?> getMentions({
    int page = 1,
    int size = 20,
    int? isRead,
    String? groupId,
  }) async => {
    'items': [
      {
        'id': 1,
        'nickname': 'Synthetic',
        'content': 'Synthetic mention',
        'is_read': 1,
        'created_at': timestamp,
      },
    ],
  };
}

Future<void> _expectTime(
  WidgetTester tester,
  Object? value,
  String expected,
) async {
  MentionService.instanceForTest = _Service(value);
  addTearDown(() => MentionService.instanceForTest = null);
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: const MaterialApp(home: MentionListPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  final tile = tester.widget<ImBoyListTile>(find.byType(ImBoyListTile));
  expect((tile.trailing as Text).data, expected);
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  for (final encoding in [
    'seconds-int',
    'seconds-string',
    'millis-int',
    'millis-string',
  ]) {
    for (final age in ['now', 'minutes', 'hours', 'days', 'date']) {
      testWidgets('mention time $encoding $age', (tester) async {
        final duration = switch (age) {
          'minutes' => const Duration(minutes: 5, seconds: 30),
          'hours' => const Duration(hours: 2, seconds: 30),
          'days' => const Duration(days: 2, seconds: 30),
          'date' => const Duration(days: 8, seconds: 30),
          _ => const Duration(seconds: 30),
        };
        final instant = DateTime.now().subtract(duration);
        final numeric = encoding.startsWith('seconds')
            ? instant.millisecondsSinceEpoch ~/ 1000
            : instant.millisecondsSinceEpoch;
        final expected = switch (age) {
          'minutes' => t.common.timeMinutesShort(count: 5),
          'hours' => t.common.timeHoursShort(count: 2),
          'days' => t.common.timeDaysShort(count: 2),
          'date' => '${instant.month}/${instant.day}',
          _ => t.common.timeNowShort,
        };
        await _expectTime(
          tester,
          encoding.endsWith('string') ? '$numeric' : numeric,
          expected,
        );
      });
    }
  }
  for (final invalid in [null, 'malformed', -1, 0, 1.5, 999999999999999999]) {
    testWidgets('invalid mention time $invalid is blank and does not crash', (
      tester,
    ) async {
      await _expectTime(tester, invalid, '');
    });
  }
}
