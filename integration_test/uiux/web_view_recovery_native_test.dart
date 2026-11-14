import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/safe_launcher.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../enterprise/macos_storage_isolation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('UX05 Android native WebView network failure and recovery', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('IMBOY_ANDROID_QA_BUILD'), isTrue);
    expect((await DeviceInfoPlugin().androidInfo).isPhysicalDevice, isTrue);
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'pub.imboy.app.uiuxqa',
    );
    final scope = await tester.runAsync(isolateNativeStorage);
    expect(scope, isNotNull);
    addTearDown(() async {
      await tester.runAsync(() => clearMacosStorage(scope!));
    });
    final fixture = await tester.runAsync(_WebFixture.start);
    expect(fixture, isNotNull);
    addTearDown(() async {
      fixture!.release();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.close);
    });
    await _networkRecovery(tester, fixture!);
    await _subresourceFailure(tester, fixture);
    await _httpRecovery(tester, fixture);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _open(WidgetTester tester, _WebFixture fixture) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(
              SafeLauncher.safeLaunchUrl(fixture.url, context: context),
            ),
            child: const Text('Open synthetic webpage'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open synthetic webpage'));
  await _wait(tester, () => tester.any(find.byType(WebViewPage)), 'web route');
  expect(find.text('127.0.0.1'), findsOneWidget);
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  expect(ready(), isTrue, reason: 'UX05 native $stage');
  expect(tester.takeException(), isNull);
}

Future<void> _body(WidgetTester tester, String marker) async {
  await _wait(
    tester,
    () => !tester.any(find.byType(LinearProgressIndicator)),
    'load completion',
  );
  final view = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
  final body = await tester.runAsync(
    () => view.platform.params.controller.runJavaScriptReturningResult(
      'document.body.textContent',
    ),
  );
  expect(body.toString(), contains(marker), reason: 'real native document');
}

Future<void> _back(WidgetTester tester) async {
  final back = find.byType(GlassBackButton);
  expect(back, findsOneWidget);
  await tester.tap(back);
  await _wait(tester, () => !tester.any(find.byType(WebViewPage)), 'return');
  expect(find.text('Open synthetic webpage'), findsOneWidget);
}

Future<void> _networkRecovery(WidgetTester tester, _WebFixture fixture) async {
  fixture.hold = Completer<void>();
  fixture.failDocument = true;
  await _open(tester, fixture);
  await _wait(tester, () => fixture.documents > 0, 'main document request');
  expect(find.byType(LinearProgressIndicator), findsOneWidget);
  fixture.release();
  await _wait(
    tester,
    () => tester.any(find.byKey(const ValueKey('webview-error'))),
    'network failure recovery UI',
  );
  expect(fixture.failedDocuments, greaterThanOrEqualTo(1));
  expect(find.byType(LinearProgressIndicator), findsNothing);
  final before = fixture.documents;
  fixture.failDocument = false;
  await tester.tap(find.text(t.common.buttonRetry));
  await _wait(tester, () => fixture.documents > before, 'retry request');
  await _body(tester, 'UX05 recovered document');
  expect(fixture.documents, before + 1, reason: 'one user retry request');
  expect(find.byKey(const ValueKey('webview-error')), findsNothing);
  await _back(tester);
}

Future<void> _subresourceFailure(
  WidgetTester tester,
  _WebFixture fixture,
) async {
  fixture.brokenResource = true;
  await _open(tester, fixture);
  await _wait(
    tester,
    () => fixture.failedResources > 0,
    'broken image request',
  );
  await _body(tester, 'UX05 recovered document');
  expect(find.byKey(const ValueKey('webview-error')), findsNothing);
  expect(find.byKey(const ValueKey('webview-load-warning')), findsNothing);
  await _back(tester);
  fixture.brokenResource = false;
}

Future<void> _httpRecovery(WidgetTester tester, _WebFixture fixture) async {
  fixture.status = HttpStatus.serviceUnavailable;
  final documentsBefore = fixture.documents;
  await _open(tester, fixture);
  final views = find.byType(WebViewWidget);
  final controller = tester.any(views)
      ? tester.widget<WebViewWidget>(views).platform.params.controller
      : null;
  try {
    await _wait(
      tester,
      () => tester.any(find.byKey(const ValueKey('webview-load-warning'))),
      'HTTP 503 recovery UI',
    );
  } on Object {
    final diagnostic = <String, Object?>{
      'documentsBefore': documentsBefore,
      'documentsAfter': fixture.documents,
      'completed503Responses': fixture.completed503Responses,
      'visibleError': tester.any(find.byKey(const ValueKey('webview-error'))),
      'visibleWarning': tester.any(
        find.byKey(const ValueKey('webview-load-warning')),
      ),
      'visibleProgress': tester.any(find.byType(LinearProgressIndicator)),
      'diagnosticFailed': false,
    };
    try {
      if (controller == null) throw StateError('Controller unavailable');
      await tester.runAsync(() async {
        try {
          diagnostic['currentUrlMatches'] =
              await controller.currentUrl() == fixture.url.toString();
          diagnostic['has503Marker'] =
              (await controller.runJavaScriptReturningResult(
                "document.body.textContent.includes('UX05 HTTP unavailable')",
              )).toString() ==
              'true';
          final ready = (await controller.runJavaScriptReturningResult(
            'document.readyState',
          )).toString().replaceAll('"', '');
          diagnostic['readyState'] =
              const {'loading', 'interactive', 'complete'}.contains(ready)
              ? ready
              : 'unknown';
          diagnostic['navigationStatus'] = int.tryParse(
            (await controller.runJavaScriptReturningResult(
              "performance.getEntriesByType('navigation')[0]?.responseStatus ?? 0",
            )).toString(),
          );
        } on Object {
          diagnostic['diagnosticFailed'] = true;
        }
      });
    } on Object {
      diagnostic['diagnosticFailed'] = true;
    }
    debugPrint('UX05_503_FAILURE_DIAGNOSTIC ${jsonEncode(diagnostic)}');
    rethrow;
  }
  await _body(tester, 'UX05 HTTP unavailable');
  expect(find.byKey(const ValueKey('webview-error')), findsNothing);
  final before = fixture.documents;
  fixture.status = HttpStatus.ok;
  await tester.tap(find.text(t.common.buttonRetry));
  await _wait(tester, () => fixture.documents > before, 'HTTP retry request');
  await _body(tester, 'UX05 recovered document');
  expect(fixture.documents, before + 1);
  expect(find.byKey(const ValueKey('webview-load-warning')), findsNothing);
  await _back(tester);
}

class _WebFixture {
  _WebFixture(this.server);
  final HttpServer server;
  Completer<void>? hold;
  bool failDocument = false;
  bool brokenResource = false;
  int status = HttpStatus.ok;
  int documents = 0;
  int failedDocuments = 0;
  int failedResources = 0;
  int completed503Responses = 0;
  final errors = <Object>[];
  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/page');

  static Future<_WebFixture> start() async {
    final fixture = _WebFixture(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    fixture.server.listen((request) {
      unawaited(
        fixture.serve(request).catchError((Object error) {
          fixture.errors.add(error);
        }),
      );
    }, onError: fixture.errors.add);
    return fixture;
  }

  void release() {
    if (hold != null && !hold!.isCompleted) hold!.complete();
  }

  Future<void> serve(HttpRequest request) async {
    final document = request.uri.path == '/page';
    if (document) {
      documents++;
      if (hold != null) await hold!.future;
    }
    if ((document && failDocument) || request.uri.path == '/broken.png') {
      if (document) {
        failedDocuments++;
      } else {
        failedResources++;
      }
      // Close before HTTP headers: the native plugin must report a network error.
      (await request.response.detachSocket(writeHeaders: false)).destroy();
      return;
    }
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.headers.contentType = ContentType.html;
    request.response.statusCode = document ? status : HttpStatus.notFound;
    request.response.write(
      '<!doctype html><html><body>'
      '${status == 200 ? 'UX05 recovered document' : 'UX05 HTTP unavailable'}'
      '${brokenResource ? '<img src="/broken.png">' : ''}'
      '</body></html>',
    );
    await request.response.close();
    if (document &&
        request.response.statusCode == HttpStatus.serviceUnavailable) {
      completed503Responses++;
    }
  }

  Future<void> close() async {
    release();
    await server.close(force: true);
    expect(errors, isEmpty, reason: 'loopback server diagnostics');
  }
}
