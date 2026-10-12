import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_timeline.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

List<EnterpriseMessage> rows(int first, int last) => [
  for (var id = first; id <= last; id++)
    EnterpriseMessage(
      id: '$id',
      organizationId: 'org',
      conversationId: 'conv',
      content: 'message $id',
    ),
];

Widget timeline(
  List<EnterpriseMessage> messages, {
  bool allowed = true,
  bool foreground = true,
  bool hasOlder = false,
  Future<void> Function()? older,
  ValueChanged<List<String>>? visible,
}) => MaterialApp(
  builder: (_, child) => TranslationProvider(child: child!),
  home: Scaffold(
    body: SizedBox(
      height: 240,
      child: CsSessionTimeline(
        messages: messages,
        readAllowed: allowed,
        canAcknowledge: () => foreground,
        onVisible: visible ?? (_) {},
        hasOlder: hasOlder,
        loadingOlder: false,
        historyFailed: false,
        olderFailed: false,
        loadOlder: older ?? () async {},
        retryHistory: () async {},
        empty: const Text('empty'),
        itemBuilder: (_, m) => SizedBox(height: 60, child: Text(m.content)),
      ),
    ),
  ),
);

void main() {
  testWidgets('only actual viewport ids are reported; foreground is required', (
    tester,
  ) async {
    final reports = <List<String>>[];
    await tester.pumpWidget(timeline(rows(1, 20), visible: reports.add));
    await tester.pump();
    expect(reports.last.length, lessThan(20));
    expect(reports.last, contains('20'));
    reports.clear();
    await tester.pumpWidget(
      timeline(rows(1, 20), foreground: false, visible: reports.add),
    );
    await tester.pump();
    expect(reports, isEmpty);
  });

  testWidgets(
    'reading history stays anchored across prepend and new messages',
    (tester) async {
      var messages = rows(51, 100);
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return timeline(
              messages,
              hasOlder: true,
              older: () async {
                update(() => messages = rows(1, 100));
              },
            );
          },
        ),
      );
      await tester.pump();
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(scroll.position.minScrollExtent);
      await tester.pump();
      final before = tester.getTopLeft(find.text('message 51')).dy;
      await tester.tap(find.byKey(const ValueKey('cs-load-older')));
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(find.text('message 51')).dy, closeTo(before, 1));
      final pixels = scroll.position.pixels;
      update(() => messages = rows(1, 101));
      await tester.pump();
      await tester.pump();
      expect(scroll.position.pixels, closeTo(pixels, 1));
    },
  );

  testWidgets('revoked read removes all message body and never reports ids', (
    tester,
  ) async {
    final reports = <List<String>>[];
    await tester.pumpWidget(
      timeline(rows(1, 10), allowed: false, visible: reports.add),
    );
    await tester.pump();
    expect(find.textContaining('message '), findsNothing);
    expect(reports, isEmpty);
  });
  testWidgets(
    '200 loaded messages do not instantiate offscreen attachment builders',
    (tester) async {
      var built = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TranslationProvider(child: child!),
          home: SizedBox(
            height: 240,
            child: CsSessionTimeline(
              messages: rows(1, 200),
              readAllowed: true,
              canAcknowledge: () => false,
              onVisible: (_) {},
              hasOlder: false,
              loadingOlder: false,
              historyFailed: false,
              olderFailed: false,
              loadOlder: () async {},
              retryHistory: () async {},
              empty: const SizedBox(),
              itemBuilder: (_, m) {
                built++;
                return SizedBox(height: 60, child: Text(m.content));
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(built, lessThan(200));
    },
  );
  testWidgets(
    'older request exposes pending and disables duplicate action until completion',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        timeline(rows(1, 10), hasOlder: true, older: () => pending.future),
      );
      await tester.pump();
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(scroll.position.minScrollExtent);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cs-load-older')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('cs-load-older')))
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
