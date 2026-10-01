import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/modules/enterprise_oa/presentation/oa_webview_container.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native OA HTTPS cookie and storage session isolation', (
    tester,
  ) async {
    const origin = String.fromEnvironment('OA_NATIVE_TEST_ORIGIN');
    const forbidden = String.fromEnvironment('OA_NATIVE_FORBIDDEN_ORIGIN');
    expect(Platform.isAndroid, isTrue);
    expect(Uri.parse(origin).scheme, 'https');
    expect(Uri.parse(origin).host, '127.0.0.1');
    expect(Uri.parse(forbidden).host, '127.0.0.1');
    expect(Uri.parse(forbidden).scheme, 'https');
    expect(forbidden, isNot(origin));
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'pub.imboy.app.gzcustomer',
    );
    await checkOverlap(tester, origin);
    await checkExit(tester, origin, forbidden);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> checkOverlap(WidgetTester tester, String origin) async {
  final a = OaTabStateMachine();
  final b = OaTabStateMachine();
  await tester.pumpWidget(host(origin, a, b, showA: true, showB: false));
  await ready(tester, a);
  expect(await probe(tester, 'a'), containsPair('session_a', true));
  await tester.pumpWidget(host(origin, a, b, showA: true, showB: true));
  await ready(tester, b);
  final entry = await javascript(
    tester,
    'b',
    'JSON.stringify(window.entryProbe)',
  );
  expect(jsonDecode(entry.toString()), containsPair('old_storage', false));
  final current = await probe(tester, 'b');
  expect(current, containsPair('session_a', false));
  expect(current, containsPair('session_b', true));
  await tester.pumpWidget(host(origin, a, b, showA: false, showB: true));
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 9)));
  await tester.pump();
  final afterOldExit = await probe(tester, 'b');
  expect(afterOldExit, containsPair('session_b', true));
  expect(afterOldExit, containsPair('late_a', false));
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pump();
}

Future<void> checkExit(
  WidgetTester tester,
  String origin,
  String forbidden,
) async {
  final c = OaTabStateMachine();
  await tester.pumpWidget(
    host(origin, c, c, showA: false, showB: true, second: 'c'),
  );
  await ready(tester, c);
  expect(await probe(tester, 'c'), containsPair('session_b', false));
  await javascript(tester, 'c', "location.href='$forbidden/forbidden';");
  await waitUntil(tester, () => c.status == OaTabStatus.originMismatch);
  expect(await javascript(tester, 'c', 'document.body.dataset.scope'), 'c');
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pump();
}

Widget host(
  String origin,
  OaTabStateMachine a,
  OaTabStateMachine b, {
  required bool showA,
  required bool showB,
  String second = 'b',
}) => MaterialApp(
  home: Stack(
    children: [
      if (showA)
        OaWebViewContainer(
          key: const ValueKey('a'),
          initialUrl: '$origin/a',
          machine: a,
          allowedOrigin: origin,
        ),
      if (showB)
        OaWebViewContainer(
          key: ValueKey(second),
          initialUrl: '$origin/$second',
          machine: b,
          allowedOrigin: origin,
        ),
    ],
  ),
);

Future<void> ready(WidgetTester tester, OaTabStateMachine machine) =>
    waitUntil(tester, () => machine.status == OaTabStatus.ready);

Future<void> waitUntil(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(condition(), isTrue);
}

Future<Object> javascript(
  WidgetTester tester,
  String scope,
  String script,
) async {
  final view = tester.widget<WebViewWidget>(
    find.descendant(
      of: find.byKey(ValueKey(scope)),
      matching: find.byType(WebViewWidget),
    ),
  );
  final result = (await tester.runAsync(
    () => view.platform.params.controller.runJavaScriptReturningResult(script),
  ))!;
  if (result is String && result.isNotEmpty) {
    return (jsonDecode(result) as Object?) ?? 'null';
  }
  return result;
}

Future<Map<String, dynamic>> probe(WidgetTester tester, String scope) async {
  await javascript(
    tester,
    scope,
    "window.nativeProbe=null; fetch('/probe').then(r=>r.json()).then(p=>window.nativeProbe=p); true;",
  );
  Map<String, dynamic>? result;
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (result == null && DateTime.now().isBefore(deadline)) {
    final value = await javascript(
      tester,
      scope,
      'JSON.stringify(window.nativeProbe)',
    );
    final decoded = jsonDecode(value.toString());
    if (decoded is Map<String, dynamic>) result = decoded;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(result, isNotNull);
  return result!;
}
