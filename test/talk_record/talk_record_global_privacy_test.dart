import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_recording_bar.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

void main() {
  const privateTitle = 'PRIVATE-RECORD-TITLE';
  const privateOrg = 'PRIVATE-ORGANIZATION';
  const origin = TalkRecordEntryContext(
    scope: TalkRecordScope.organization,
    organizationId: 'synthetic-org',
    organizationName: privateOrg,
  );

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      // Keep platform/runtime assembly out of these projection tests.
      talkRecordRecordingRuntimeProvider.overrideWith(
        (ref) => Completer<TalkRecordRecordingCoordinator>().future,
      ),
    ],
  );

  void show(ProviderContainer container) => container
      .read(talkRecordActiveCaptureProvider.notifier)
      .show(originContext: origin, title: privateTitle, positionMs: 42000);

  test('hide clears private title, organization and elapsed time', () {
    final container = newContainer();
    addTearDown(container.dispose);
    show(container);
    container.read(talkRecordActiveCaptureProvider.notifier).hide();
    final state = container.read(talkRecordActiveCaptureProvider);
    expect(state.visible, isFalse);
    expect(state.title, isEmpty);
    expect(state.originContext.organizationId, isEmpty);
    expect(state.originContext.organizationName, isEmpty);
    expect(state.positionMs, 0);
  });

  testWidgets(
    'open modal loses private content and controls immediately on hide',
    (tester) async {
      final container = newContainer();
      addTearDown(container.dispose);
      show(container);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TalkRecordGlobalRecordingBar(
                currentContext: TalkRecordEntryContext.personal(),
                actions: [Text('SYNTHETIC-RECORDING-CONTROL')],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('talk_record_recording_bar')));
      await tester.pumpAndSettle();
      expect(find.text('SYNTHETIC-RECORDING-CONTROL'), findsOneWidget);
      expect(find.text(privateTitle), findsWidgets);
      container.read(talkRecordActiveCaptureProvider.notifier).hide();
      await tester.pump();
      expect(find.text(privateTitle), findsNothing);
      expect(find.textContaining(privateOrg), findsNothing);
      expect(find.text('SYNTHETIC-RECORDING-CONTROL'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('application host scope suppresses page-local duplicate bar', (
    tester,
  ) async {
    final container = newContainer();
    addTearDown(container.dispose);
    show(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TalkRecordRecordingHostScope(
              child: Column(
                children: [
                  TalkRecordGlobalRecordingBar(
                    currentContext: TalkRecordEntryContext.personal(),
                  ),
                  TalkRecordGlobalRecordingBar(
                    applicationHost: true,
                    currentContext: TalkRecordEntryContext.personal(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('talk_record_recording_bar')),
      findsOneWidget,
    );
    expect(find.text(privateTitle), findsOneWidget);
  });

  testWidgets('missing root modal context safely ignores tap', (tester) async {
    final container = newContainer();
    addTearDown(container.dispose);
    show(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TalkRecordGlobalRecordingBar(
              currentContext: const TalkRecordEntryContext.personal(),
              modalContext: () => null,
              actions: const [Text('UNOPENED-CONTROL')],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('talk_record_recording_bar')));
    await tester.pump();
    expect(find.text('UNOPENED-CONTROL'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
