import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_recording_host.dart';

void main() {
  testWidgets('logged-out safety warning survives failed runtime resolution', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final container = ProviderContainer(
      overrides: [
        talkRecordRecordingRuntimeProvider.overrideWith((ref) async {
          throw StateError('synthetic unavailable runtime');
        }),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(talkRecordActiveCaptureProvider.notifier)
        .show(
          originContext: const TalkRecordEntryContext.personal(),
          title: 'PRIVATE-OLD-TITLE',
          positionMs: 1200,
        );
    container.read(talkRecordStopUnconfirmedProvider.notifier).set(true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TalkRecordRecordingHost(
            navigatorKey: GlobalKey<NavigatorState>(),
            child: const Text('LOGIN-PAGE'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('PRIVATE-OLD-TITLE'), findsNothing);
    expect(find.text('LOGIN-PAGE'), findsOneWidget);
    expect(find.text(t.talkRecord.microphoneStopUnconfirmed), findsOneWidget);
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    expect(container.read(talkRecordStopUnconfirmedProvider), isTrue);
    expect(tester.takeException(), isNull);
  });
}
