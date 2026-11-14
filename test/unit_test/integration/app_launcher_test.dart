import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/flows/app_launcher.dart';

void main() {
  testWidgets('owned launcher retries failure and reuses a mounted app', (
    tester,
  ) async {
    var attempts = 0;
    Future<void> launch(WidgetTester tester) async {
      attempts++;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      if (attempts == 1 || attempts == 3) {
        throw StateError('launch failed');
      }
    }

    Object? launchError;
    try {
      await ensureAppLaunched(tester, maxSeconds: 1, launch: launch);
    } catch (error) {
      launchError = error;
    }
    expect(launchError, isA<StateError>());
    await ensureAppLaunched(tester, maxSeconds: 1, launch: launch);
    await ensureAppLaunched(tester, maxSeconds: 1, launch: launch);
    expect(attempts, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    launchError = null;
    try {
      await ensureAppLaunched(tester, maxSeconds: 1, launch: launch);
    } catch (error) {
      launchError = error;
    }
    expect(launchError, isA<StateError>());
    expect(find.byType(MaterialApp), findsOneWidget);
    await ensureAppLaunched(tester, maxSeconds: 1, launch: launch);
    expect(attempts, 4);
  });
}
