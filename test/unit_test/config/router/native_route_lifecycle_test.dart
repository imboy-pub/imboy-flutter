import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart' as api;
import 'package:imboy/config/init.dart' show serviceContainer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_page.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
import 'package:imboy/page/contact/people_info/people_info_provider.dart';
import 'package:imboy/page/web_shell/web_shell_page.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/component/location/widget.dart';
import 'package:imboy/service/message.dart';
// 原生边界测试复用 webview_flutter 已锁定的平台接口。
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../helper/fake_webview_platform.dart';
import '../../smoke/route_registry.dart';
import '../../smoke/smoke_test_harness.dart';

class _UnrelatedPerson extends PeopleInfoNotifier {
  @override
  PeopleInfoState build() => const PeopleInfoState(nickname: 'Fixture peer');

  @override
  Future<void> initData(String id, String scene) async {}
}

class _FriendResponseAdapter implements HttpClientAdapter {
  _FriendResponseAdapter(this.delegate, {this.responseGate});
  final HttpClientAdapter delegate;
  final Completer<void>? responseGate;
  int completed = 0;
  String? to;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    if (options.method != 'POST' || !options.uri.path.endsWith('/friend/add')) {
      return delegate.fetch(options, body, cancelFuture);
    }
    final chunks = <int>[];
    if (body != null) {
      await for (final chunk in body) {
        chunks.addAll(chunk);
      }
    }
    final data = utf8.decode(chunks);
    final fields = options.contentType?.contains('json') == true
        ? Map<String, dynamic>.from(jsonDecode(data) as Map)
        : Uri.splitQueryString(data);
    to = fields['to']?.toString();
    completed++;
    await responseGate?.future;
    return ResponseBody.fromString(
      '{"code":0,"msg":"success","payload":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() {
    installSmokeHttpOverrides();
    MessageService.instance;
  });
  tearDownAll(() => MessageService.instance.dispose());
  setUp(prepareSmokeEnv);

  testWidgets('friend apply returns to the existing shell before mine', (
    tester,
  ) async {
    await _checkFriendRouteReturn(tester);
  });

  testWidgets('friend apply from a root profile returns to the native shell', (
    tester,
  ) async {
    await _checkFriendRouteReturn(tester, rootProfile: true);
  });

  testWidgets('friend apply completion leaves a newer route untouched', (
    tester,
  ) async {
    await _checkFriendRouteReturn(tester, coverWhileWaiting: true);
  });

  for (final name in ['live_room_publisher', 'live_room_subscriber']) {
    testWidgets('$name unload stops the renderer before releasing it', (
      tester,
    ) async {
      final calls = mockSmokeVideoRenderer();
      final route = smokeRoutes.singleWhere((route) => route.name == name);
      expect(await renderRoute(tester, route), isNull);

      expect(
        calls.where((call) => call == 'createVideoRenderer'),
        hasLength(1),
      );
      expect(
        calls.where((call) => call == 'videoRendererDispose'),
        hasLength(1),
        reason: calls.join(', '),
      );
      expect(calls.indexOf('videoRendererSetSrcObject'), greaterThan(-1));
      expect(
        calls.indexOf('videoRendererSetSrcObject'),
        lessThan(calls.indexOf('videoRendererDispose')),
      );
    });
  }

  for (final name in ['live_room_publisher', 'live_room_subscriber']) {
    testWidgets('$name closes safely before native initialization completes', (
      tester,
    ) async {
      final gate = Completer<void>();
      final calls = mockSmokeVideoRenderer(createRendererGate: gate.future);
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final route = smokeRoutes.singleWhere((route) => route.name == name);
      expect(await renderRoute(tester, route), isNull);
      expect(calls, isNot(contains('videoRendererDispose')));
      gate.complete();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(
        calls.where((call) => call == 'videoRendererDispose'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'map bridge accepts a move event while the real page is mounted',
    (tester) async {
      final platform = FakeWebViewPlatform();
      final previous = WebViewPlatform.instance;
      WebViewPlatform.instance = platform;
      if (previous != null) {
        addTearDown(() => WebViewPlatform.instance = previous);
      }
      final container = ProviderContainer();
      final router = createAppRouter(
        initialLocation: '/map_location_picker',
        navigatorKeyOverride: GlobalKey<NavigatorState>(),
      );
      addTearDown(router.dispose);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildRouterApp(router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MapLocationPicker), findsOneWidget);
      expect(
        find.byKey(const ValueKey('fake-webview-surface')),
        findsOneWidget,
      );
      final locationButton = find.byIcon(CupertinoIcons.location);
      expect(tester.widget<Icon>(locationButton).color, AppColors.primary);
      platform.channels['FlutterBridge']!.onMessageReceived(
        const JavaScriptMessage(
          message: '{"type":"moveend","data":{"lat":39.9,"lng":116.4}}',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Icon>(locationButton).color, AppColors.iosGray);
      expect(find.byType(MapLocationPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'map route mounts its real page and configures the WebView bridge',
    (tester) async {
      final route = smokeRoutes.singleWhere(
        (route) => route.name == 'map_location_picker',
      );
      expect(await renderRoute(tester, route), isNull);
      final platform = WebViewPlatform.instance! as FakeWebViewPlatform;
      expect(platform.html, contains('new AMap.Map'));
      final center = RegExp(r'center: \[([^,]+), ([^\]]+)\]')
          .firstMatch(platform.html!)!;
      expect(double.parse(center[1]!), closeTo(116.397451, 1e-6));
      expect(double.parse(center[2]!), closeTo(39.909187, 1e-6));
      expect(platform.channels, contains('FlutterBridge'));
    },
  );
}

Future<void> _checkFriendRouteReturn(
  WidgetTester tester, {
  bool rootProfile = false,
  bool coverWhileWaiting = false,
}) async {
  _installConnectivityFixture();
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  final client = serviceContainer.get<api.HttpClient>();
  final oldAdapter = client.dio.httpClientAdapter;
  final gate = coverWhileWaiting ? Completer<void>() : null;
  final adapter = _FriendResponseAdapter(oldAdapter, responseGate: gate);
  client.dio.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [peopleInfoProvider.overrideWith(_UnrelatedPerson.new)],
  );
  final router = createAppRouter(
    initialLocation: '/web_shell?tab=chat',
    navigatorKeyOverride: GlobalKey<NavigatorState>(),
  );
  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildRouterApp(router),
      ),
    );
    await _exerciseFriendReturn(
      tester,
      router,
      adapter,
      rootProfile: rootProfile,
      gate: gate,
    );
  } finally {
    if (gate != null && !gate.isCompleted) gate.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    client.dio.httpClientAdapter = oldAdapter;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

Future<void> _exerciseFriendReturn(
  WidgetTester tester,
  GoRouter router,
  _FriendResponseAdapter adapter, {
  required bool rootProfile,
  Completer<void>? gate,
}) async {
  await _checkedFrames(tester, 32);
  final shellState = tester.state(find.byType(WebShellPage));
  if (rootProfile) {
    router.go('/people_info/123');
  } else {
    router.push('/people_info/123');
  }
  await _checkedFrames(tester, 32);
  expect(find.byType(PeopleInfoPage), findsOneWidget);
  await tester.ensureVisible(find.text(t.common.addToContacts));
  await tester.tap(find.text(t.common.addToContacts));
  await _checkedFrames(tester, 32);
  expect(find.byType(ApplyFriendPage), findsOneWidget);
  await tester.tap(find.text(t.common.buttonSend));
  if (gate != null) {
    await _checkCoveredApplyCompletion(tester, router, adapter, gate);
    return;
  }
  await _waitForApplyAndReturn(
    tester,
    router,
    adapter,
    destination: rootProfile ? '/bottom_navigation' : '/web_shell',
  );
  if (!rootProfile) {
    expect(
      identical(tester.state(find.byType(WebShellPage)), shellState),
      isTrue,
    );
  }
  router.go('/web_shell?tab=mine');
  await _checkedFrames(tester, 40);
  expect(
    router.routeInformationProvider.value.uri.queryParameters['tab'],
    'mine',
  );
  expect(find.byType(WebShellPage), findsOneWidget);
  if (!rootProfile) {
    expect(
      identical(tester.state(find.byType(WebShellPage)), shellState),
      isTrue,
    );
  }
  expect(find.byType(ErrorWidget), findsNothing);
}

Future<void> _checkCoveredApplyCompletion(
  WidgetTester tester,
  GoRouter router,
  _FriendResponseAdapter adapter,
  Completer<void> gate,
) async {
  // 请求发出即挂起在 responseGate 上：真实异步（dio 握手）可能不止一跳
  // 微任务。对齐 _waitForApplyAndReturn 的 Stopwatch 预算式轮询，避免固定
  // 跳数在 CI 慢机上超窗（2026-11-21 scheduled run 44956962746 实测连坐
  // 64 target 的根因）。
  final requested = Stopwatch()..start();
  while (requested.elapsed < const Duration(seconds: 30) &&
      adapter.completed == 0) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await _checkedFrames(tester, 1);
  }
  expect(adapter.completed, 1);
  expect(adapter.to, '123');
  const coverKey = ValueKey('friend-apply-cover');
  final requestElement = tester.element(find.byType(ApplyFriendPage));
  final requestRoute = ModalRoute.of(requestElement)!;
  final topRoute = CupertinoPageRoute<void>(
    builder: (_) => const CupertinoPageScaffold(
      child: Center(child: Text('Route ownership cover', key: coverKey)),
    ),
  );
  Navigator.of(requestElement).push(topRoute);
  await _waitForApplyCover(tester, requestRoute, topRoute);
  expect(requestRoute.isCurrent, isFalse);
  expect(topRoute.isCurrent, isTrue);
  expect(find.byType(ApplyFriendPage, skipOffstage: false), findsOneWidget);
  expect(find.byType(ApplyFriendPage), findsNothing);
  final coverElement = tester.element(find.byKey(coverKey));
  expect(ModalRoute.of(coverElement), same(topRoute));
  final topUri = router.routeInformationProvider.value.uri;
  gate.complete();
  final restoredSend = find.descendant(
    of: find.byType(ApplyFriendPage, skipOffstage: false),
    matching: find.text(t.common.buttonSend, skipOffstage: false),
    skipOffstage: false,
  );
  // gate 释放后的成功链路穿过真实异步（dio 解析 → NewFriendRepo 落库
  // （sqlite ffi 隔离线程）→ finally setState）。固定 100 跳 ≈1s 在 CI
  // 负载下偶发不够（同上 run 实测 0 命中）；对齐 _waitForApplyAndReturn
  // 的 30s Stopwatch 真实预算，帧推进与异常断言不变。
  final restored = Stopwatch()..start();
  while (restored.elapsed < const Duration(seconds: 30) &&
      restoredSend.evaluate().isEmpty) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await _checkedFrames(tester, 1);
  }
  expect(
    restoredSend,
    findsOneWidget,
    reason: 'Offstage request page must finish its successful async action',
  );
  expect(router.routeInformationProvider.value.uri, topUri);
  expect(find.byType(ApplyFriendPage), findsNothing);
  expect(topRoute.isCurrent, isTrue);
  expect(requestRoute.isCurrent, isFalse);
  expect(identical(tester.element(find.byKey(coverKey)), coverElement), isTrue);
  expect(adapter.completed, 1);
  expect(find.byType(ErrorWidget), findsNothing);
}

Future<void> _waitForApplyCover(
  WidgetTester tester,
  ModalRoute<dynamic> requestRoute,
  CupertinoPageRoute<void> topRoute,
) async {
  final request = find.byType(ApplyFriendPage);
  for (
    var i = 0;
    i < 100 &&
        (topRoute.animation?.status != AnimationStatus.completed ||
            request.evaluate().isNotEmpty);
    i++
  ) {
    await _checkedFrames(tester, 1);
  }
  final flags =
      'opaque=${topRoute.opaque}, '
      'overlayFirstOpaque=${topRoute.overlayEntries.isNotEmpty && topRoute.overlayEntries.first.opaque}, '
      'requestCurrent=${requestRoute.isCurrent}, topCurrent=${topRoute.isCurrent}, '
      'animation=${topRoute.animation?.status}';
  expect(topRoute.animation?.status, AnimationStatus.completed, reason: flags);
  expect(request, findsNothing, reason: flags);
}

Future<void> _waitForApplyAndReturn(
  WidgetTester tester,
  GoRouter router,
  _FriendResponseAdapter adapter, {
  String destination = '/web_shell',
}) async {
  final wait = Stopwatch()..start();
  while (wait.elapsed < const Duration(seconds: 30)) {
    // Give host I/O a real-time budget and keep pumping until both departing
    // routes are disposed; a fixed frame count can expire during their exit.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await _checkedFrames(tester, 1);
    if (adapter.completed == 1 &&
        find.byType(ApplyFriendPage, skipOffstage: false).evaluate().isEmpty &&
        find.byType(PeopleInfoPage, skipOffstage: false).evaluate().isEmpty &&
        router.routeInformationProvider.value.uri.path == destination) {
      break;
    }
  }
  expect(adapter.completed, 1);
  expect(adapter.to, '123');
  expect(find.byType(ApplyFriendPage, skipOffstage: false), findsNothing);
  expect(find.byType(PeopleInfoPage, skipOffstage: false), findsNothing);
  expect(router.routeInformationProvider.value.uri.path, destination);
  expect(find.byType(ErrorWidget), findsNothing);
}

Future<void> _checkedFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
}

void _installConnectivityFixture() {
  const method = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const events = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(method, (call) async {
    if (call.method == 'check') return <String>['wifi'];
    throw MissingPluginException('Unexpected connectivity method');
  });
  // ConversationPage.initData subscribes after check; no events are emitted.
  messenger.setMockMethodCallHandler(events, (call) async {
    if (call.method == 'listen' || call.method == 'cancel') return null;
    throw MissingPluginException('Unexpected connectivity event method');
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(events, null);
  });
}
