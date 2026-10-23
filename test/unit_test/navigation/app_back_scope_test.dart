import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_back_scope.dart';
import 'package:imboy/theme/default/theme.dart';

void main() {
  testWidgets('child state survives guard, edge and activity changes', (
    tester,
  ) async {
    final mode = ValueNotifier<int>(0);
    addTearDown(mode.dispose);
    await _pump(
      tester,
      home: ValueListenableBuilder<int>(
        valueListenable: mode,
        builder: (_, value, _) => TickerMode(
          enabled: value != 2,
          child: AppBackScope<void>(
            canPop: value == 1,
            edgeGestureEnabled: value != 3,
            onPopInvokedWithResult: (_, _) {},
            child: const Scaffold(body: TextField()),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'unsaved draft');
    for (final value in [1, 0, 3, 0, 2, 0]) {
      mode.value = value;
      await tester.pump();
      expect(
        find.text('unsaved draft'),
        findsOneWidget,
        reason: 'mode $value must preserve the child State',
      );
    }
  });

  testWidgets('edge confirmation can cancel then leave one route', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    var attempts = 0;
    final route = _push(navigator, (didPop, _) async {
      if (didPop) return;
      attempts++;
      final leave = await showCupertinoDialog<bool>(
        context: navigator.currentContext!,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Keep draft?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (leave == true) navigator.currentState!.pop();
    });
    await tester.pumpAndSettle();
    await _swipe(tester);
    expect(find.text('Keep draft?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    await _swipe(tester);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(find.text('Root'), findsOneWidget);
  });

  testWidgets('real async handler excludes repeated edge and system attempts', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    var release = Completer<void>();
    var attempts = 0;
    final route = _push(navigator, (didPop, _) async {
      if (didPop) return;
      attempts++;
      await release.future;
    });
    await tester.pumpAndSettle();
    await _swipe(tester);
    await _swipe(tester);
    await navigator.currentState!.maybePop();
    expect(attempts, 1);
    expect(route.isCurrent, isTrue);
    release.complete();
    await tester.pump();
    release = Completer<void>();
    await _swipe(tester);
    expect(attempts, 2);
    release.complete();
    await tester.pump();
  });

  testWidgets('ordinary route retains native interactive pop', (tester) async {
    final navigator = await _pump(tester);
    final notifications = <bool>[];
    _push(navigator, (didPop, _) => notifications.add(didPop), canPop: true);
    await tester.pumpAndSettle();
    await _swipe(tester);
    expect(notifications, [true]);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('native pop result reaches the typed handler unchanged', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    String? notification;
    final result = navigator.currentState!.push<String>(
      CupertinoPageRoute<String>(
        builder: (_) => AppBackScope<String>(
          canPop: true,
          onPopInvokedWithResult: (didPop, value) {
            if (didPop) notification = value;
          },
          child: const Scaffold(body: Text('Detail')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop('saved');
    await tester.pumpAndSettle();
    expect(await result, 'saved');
    expect(notification, 'saved');
  });

  testWidgets('disabling edge preserves system back handler', (tester) async {
    final navigator = await _pump(tester);
    var attempts = 0;
    _push(navigator, (_, _) => attempts++, edgeGestureEnabled: false);
    await tester.pumpAndSettle();
    await _swipe(tester);
    expect(attempts, 0);
    await navigator.currentState!.maybePop();
    expect(attempts, 1);
  });

  for (final allowAtRoot in [false, true]) {
    testWidgets('root handler requires explicit opt in $allowAtRoot', (
      tester,
    ) async {
      var attempts = 0;
      final navigator = await _pump(
        tester,
        home: AppBackScope<void>(
          canPop: false,
          allowAtRoot: allowAtRoot,
          onPopInvokedWithResult: (_, _) => attempts++,
          child: const Scaffold(body: Text('Root')),
        ),
      );
      await _swipe(tester);
      expect(attempts, allowAtRoot ? 1 : 0);
      expect(navigator.currentState!.canPop(), isFalse);
    });
  }

  testWidgets(
    'short, vertical, body, cancelled and multi touch never attempt',
    (tester) async {
      final navigator = await _pump(tester);
      var attempts = 0;
      _push(navigator, (_, _) => attempts++);
      await tester.pumpAndSettle();
      await _swipe(tester, delta: const Offset(40, 0));
      await _swipe(tester, delta: const Offset(5, 200));
      await _swipe(
        tester,
        start: const Offset(80, 200),
        delta: const Offset(220, 0),
      );
      final cancelled = await tester.startGesture(const Offset(5, 200));
      await cancelled.moveBy(const Offset(160, 0));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      final first = await tester.startGesture(const Offset(5, 200), pointer: 1);
      final second = await tester.startGesture(
        const Offset(200, 400),
        pointer: 2,
      );
      await first.moveBy(const Offset(250, 0));
      await second.up();
      await first.up();
      await tester.pumpAndSettle();
      expect(attempts, 0);
    },
  );

  testWidgets(
    'dialog covering route prevents attempts and cancels active drag',
    (tester) async {
      final navigator = await _pump(tester);
      var attempts = 0;
      _push(navigator, (_, _) => attempts++);
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(const Offset(5, 200));
      await drag.moveBy(const Offset(180, 0));
      showDialog<void>(
        context: navigator.currentContext!,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(content: Text('Covered')),
      );
      await tester.pumpAndSettle();
      await drag.up();
      await tester.pumpAndSettle();
      await _swipe(tester);
      expect(attempts, 0);
      expect(find.text('Covered'), findsOneWidget);
    },
  );

  testWidgets('a route change permanently cancels the current drag', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    var attempts = 0;
    _push(navigator, (_, _) => attempts++);
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(const Offset(5, 200));
    await drag.moveBy(const Offset(180, 0));
    navigator.currentState!.push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await drag.up();
    await tester.pumpAndSettle();
    expect(attempts, 0);
  });

  testWidgets('offstage scope and ticker-disabled scope do not receive edges', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    var attempts = 0;
    final route = _push(
      navigator,
      (didPop, _) {
        if (!didPop) attempts++;
      },
      wrap: (scope) => Stack(
        children: [
          const Scaffold(body: Text('Visible')),
          Offstage(offstage: true, child: scope),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _swipe(tester);
    expect(attempts, 0);
    navigator.currentState!.removeRoute(route);
    _push(navigator, (didPop, _) {
      if (!didPop) attempts++;
    }, wrap: (scope) => TickerMode(enabled: false, child: scope));
    await tester.pumpAndSettle();
    await _swipe(tester);
    expect(attempts, 0);
  });

  testWidgets('ticker-disabled scope permits system pop without an attempt', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    var attempts = 0;
    final route = _push(navigator, (didPop, _) {
      if (!didPop) attempts++;
    }, wrap: (scope) => TickerMode(enabled: false, child: scope));
    await tester.pumpAndSettle();
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(route.isActive, isFalse);
    expect(attempts, 0);
  });

  testWidgets('inactive scope ignores another active scope rejection', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    var outerAttempts = 0;
    var inactiveAttempts = 0;
    _push(
      navigator,
      (_, _) => outerAttempts++,
      child: TickerMode(
        enabled: false,
        child: AppBackScope<void>(
          canPop: false,
          onPopInvokedWithResult: (_, _) => inactiveAttempts++,
          child: const Scaffold(body: Text('Inactive')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await navigator.currentState!.maybePop();
    expect(outerAttempts, 1);
    expect(inactiveAttempts, 0);
  });

  testWidgets('body PageView horizontal navigation is preserved', (
    tester,
  ) async {
    final navigator = await _pump(tester);
    final controller = PageController(initialPage: 1);
    addTearDown(controller.dispose);
    var attempts = 0;
    _push(
      navigator,
      (_, _) => attempts++,
      child: Scaffold(
        body: PageView(
          controller: controller,
          children: const [
            Center(child: Text('First')),
            Center(child: Text('Second')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _swipe(
      tester,
      start: const Offset(80, 200),
      delta: const Offset(270, 0),
    );
    expect(controller.page, 0);
    expect(attempts, 0);
  });

  testWidgets('leading edge follows RTL and ignores mouse input', (
    tester,
  ) async {
    final navigator = await _pump(tester, direction: TextDirection.rtl);
    var attempts = 0;
    _push(navigator, (_, _) => attempts++);
    await tester.pumpAndSettle();
    await _swipe(tester);
    expect(attempts, 0);
    await _swipe(
      tester,
      start: const Offset(385, 200),
      delta: const Offset(-300, 0),
    );
    expect(attempts, 1);
    final mouse = await tester.startGesture(
      const Offset(385, 200),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(-300, 0));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(attempts, 1);
  });
}

Future<GlobalKey<NavigatorState>> _pump(
  WidgetTester tester, {
  Widget home = const Scaffold(body: Text('Root')),
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.getLightTheme().copyWith(
        platform: TargetPlatform.android,
      ),
      builder: (_, child) =>
          Directionality(textDirection: direction, child: child!),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

PageRoute<void> _push(
  GlobalKey<NavigatorState> navigator,
  FutureOr<void> Function(bool, void) onPop, {
  bool canPop = false,
  bool edgeGestureEnabled = true,
  Widget child = const Scaffold(body: Text('Protected')),
  Widget Function(Widget)? wrap,
}) {
  final route = CupertinoPageRoute<void>(
    builder: (_) {
      final scope = AppBackScope<void>(
        canPop: canPop,
        edgeGestureEnabled: edgeGestureEnabled,
        onPopInvokedWithResult: onPop,
        child: child,
      );
      return wrap?.call(scope) ?? scope;
    },
  );
  navigator.currentState!.push<void>(route);
  return route;
}

Future<void> _swipe(
  WidgetTester tester, {
  Offset start = const Offset(5, 200),
  Offset delta = const Offset(300, 0),
}) async {
  await tester.timedDragFrom(start, delta, const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
