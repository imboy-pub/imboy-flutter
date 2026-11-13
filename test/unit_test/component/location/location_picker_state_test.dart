import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/location/widget.dart';
import 'package:imboy/i18n/strings.g.dart';
// Exercise the installed platform boundary without a native map or network.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../helper/fake_webview_platform.dart';

class _MapNetwork extends HttpOverrides {
  final requests = <(Uri, Completer<Map<String, dynamic>>)>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(this);

  void complete(int index, List<String> names) {
    requests[index].$2.complete({
      'status': '1',
      'pois': [
        for (final name in names)
          {
            'id': name,
            'name': name,
            'location': '0.01,0.02',
            'address': 'Synthetic address',
            'adcode': '000000',
            'distance': '1',
          },
      ],
    });
  }
}

class _Client implements HttpClient {
  _Client(this.network);
  final _MapNetwork network;
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final result = Completer<Map<String, dynamic>>();
    network.requests.add((url, result));
    return _Request(result.future);
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  void forEach(void Function(String, List<String>) action) =>
      action(HttpHeaders.contentTypeHeader, ['application/json']);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.result);
  final Future<Map<String, dynamic>> result;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(await result);
  @override
  Future<HttpClientResponse> get done => close();
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(Map<String, dynamic> body) : bytes = utf8.encode(jsonEncode(body));
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => bytes.length;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  HttpHeaders get headers => _Headers();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final network = _MapNetwork();
  setUpAll(() => HttpOverrides.global = network);
  setUp(() {
    network.requests.clear();
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  Future<void> mount(WidgetTester tester, {double textScale = 1}) async {
    await HttpOverrides.runZoned(
      () => tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Material(
            child: MapLocationPicker(
              arguments: {
                'lat': 0.02,
                'lng': 0.01,
                'citycode': '000000',
                'isMapImage': false,
              },
            ),
          ),
        ),
      ),
      createHttpClient: network.createHttpClient,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('around requests use longitude before latitude', (tester) async {
    await mount(tester);
    final coordinates = network.requests.single.$1.queryParameters['location']!
        .split(',')
        .map(double.parse)
        .toList();
    expect(coordinates, hasLength(2));
    expect(coordinates[0], closeTo(0.01, 1e-9));
    expect(coordinates[1], closeTo(0.02, 1e-9));
    network.complete(0, []);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'new keyword immediately invalidates the previously selected POI',
    (tester) async {
      await mount(tester);
      network.complete(0, ['Synthetic A']);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic A'));
      await tester.enterText(find.byType(TextField), 'Synthetic B');
      await tester.pump();
      expect(find.text('Synthetic A'), findsNothing);
      final send = tester.widget<CupertinoButton>(
        find.ancestor(
          of: find.text(t.common.buttonSend),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(send.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      network.complete(1, []);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'latest keyword owns results even when older query returns last',
    (tester) async {
      await mount(tester);
      network.complete(0, ['Initial']);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'older');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'newer');
      await tester.pump();
      network.complete(2, ['Current result']);
      await tester.pumpAndSettle();
      network.complete(1, ['Stale result']);
      await tester.pumpAndSettle();
      expect(find.text('Current result'), findsOneWidget);
      expect(find.text('Stale result'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('successful empty query explains the empty result', (
    tester,
  ) async {
    await mount(tester);
    network.complete(0, []);
    await tester.pumpAndSettle();
    expect(find.text(t.common.searchNoResults), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('first-page errors stop loading and retry succeeds', (
    tester,
  ) async {
    await mount(tester);
    network.requests[0].$2.complete({'status': '0'});
    await tester.pumpAndSettle();
    expect(find.text(t.common.loadError), findsOneWidget);
    await tester.ensureVisible(find.text(t.common.buttonRetry));
    await tester.tap(find.text(t.common.buttonRetry));
    await flush(tester);
    expect(network.requests, hasLength(2));
    network.complete(1, ['Recovered']);
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed page keeps results and retries the same page', (
    tester,
  ) async {
    await mount(tester, textScale: 0.5);
    network.complete(0, List.generate(10, (i) => 'Result $i'));
    await tester.pumpAndSettle();
    final load = tester.widget<EasyRefresh>(find.byType(EasyRefresh)).onLoad!;
    unawaited(Future<void>.sync(() async => await load()));
    await flush(tester);
    expect(network.requests[1].$1.queryParameters['page_num'], '2');
    network.requests[1].$2.complete({'status': '0'});
    await tester.pumpAndSettle();
    expect(find.text('Result 0'), findsOneWidget);
    final scroll = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    for (
      var attempt = 0;
      attempt < 4 && find.text(t.common.buttonRetry).evaluate().isEmpty;
      attempt++
    ) {
      scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    final retry = find.ancestor(
      of: find.text(t.common.buttonRetry),
      matching: find.byType(CupertinoButton),
    );
    await tester.ensureVisible(retry);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    await flush(tester);
    expect(network.requests[2].$1.queryParameters['page_num'], '2');
    network.complete(2, ['Next page']);
    await flush(tester);
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 4 && find.text('Next page').evaluate().isEmpty;
      attempt++
    ) {
      scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    expect(find.text('Next page'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('map movement supersedes an in-flight keyword', (tester) async {
    await mount(tester);
    network.complete(0, ['Initial']);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old keyword');
    await flush(tester);
    final map = WebViewPlatform.instance! as FakeWebViewPlatform;
    map.channels['FlutterBridge']!.onMessageReceived(
      const JavaScriptMessage(
        message: '{"type":"moveend","data":{"lat":0.03,"lng":0.04}}',
      ),
    );
    await flush(tester);
    expect(network.requests[2].$1.path, endsWith('/around'));
    network.complete(2, ['Current center']);
    await tester.pumpAndSettle();
    network.complete(1, ['Old keyword']);
    await tester.pumpAndSettle();
    expect(find.text('Current center'), findsOneWidget);
    expect(find.text('Old keyword'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'malformed coordinates display an error without selecting a POI',
    (tester) async {
      await mount(tester);
      network.requests[0].$2.complete({
        'status': '1',
        'pois': [
          {
            'id': 'invalid',
            'name': 'Invalid coordinate',
            'location': 'NaN,Infinity',
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text(t.common.loadError), findsOneWidget);
      expect(find.text('Invalid coordinate'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'only an explicit current selection returns its unchanged payload',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox.shrink()),
      );
      late Future<Map<String, dynamic>?> result;
      await HttpOverrides.runZoned(() async {
        result = navigator.currentState!.push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => MapLocationPicker(
              arguments: {
                'lat': 0.02,
                'lng': 0.01,
                'citycode': '000000',
                'isMapImage': false,
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await flush(tester);
      }, createHttpClient: network.createHttpClient);
      network.complete(0, ['Selected result']);
      await tester.pumpAndSettle();
      final send = find.ancestor(
        of: find.text(t.common.buttonSend),
        matching: find.byType(CupertinoButton),
      );
      expect(tester.widget<CupertinoButton>(send).onPressed, isNull);
      await tester.tap(find.text('Selected result'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();
      final payload = await result;
      expect(payload, containsPair('id', 'Selected result'));
      expect(payload, containsPair('title', 'Selected result'));
      expect(payload!['latitude'], closeTo(0.02, 0.000001));
      expect(payload['longitude'], closeTo(0.01, 0.000001));
      expect(payload['address'], 'Synthetic address');
      expect(payload['image'], isNull);
      expect(network.requests, hasLength(1));
    },
  );

  testWidgets(
    'Unicode keyword is trimmed and whitespace restores nearby search',
    (tester) async {
      await mount(tester);
      network.complete(0, []);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  演示 🧭 %_  ');
      await flush(tester);
      expect(network.requests[1].$1.queryParameters['keywords'], '演示 🧭 %_');
      network.complete(1, []);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await flush(tester);
      expect(network.requests[2].$1.path, endsWith('/around'));
      network.complete(2, []);
      await tester.pumpAndSettle();
      expect(find.text(t.common.searchNoResults), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '$width wide ${scale * 100}% text keeps empty/error actions usable in $brightness',
          (tester) async {
            tester.view.physicalSize = Size(width, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await HttpOverrides.runZoned(
              () => tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: MapLocationPicker(
                    arguments: {
                      'lat': 0.02,
                      'lng': 0.01,
                      'citycode': '000000',
                      'isMapImage': false,
                    },
                  ),
                ),
              ),
              createHttpClient: network.createHttpClient,
            );
            await flush(tester);
            network.complete(0, []);
            await tester.pumpAndSettle();
            expect(find.text(t.common.searchNoResults), findsOneWidget);
            expect(find.text(t.common.pleaseSelectLocation), findsOneWidget);
            final send = find.ancestor(
              of: find.text(t.common.buttonSend),
              matching: find.byType(CupertinoButton),
            );
            expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
            final semantics = tester.ensureSemantics();
            await tester.pump();
            expect(
              tester
                  .getSemantics(find.byType(FloatingActionButton))
                  .getSemanticsData()
                  .label,
              t.common.myLocation,
            );
            final sendData = tester
                .getSemantics(find.bySemanticsLabel(t.common.buttonSend))
                .getSemanticsData();
            expect(sendData.label, t.common.buttonSend);
            expect(sendData.flagsCollection.isButton, isTrue);
            expect(sendData.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
            await tester.enterText(find.byType(TextField), 'synthetic');
            await flush(tester);
            network.requests[1].$2.complete({'status': '0'});
            await tester.pumpAndSettle();
            expect(find.text(t.common.loadError), findsOneWidget);
            await tester.ensureVisible(find.text(t.common.buttonRetry));
            expect(
              find.text(t.common.buttonRetry).hitTestable(),
              findsOneWidget,
            );
            final retry = find.ancestor(
              of: find.text(t.common.buttonRetry),
              matching: find.byType(CupertinoButton),
            );
            expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
            expect(
              tester
                  .getSemantics(find.bySemanticsLabel(t.common.buttonRetry))
                  .getSemanticsData()
                  .label,
              t.common.buttonRetry,
            );
            semantics.dispose();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
