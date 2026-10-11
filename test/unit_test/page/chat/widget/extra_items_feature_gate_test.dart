import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/extra_item.dart';

void main() {
  tearDown(() => AppFeatureRegistry.replaceSnapshotForTest({}));

  for (final type in ['C2C', 'C2G']) {
    testWidgets('$type tools hide disabled delivery domains', (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest({
        FeatureKeys.rtc: false,
        FeatureKeys.wallet: false,
        FeatureKeys.location: false,
        FeatureKeys.groupVote: false,
        FeatureKeys.groupSchedule: false,
        FeatureKeys.groupTask: false,
      });
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: ExtraItems(type: type, options: const {'to': '3001'}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final titles = tester
          .widgetList<ExtraItem>(find.byType(ExtraItem))
          .map((item) => item.title)
          .toSet();
      for (final title in [
        t.common.voiceCall,
        t.common.videoCall,
        t.common.groupCall,
        t.common.redPacket,
        t.common.transfer,
        t.groupSchedule.location,
        t.groupVote.title,
        t.groupSchedule.title,
        t.groupTask.title,
      ]) {
        expect(titles, isNot(contains(title)));
      }
      expect(titles, contains(t.main.album));
      expect(titles, contains(t.chat.file));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'mounted composer restores location and group tools after recovery',
    (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest({});
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: ExtraItems(type: 'C2G', options: const {'to': '3001'}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(t.groupSchedule.location), findsNothing);
      expect(find.text(t.groupVote.title), findsNothing);
      AppFeatureRegistry.replaceSnapshotForTest({
        FeatureKeys.location: true,
        FeatureKeys.groupVote: true,
      });
      await tester.pump();
      expect(find.text(t.groupSchedule.location), findsOneWidget);
      expect(find.text(t.groupVote.title), findsOneWidget);
      expect(find.text(t.main.album), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
