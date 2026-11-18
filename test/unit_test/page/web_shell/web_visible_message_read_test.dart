import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:imboy/page/web_shell/web_visible_message_read.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<void> show(
    WidgetTester tester, {
    required Future<bool> Function() onRead,
    bool Function()? current,
    bool enabled = true,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebVisibleMessageRead(
          enabled: enabled,
          fraction: .6,
          delayMs: 400,
          isCurrent: current ?? () => true,
          onRead: onRead,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
  }

  void visible(WidgetTester tester, double fraction) {
    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged!(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(100, 100),
        visibleBounds: Rect.fromLTWH(0, 0, 100, 100 * fraction),
      ),
    );
  }

  testWidgets('only continuous threshold visibility commits once', (
    tester,
  ) async {
    var calls = 0;
    await show(
      tester,
      onRead: () async {
        calls++;
        return true;
      },
    );
    visible(tester, .5);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);
    visible(tester, 1);
    await tester.pump(const Duration(milliseconds: 399));
    expect(calls, 0);
    visible(tester, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 0);
    visible(tester, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    visible(tester, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled, expired owner, and dispose never commit', (
    tester,
  ) async {
    var calls = 0;
    var current = true;
    await show(
      tester,
      enabled: false,
      onRead: () async {
        calls++;
        return true;
      },
    );
    visible(tester, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    await show(
      tester,
      current: () => current,
      onRead: () async {
        calls++;
        return true;
      },
    );
    visible(tester, 1);
    current = false;
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 0);
    current = true;
    visible(tester, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);
  });

  testWidgets('background cancels delay; resume requires a new full delay', (
    tester,
  ) async {
    var calls = 0;
    await show(
      tester,
      onRead: () async {
        calls++;
        return true;
      },
    );
    visible(tester, 1);
    await tester.pump(const Duration(milliseconds: 200));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 399));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in-flight commit is not duplicated by visibility changes', (
    tester,
  ) async {
    var calls = 0;
    final done = Completer<bool>();
    await show(
      tester,
      onRead: () {
        calls++;
        return done.future;
      },
    );
    visible(tester, 1);
    await tester.pump(const Duration(milliseconds: 400));
    visible(tester, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    done.complete(true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'transient failure retries while visible and stops at three attempts',
    (tester) async {
      var calls = 0;
      await show(
        tester,
        onRead: () async {
          calls++;
          return calls > 1;
        },
      );
      visible(tester, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      calls = 0;
      await show(
        tester,
        onRead: () async {
          calls++;
          return false;
        },
      );
      visible(tester, 1);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(calls, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('retry cannot cross owner change or hidden lifecycle', (
    tester,
  ) async {
    var current = true;
    var calls = 0;
    await show(
      tester,
      current: () => current,
      onRead: () async {
        calls++;
        return false;
      },
    );
    visible(tester, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    current = false;
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    current = true;
    await show(
      tester,
      onRead: () async {
        calls++;
        return false;
      },
    );
    visible(tester, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'burn scheduling follows read success and cannot cross owner change',
    () async {
      var current = true;
      final events = <String>[];
      expect(
        await commitWebVisibleMessageRead(
          isCurrent: () => current,
          markRead: () async {
            events.add('read');
            return true;
          },
          markBurnRead: () async {
            events.add('burn');
            return true;
          },
        ),
        isTrue,
      );
      expect(events, ['read', 'burn']);
      events.clear();
      expect(
        await commitWebVisibleMessageRead(
          isCurrent: () => current,
          markRead: () async {
            events.add('read');
            return false;
          },
          markBurnRead: () async {
            events.add('burn');
            return true;
          },
        ),
        isFalse,
      );
      expect(events, ['read']);
      events.clear();
      expect(
        await commitWebVisibleMessageRead(
          isCurrent: () => current,
          markRead: () async {
            events.add('read');
            current = false;
            return true;
          },
          markBurnRead: () async {
            events.add('burn');
            return true;
          },
        ),
        isFalse,
      );
      expect(events, ['read']);
      events.clear();
      expect(
        await commitWebVisibleMessageRead(
          isCurrent: () => current,
          markRead: () async {
            events.add('read');
            return true;
          },
          markBurnRead: () async {
            events.add('burn');
            return true;
          },
        ),
        isFalse,
      );
      expect(events, isEmpty);
    },
  );
  testWidgets(
    'read succeeds but burn fails: retry completes expiry before committing',
    (tester) async {
      var reads = 0;
      var burns = 0;
      await show(
        tester,
        onRead: () => commitWebVisibleMessageRead(
          isCurrent: () => true,
          markRead: () async {
            reads++;
            return true;
          },
          markBurnRead: () async {
            burns++;
            return burns > 1;
          },
        ),
      );
      visible(tester, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(reads, 1);
      expect(burns, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(reads, 2);
      expect(burns, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(reads, 2);
      expect(burns, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'scrolling offscreen during throttled notification cannot mark read',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final top = ValueNotifier<double>(0);
      var calls = 0;
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<double>(
              valueListenable: top,
              builder: (_, y, _) => Stack(
                children: [
                  Positioned(
                    top: y,
                    left: 0,
                    width: 100,
                    height: 100,
                    child: WebVisibleMessageRead(
                      enabled: true,
                      fraction: .6,
                      delayMs: 400,
                      isCurrent: () => true,
                      onRead: () async {
                        calls++;
                        return true;
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 50));
        top.value = 10000;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(calls, 0);
      } finally {
        await tester.pumpWidget(const SizedBox());
        VisibilityDetectorController.instance.notifyNow();
        await tester.pump(const Duration(seconds: 1));
        top.dispose();
      }
    },
  );
  testWidgets(
    'offscreen and back during throttle restarts continuous visibility delay',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final top = ValueNotifier<double>(0);
      var calls = 0;
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<double>(
              valueListenable: top,
              builder: (_, y, _) => Stack(
                children: [
                  Positioned(
                    top: y,
                    left: 0,
                    width: 100,
                    height: 100,
                    child: WebVisibleMessageRead(
                      enabled: true,
                      fraction: .6,
                      delayMs: 400,
                      isCurrent: () => true,
                      onRead: () async {
                        calls++;
                        return true;
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 50));
        top.value = 10000;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        top.value = 0;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(calls, 0);
      } finally {
        await tester.pumpWidget(const SizedBox());
        VisibilityDetectorController.instance.notifyNow();
        await tester.pump(const Duration(seconds: 1));
        top.dispose();
      }
    },
  );
}
