// Isolated real-device navigation tests; never starts the production bootstrap.
// Build this target as a standalone debug APK, install the owned flavor with
// adb install --no-streaming, then use the existing IntegrationDriver.
// Verify the flavor's applicationId and device occupancy before installing.
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/app_back_scope.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/theme.dart';

import '../test/env_test_pin.dart';

final _screen = GlobalKey();

class _DenyNetwork extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) =>
      throw StateError('Network access is forbidden in the edge-back fixture');
}

class _StackObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  int pagePops = 0;

  List<String?> get names =>
      routes.map((route) => route.settings.name).toList();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    if (route is PageRoute) pagePops++;
  }
}

class _Fixture {
  final navigator = GlobalKey<NavigatorState>();
  final observer = _StackObserver();
  final pages = PageController(initialPage: 1);
  int confirmCalls = 0;
  int rootAttempts = 0;
  Completer<void>? confirmationGate;

  Future<void> mount(WidgetTester tester) async {
    addTearDown(pages.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: RepaintBoundary(
          key: _screen,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getLightTheme(),
            navigatorKey: navigator,
            navigatorObservers: [observer],
            home: AppBackScope<void>(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) rootAttempts++;
              },
              child: const _FixturePage(title: '根页面'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(observer.names, ['/']);
  }

  Future<void> push(
    WidgetTester tester, {
    bool cupertino = false,
    bool guarded = false,
    bool pageView = false,
  }) async {
    final name = guarded ? '/guarded' : '/detail';
    Widget builder(BuildContext context) => AppBackScope<void>(
      canPop: !guarded,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirm(context);
      },
      child: _FixturePage(
        title: guarded ? '有未保存内容' : '详情页面',
        body: pageView
            ? PageView(
                key: const ValueKey('fixture-pages'),
                controller: pages,
                children: const [
                  Center(child: Text('页面 A')),
                  Center(child: Text('页面 B')),
                ],
              )
            : null,
      ),
    );
    final settings = RouteSettings(name: name);
    navigator.currentState!.push<void>(
      cupertino
          ? CupertinoPageRoute<void>(settings: settings, builder: builder)
          : MaterialPageRoute<void>(settings: settings, builder: builder),
    );
    await tester.pumpAndSettle();
    expect(observer.names, ['/', name]);
    expect(navigator.currentState!.canPop(), isTrue);
  }

  Future<void> _confirm(BuildContext context) async {
    confirmCalls++;
    if (confirmationGate != null) await confirmationGate!.future;
    if (!context.mounted) return;
    final leave = await showCupertinoDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: '/confirm'),
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('放弃未保存的内容？'),
        content: const Text('这是隔离导航测试，不会修改业务数据。'),
        actions: [
          CupertinoDialogAction(
            key: const ValueKey('guard-stay'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留'),
          ),
          CupertinoDialogAction(
            key: const ValueKey('guard-leave'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('离开'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) Navigator.of(context).pop();
  }
}

class _FixturePage extends StatelessWidget {
  const _FixturePage({required this.title, this.body});
  final String title;
  final Widget? body;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body:
        body ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.regular),
            child: Text(title),
          ),
        ),
  );
}

Future<TestGesture> _dragTo(
  WidgetTester tester,
  double fraction, {
  bool body = false,
}) async {
  final bounds = tester.getRect(find.byKey(_screen));
  final gesture = await tester.startGesture(
    Offset(body ? bounds.width * .25 : bounds.left + 2, bounds.height * .6),
  );
  await gesture.moveBy(
    const Offset(24, 0),
    timeStamp: const Duration(milliseconds: 80),
  );
  await tester.pump(const Duration(milliseconds: 80));
  await gesture.moveBy(
    Offset(bounds.width * fraction - 24, 0),
    timeStamp: const Duration(milliseconds: 380),
  );
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

Future<void> _swipe(
  WidgetTester tester, {
  double fraction = .68,
  bool body = false,
}) async {
  final gesture = await _dragTo(tester, fraction, body: body);
  await gesture.up(timeStamp: const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> takeScreenshot(WidgetTester tester, String name) async {
  final image = await tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_screen))
      .toImage();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final encoded = base64Encode(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('[EDGE_PNG_BEGIN:$name:${encoded.length}]');
    for (var offset = 0; offset < encoded.length; offset += 800) {
      // ignore: avoid_print
      print(
        '[EDGE_PNG:$name:$offset]'
        '${encoded.substring(offset, math.min(offset + 800, encoded.length))}',
      );
    }
    // ignore: avoid_print
    print('[EDGE_PNG_END:$name:${encoded.length}]');
  } finally {
    image.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final previousHttpOverrides = io.HttpOverrides.current;
  late _Fixture fixture;

  setUpAll(() {
    pinLoopbackTestEnv();
    io.HttpOverrides.global = _DenyNetwork();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
    fixture = _Fixture();
  });
  tearDownAll(() => io.HttpOverrides.global = previousHttpOverrides);

  testWidgets('Android Material push: edge drag pops exactly one route', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.push(tester);
    final gesture = await _dragTo(tester, .3);
    expect(fixture.observer.names, ['/', '/detail']);
    expect(fixture.observer.pagePops, 0);
    await takeScreenshot(tester, 'edge_back_drag_progress');
    await gesture.moveBy(
      Offset(tester.getSize(find.byKey(_screen)).width * .38, 0),
      timeStamp: const Duration(milliseconds: 650),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(fixture.observer.names, ['/']);
    expect(fixture.observer.pagePops, 1);
    expect(fixture.navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cupertino push: edge drag pops exactly one route', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.push(tester, cupertino: true);
    await _swipe(tester);
    expect(fixture.observer.names, ['/']);
    expect(fixture.observer.pagePops, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short edge drag cancels and preserves the detail route', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.push(tester);
    await _swipe(tester, fraction: .1);
    expect(fixture.observer.names, ['/', '/detail']);
    expect(fixture.observer.pagePops, 0);
    expect(fixture.navigator.currentState!.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guard cancellation preserves the page and its route', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.push(tester, guarded: true);
    await _swipe(tester);
    expect(fixture.observer.names, ['/', '/guarded', '/confirm']);
    await takeScreenshot(tester, 'edge_back_guard_confirmation');
    await _choose(tester, 'guard-stay');
    expect(fixture.confirmCalls, 1);
    expect(fixture.observer.names, ['/', '/guarded']);
    expect(fixture.observer.pagePops, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guard confirmation removes the page only after approval', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.push(tester, guarded: true, cupertino: true);
    await _swipe(tester);
    expect(fixture.observer.names, ['/', '/guarded', '/confirm']);
    expect(fixture.observer.pagePops, 0);
    await _choose(tester, 'guard-leave');
    expect(fixture.confirmCalls, 1);
    expect(fixture.observer.names, ['/']);
    expect(fixture.observer.pagePops, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated edge gestures do not duplicate a pending guard', (
    tester,
  ) async {
    await fixture.mount(tester);
    fixture.confirmationGate = Completer<void>();
    await fixture.push(tester, guarded: true);
    await _swipe(tester);
    await _swipe(tester);
    expect(fixture.confirmCalls, 1);
    expect(fixture.observer.names, ['/', '/guarded']);
    fixture.confirmationGate!.complete();
    await tester.pumpAndSettle();
    expect(fixture.observer.names, ['/', '/guarded', '/confirm']);
    await _choose(tester, 'guard-stay');
    expect(fixture.observer.names, ['/', '/guarded']);
    expect(fixture.observer.pagePops, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('root edge gesture neither pops nor invokes a guard', (
    tester,
  ) async {
    await fixture.mount(tester);
    await _swipe(tester);
    expect(fixture.observer.names, ['/']);
    expect(fixture.observer.pagePops, 0);
    expect(fixture.rootAttempts, 0);
    expect(fixture.navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('body PageView drag changes page without navigation or guard', (
    tester,
  ) async {
    await fixture.mount(tester);
    await fixture.push(tester, guarded: true, pageView: true);
    expect(fixture.pages.page, 1);
    await _swipe(tester, fraction: .65, body: true);
    expect(fixture.pages.page, 0);
    expect(fixture.observer.names, ['/', '/guarded']);
    expect(fixture.observer.pagePops, 0);
    expect(fixture.confirmCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
