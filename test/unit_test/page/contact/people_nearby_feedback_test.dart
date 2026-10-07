import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_page.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_provider.dart';

class _PendingVisibility extends PeopleNearbyNotifier {
  _PendingVisibility(this.visible);
  final bool visible;
  final result = Completer<bool>();
  int calls = 0;
  int nearbyCalls = 0;

  @override
  PeopleNearbyState build() => PeopleNearbyState(peopleNearbyVisible: visible);
  @override
  Future<void> init() async {}
  @override
  Future<void> peopleNearby() async {
    nearbyCalls++;
  }

  @override
  Future<bool> makeMyselfVisible() {
    calls++;
    return result.future;
  }

  @override
  Future<bool> makeMyselfUnVisible() {
    calls++;
    return result.future;
  }
}

void main() {
  testWidgets('resume revalidates nearby location and permissions', (
    tester,
  ) async {
    final notifier = _PendingVisibility(false);
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [peopleNearbyProvider.overrideWith(() => notifier)],
          child: MaterialApp(
            builder: AppLoading.init(),
            home: const PeopleNearbyPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(notifier.nearbyCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final visible in [true, false]) {
    for (final succeeds in [true, false]) {
      testWidgets(
        'visibility=$visible result=$succeeds feedback waits for confirmation',
        (tester) async {
          final notifier = _PendingVisibility(visible);
          await tester.pumpWidget(
            TranslationProvider(
              child: ProviderScope(
                overrides: [peopleNearbyProvider.overrideWith(() => notifier)],
                child: MaterialApp(
                  builder: AppLoading.init(),
                  home: const PeopleNearbyPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(
              visible
                  ? t.main.makeYourselfInvisible
                  : t.main.makeYourselfVisible,
            ),
          );
          await tester.pumpAndSettle();
          if (!visible) {
            await tester.tap(find.text(t.common.buttonConfirm));
            await tester.pumpAndSettle();
          }
          expect(notifier.calls, 1);
          final success = visible
              ? t.common.locationHidden
              : t.common.locationVisible;
          expect(find.text(success), findsNothing);
          notifier.result.complete(succeeds);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text(success), succeeds ? findsOneWidget : findsNothing);
          if (!succeeds) {
            expect(
              find.text(t.common.operationFailedAgainLater),
              findsOneWidget,
            );
          }
          unawaited(AppLoading.dismiss());
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
