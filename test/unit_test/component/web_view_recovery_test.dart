import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helper/fake_webview_platform.dart';

void main() {
  late FakeWebViewPlatform platform;
  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });
  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: WebViewPage('https://example.test/page', 'Synthetic page'),
    ),
  );
  void fail({String url = 'https://example.test/page', bool main = true}) =>
      platform.resourceError(
        WebResourceError(
          errorCode: -2,
          description: 'private request details',
          isForMainFrame: main,
          url: url,
        ),
      );

  testWidgets('named page has local progress and completes', (tester) async {
    await open(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    platform.progress(35);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .35,
    );
    platform.finished('https://example.test/page');
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets(
    'subresource failure preserves page without caller notification',
    (tester) async {
      final errors = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: WebViewPage(
            'https://example.test/page',
            'Synthetic page',
            errorCallback: errors.add,
          ),
        ),
      );
      fail(url: 'https://example.test/image.png', main: false);
      await tester.pump();
      expect(find.byKey(const ValueKey('webview-error')), findsNothing);
      expect(
        find.byKey(const ValueKey('fake-webview-surface')),
        findsOneWidget,
      );
      expect(errors, isEmpty);
    },
  );
  testWidgets('main failure survives finish event and retry reloads once', (
    tester,
  ) async {
    await open(tester);
    fail();
    platform.finished('https://example.test/page');
    await tester.pump();
    expect(find.byKey(const ValueKey('webview-error')), findsOneWidget);
    expect(find.textContaining('private request details'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    expect(platform.requests.map((u) => u.toString()), [
      'https://example.test/page',
      'https://example.test/page',
    ]);
    expect(find.byKey(const ValueKey('webview-error')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    platform.finished('https://example.test/page');
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets('subresource HTTP errors do not warn for the whole document', (
    tester,
  ) async {
    await open(tester);
    for (final error in [
      HttpResponseError(
        request: WebResourceRequest(
          uri: Uri.parse('https://example.test/image.png'),
        ),
        response: WebResourceResponse(uri: null, statusCode: 404),
      ),
      HttpResponseError(
        response: WebResourceResponse(
          uri: Uri.parse('https://example.test/favicon.ico'),
          statusCode: 404,
        ),
      ),
    ]) {
      platform.httpError?.call(error);
      await tester.pump();
      expect(find.byKey(const ValueKey('webview-load-warning')), findsNothing);
      expect(find.byKey(const ValueKey('webview-error')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    }
    platform.finished('https://example.test/page');
    await tester.pump();
    expect(find.byKey(const ValueKey('fake-webview-surface')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('HTTP errors retain content and offer persistent recovery', (
    tester,
  ) async {
    await open(tester);
    platform.httpError?.call(
      HttpResponseError(
        request: WebResourceRequest(
          uri: Uri.parse('https://example.test/page'),
        ),
        response: WebResourceResponse(uri: null, statusCode: 503),
      ),
    );
    platform.finished('https://example.test/page');
    await tester.pump();
    expect(find.byKey(const ValueKey('webview-load-warning')), findsOneWidget);
    expect(find.byKey(const ValueKey('webview-error')), findsNothing);
    expect(find.byKey(const ValueKey('fake-webview-surface')), findsOneWidget);
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    expect(platform.requests.length, 2);
    expect(platform.requests.last.toString(), 'https://example.test/page');
    expect(find.byKey(const ValueKey('webview-load-warning')), findsNothing);
    platform.httpError?.call(
      HttpResponseError(
        response: WebResourceResponse(
          uri: Uri.parse('https://example.test/page'),
          statusCode: 500,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('webview-error')), findsNothing);
    expect(find.byKey(const ValueKey('fake-webview-surface')), findsOneWidget);
    expect(find.byKey(const ValueKey('webview-load-warning')), findsOneWidget);
  });

  testWidgets('failed redirect retries current document', (tester) async {
    await open(tester);
    platform.started('https://example.test/next');
    fail(url: 'https://example.test/next');
    await tester.pump();
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    expect(platform.requests.last.toString(), 'https://example.test/next');
  });
  testWidgets('load exception has a recovery action and stays in page', (
    tester,
  ) async {
    platform.load = (_) => Future<void>.error(StateError('synthetic failure'));
    await open(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('webview-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
    platform.load = null;
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
  testWidgets('recovery is reachable across all 18 planned mobile layouts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    try {
      var executed = 0;
      for (final width in [320.0, 360.0, 390.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final brightness in Brightness.values) {
            await tester.pumpWidget(const SizedBox.shrink());
            tester.view.physicalSize = Size(width, 480);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const WebViewPage(
                  'https://example.test/page',
                  'Synthetic page',
                ),
              ),
            );
            fail();
            await tester.pump();
            final retry = find.text(t.common.buttonRetry);
            await tester.ensureVisible(retry);
            expect(retry.hitTestable(), findsOneWidget);
            expect(find.bySemanticsLabel(t.common.buttonRetry), findsWidgets);
            expect(
              tester.getSize(find.byType(RoundedCupertinoButton)).height,
              greaterThanOrEqualTo(48),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$width $scale $brightness',
            );
            await tester.tap(retry);
            platform.httpError?.call(
              HttpResponseError(
                response: WebResourceResponse(uri: null, statusCode: 503),
              ),
            );
            platform.finished('https://example.test/page');
            await tester.pump();
            final warning = find.byKey(const ValueKey('webview-load-warning'));
            final warningText = find.text(t.common.webpageLoadProblem);
            expect(
              MediaQuery.textScalerOf(tester.element(warningText)).scale(10),
              scale * 10,
            );
            final warningSemantics = find.ancestor(
              of: warningText,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.liveRegion == true,
              ),
            );
            expect(warningSemantics, findsWidgets);
            final warningRetry = find.descendant(
              of: warning,
              matching: find.byType(TextButton),
            );
            expect(warningRetry.hitTestable(), findsOneWidget);
            expect(
              tester.getSize(warningRetry).height,
              greaterThanOrEqualTo(48),
            );
            expect(find.bySemanticsLabel(t.common.buttonRetry), findsWidgets);
            expect(
              tester.takeException(),
              isNull,
              reason: '$width $scale $brightness',
            );
            executed++;
          }
        }
      }
      expect(executed, 18);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('HTTP recovery stays reachable above a retained keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 280),
          ),
          child: child!,
        ),
        home: const WebViewPage('https://example.test/page', 'Synthetic'),
      ),
    );
    platform.httpError?.call(
      HttpResponseError(
        response: WebResourceResponse(uri: null, statusCode: 503),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final retry = find.text(t.common.buttonRetry);
    await tester.ensureVisible(retry);
    expect(retry.hitTestable(), findsOneWidget);
    await tester.tap(retry);
    await tester.pump();
    expect(platform.requests.length, 2);
  });

  testWidgets('leaving during cache clear does not issue late load', (
    tester,
  ) async {
    final cache = Completer<void>();
    platform.clear = () => cache.future;
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewPage('https://imboy.pub/synthetic', 'Synthetic'),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    cache.complete();
    await tester.pump();
    expect(platform.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
