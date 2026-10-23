import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/theme/default/theme.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      final scenario = '$platform $brightness';
      for (final cupertino in [false, true]) {
        testWidgets('edge swipe returns pushed route $cupertino $scenario', (
          tester,
        ) async {
          final navigator = await _pumpNavigator(tester, platform, brightness);
          final route = _route(cupertino: cupertino);
          navigator.currentState!.push<void>(route);
          await tester.pumpAndSettle();
          await _swipe(tester);
          expect(route.isActive, isFalse);
          expect(navigator.currentState!.canPop(), isFalse);
        });
      }

      testWidgets('short edge drag cancels without popping $scenario', (
        tester,
      ) async {
        final navigator = await _pumpNavigator(tester, platform, brightness);
        final route = _route();
        navigator.currentState!.push<void>(route);
        await tester.pumpAndSettle();
        await _swipe(tester, distance: 40);
        expect(route.isCurrent, isTrue);
      });

      testWidgets('edge swipe preserves protected route $scenario', (
        tester,
      ) async {
        var rejectedPops = 0;
        final navigator = await _pumpNavigator(tester, platform, brightness);
        final route = _route(
          child: PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) rejectedPops++;
            },
            child: const Scaffold(body: Text('Protected')),
          ),
        );
        navigator.currentState!.push<void>(route);
        await tester.pumpAndSettle();
        await _swipe(tester);
        expect(route.isCurrent, isTrue);
        expect(rejectedPops, 0);
        await navigator.currentState!.maybePop();
        expect(rejectedPops, 1);
        expect(route.isCurrent, isTrue);
      });

      testWidgets('edge swipe cannot pop root $scenario', (tester) async {
        final navigator = await _pumpNavigator(tester, platform, brightness);
        await _swipe(tester);
        expect(find.text('Root'), findsOneWidget);
        expect(navigator.currentState!.canPop(), isFalse);
      });

      for (final cupertino in [false, true]) {
        testWidgets('fullscreen modal stays modal $cupertino $scenario', (
          tester,
        ) async {
          final navigator = await _pumpNavigator(tester, platform, brightness);
          final route = _route(cupertino: cupertino, fullscreenDialog: true);
          navigator.currentState!.push<void>(route);
          await tester.pumpAndSettle();
          await _swipe(tester);
          expect(route.isCurrent, isTrue);
        });
      }

      testWidgets('GoRouter Cupertino page keeps declarative stack $scenario', (
        tester,
      ) async {
        _configureSize(tester);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (_, state) => CupertinoPage<void>(
                key: state.pageKey,
                child: const Scaffold(body: Text('Root')),
              ),
            ),
            GoRoute(
              path: '/detail',
              pageBuilder: (_, state) => CupertinoPage<void>(
                key: state.pageKey,
                child: const Scaffold(body: Text('Detail')),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: _theme(platform, brightness),
            routerConfig: router,
          ),
        );
        router.push<void>('/detail');
        await tester.pumpAndSettle();
        await _swipe(tester);
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(router.canPop(), isFalse);
      });
    }
  }
}

ThemeData _theme(TargetPlatform platform, Brightness brightness) =>
    (brightness == Brightness.dark
            ? AppTheme.getDarkTheme()
            : AppTheme.getLightTheme())
        .copyWith(platform: platform);

void _configureSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<GlobalKey<NavigatorState>> _pumpNavigator(
  WidgetTester tester,
  TargetPlatform platform,
  Brightness brightness,
) async {
  _configureSize(tester);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      theme: _theme(platform, brightness),
      home: const Scaffold(body: Text('Root')),
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

PageRoute<void> _route({
  bool cupertino = false,
  bool fullscreenDialog = false,
  Widget child = const Scaffold(body: Text('Detail')),
}) => cupertino
    ? CupertinoPageRoute<void>(
        fullscreenDialog: fullscreenDialog,
        builder: (_) => child,
      )
    : MaterialPageRoute<void>(
        fullscreenDialog: fullscreenDialog,
        builder: (_) => child,
      );

Future<void> _swipe(WidgetTester tester, {double distance = 300}) async {
  await tester.timedDragFrom(
    const Offset(5, 200),
    Offset(distance, 0),
    const Duration(seconds: 1),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
