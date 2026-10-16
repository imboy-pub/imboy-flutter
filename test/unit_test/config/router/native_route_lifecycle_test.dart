import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
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

void main() {
  setUpAll(() {
    installSmokeHttpOverrides();
    MessageService.instance;
  });
  tearDownAll(() => MessageService.instance.dispose());
  setUp(prepareSmokeEnv);

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
