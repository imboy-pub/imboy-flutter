import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_timeline.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

List<EnterpriseMessage> rows(int first, int last, {String conv = 'conv'}) => [
  for (var id = first; id <= last; id++)
    EnterpriseMessage(
      id: '$id',
      organizationId: 'org',
      conversationId: conv,
      content: 'message $id',
    ),
];

Widget timeline(
  List<EnterpriseMessage> messages, {
  bool dark = false,
  double textScale = 1,
  bool allowed = true,
  bool foreground = true,
  bool hasOlder = false,
  Future<void> Function()? older,
  ValueChanged<List<String>>? visible,
}) => MaterialApp(
  theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
  builder: (context, child) => TranslationProvider(
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
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
      final reports = <List<String>>[];
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return timeline(
              messages,
              visible: reports.add,
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
      expect(find.byKey(const ValueKey('cs-jump-to-latest')), findsNothing);
      final pixels = scroll.position.pixels;
      reports.clear();
      update(() => messages = rows(1, 101));
      await tester.pump();
      await tester.pump();
      expect(scroll.position.pixels, closeTo(pixels, 1));
      expect(reports.expand((r) => r), isNot(contains('101')));
      final jump = find.byKey(const ValueKey('cs-jump-to-latest'));
      expect(jump, findsOneWidget);
      await tester.tap(jump);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(scroll.position.extentAfter, closeTo(0, 1));
      expect(find.text('message 101'), findsOneWidget);
      expect(reports.last, contains('101'));
      expect(reports.last.length, lessThan(101));
      expect(jump, findsNothing);
    },
  );

  testWidgets('bottom follows new messages without exposing jump entry', (
    tester,
  ) async {
    final reports = <List<String>>[];
    await tester.pumpWidget(timeline(rows(1, 20), visible: reports.add));
    await tester.pump();
    await tester.pumpWidget(timeline(rows(1, 21), visible: reports.add));
    await tester.pump();
    await tester.pump();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroll.position.extentAfter, closeTo(0, 1));
    expect(find.byKey(const ValueKey('cs-jump-to-latest')), findsNothing);
    expect(reports.last, contains('21'));
  });

  for (final boundary in ['revoke', 'foreground', 'scope', 'empty']) {
    testWidgets('$boundary clears an old scope new-message entry', (
      tester,
    ) async {
      await tester.pumpWidget(timeline(rows(1, 20)));
      await tester.pump();
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(scroll.position.minScrollExtent);
      await tester.pump();
      await tester.pumpWidget(timeline(rows(1, 21)));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('cs-jump-to-latest')), findsOneWidget);
      final reports = <List<String>>[];
      await tester.pumpWidget(
        timeline(
          boundary == 'empty'
              ? []
              : rows(1, 21, conv: boundary == 'scope' ? 'other' : 'conv'),
          allowed: boundary != 'revoke',
          foreground: boundary != 'foreground',
          visible: reports.add,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('cs-jump-to-latest')), findsNothing);
      if (boundary == 'revoke' || boundary == 'foreground') {
        expect(reports, isEmpty);
      }
      await tester.pumpWidget(timeline(rows(1, 21)));
      await tester.pump();
      expect(find.byKey(const ValueKey('cs-jump-to-latest')), findsNothing);
    });
  }

  testWidgets('new-message entry is accessible in dark large-text layout', (
    tester,
  ) async {
    await tester.pumpWidget(timeline(rows(1, 20), dark: true, textScale: 2));
    await tester.pump();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    scroll.position.jumpTo(scroll.position.minScrollExtent);
    await tester.pump();
    await tester.pumpWidget(timeline(rows(1, 21), dark: true, textScale: 2));
    await tester.pump();
    await tester.pump();
    final jump = find.byKey(const ValueKey('cs-jump-to-latest'));
    expect(tester.getSize(jump).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(jump).width, greaterThanOrEqualTo(44));
    expect(tester.getSemantics(jump).label, contains('查看最新'));
    expect(tester.takeException(), isNull);
    await tester.tap(jump);
    await tester.pump();
    await tester.pump();
    expect(scroll.position.extentAfter, closeTo(0, 1));
  });

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
