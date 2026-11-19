import 'dart:async';
import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/chat_message_list.dart';

/// ChatMessageList 渲染契约测试（TypeA 纯 StatelessWidget）
///
/// 用空 messages 列表，断言 ListView 结构与 reverse 属性，避免依赖
/// flutter_chat_core Message 实例与 message_type_registry 注册。
class _ScreenAnchorFixture {
  final scroll = ScrollController();
  final viewport = GlobalKey();
  final rows = <String, GlobalKey>{};
  final added = <String>[];
  double width = 450, height = 300, top = 0;
  String? longId;
  var own = false;
  Object session = 'session-1';
  ({String id, double y})? initialAnchor;
  ({String id, double y})? observedAnchor;
  bool freezeList = false;
  Widget? _frozenList;

  Widget build() {
    final list = _buildList();
    _frozenList ??= list;
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: SizedBox(
              width: width,
              height: height,
              child: freezeList ? _frozenList! : list,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() => ChatMessageList(
    key: viewport,
    messages: [
      if (own) TextMessage(id: 'own-added', authorId: '1', text: 'own'),
      ...List.generate(
        40,
        (i) => TextMessage(id: 'screen-$i', authorId: '1', text: 'row $i'),
      ),
    ],
    currentUserId: '1',
    scrollController: scroll,
    preserveReadingPosition: true,
    readingSessionKey: session,
    initialReadingAnchor: initialAnchor,
    onReadingAnchor: (value) => observedAnchor = value,
    isCurrent: () => true,
    onNewMessages: (messages, _) => added.addAll(messages.map((m) => m.id)),
    onMessageLongPress: (_) {},
    onMessageDoubleTap: (_) {},
    messageContentBuilder: (_, message, _) => ConstrainedBox(
      key: rows.putIfAbsent(message.id, GlobalKey.new),
      constraints: const BoxConstraints(minHeight: 24),
      child: Text(
        message.id == longId
            ? List.filled(8, 'a real wrapping message ').join()
            : message.id,
      ),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(build());
    final frames = await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(frames, lessThan(20), reason: 'bounded correction must settle');
    expect(tester.takeException(), isNull);
  }

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      scroll.dispose();
    });
    await pump(tester);
    scroll.jumpTo(350);
    await tester.pumpAndSettle();
  }

  Rect rect(String id) {
    final box = rows[id]!.currentContext!.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  String firstVisible() {
    final box = viewport.currentContext!.findRenderObject() as RenderBox;
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    final ids =
        rows.keys
            .where((id) => rows[id]!.currentContext != null)
            .where(
              (id) =>
                  rect(id).bottom > bounds.top && rect(id).top < bounds.bottom,
            )
            .toList()
          ..sort((a, b) => rect(a).top.compareTo(rect(b).top));
    expect(ids, isNotEmpty);
    return ids.first;
  }
}

void main() {
  testWidgets('reading ID and viewport Y survive remount', (tester) async {
    final first = _ScreenAnchorFixture();
    await first.mount(tester);
    final saved = first.observedAnchor;
    expect(saved, isNotNull);
    final id = saved!.id;
    final viewport = tester.getRect(find.byType(ChatMessageList));
    final originalY = first.rect(id).top - viewport.top;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final reopened = _ScreenAnchorFixture()..initialAnchor = saved;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      reopened.scroll.dispose();
    });
    await reopened.pump(tester);
    final nextViewport = tester.getRect(find.byType(ChatMessageList));
    expect(reopened.rows[id]?.currentContext, isNotNull);
    expect(reopened.rect(id).top - nextViewport.top, closeTo(originalY, 1));
  });

  testWidgets('explicit latest cancels an in-flight saved ID seek', (
    tester,
  ) async {
    final f = _ScreenAnchorFixture()..initialAnchor = (id: 'screen-39', y: 35);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      f.scroll.dispose();
    });
    await tester.pumpWidget(f.build());
    expect(f.scroll.offset, greaterThan(0));
    expect(f.rows['screen-39']?.currentContext, isNull);
    f.initialAnchor = null;
    await tester.pumpWidget(f.build());
    f.scroll.jumpTo(f.scroll.position.minScrollExtent);
    await tester.pumpAndSettle();
    expect(f.scroll.offset, closeTo(f.scroll.position.minScrollExtent, 0.01));
  });

  testWidgets('unavailable loaded ID does not force scroll', (tester) async {
    final f = _ScreenAnchorFixture()
      ..initialAnchor = (id: 'missing-message', y: 35);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      f.scroll.dispose();
    });
    await f.pump(tester);
    expect(f.scroll.offset, closeTo(f.scroll.position.minScrollExtent, 0.01));
    expect(f.observedAnchor, isNull);
  });

  for (final coupledHeight in [false, true]) {
    testWidgets(
      'screen anchor survives header origin change height=$coupledHeight',
      (tester) async {
        final f = _ScreenAnchorFixture()
          ..top = 44
          ..freezeList = true;
        await f.mount(tester);
        final id = f.firstVisible();
        final y = f.rect(id).top, offset = f.scroll.offset;
        final element = f.rows[id]!.currentContext;
        f.top = 0;
        if (coupledHeight) f.height += 44;
        await f.pump(tester);
        expect(f.rows[id]!.currentContext, same(element));
        expect(f.rect(id).top, closeTo(y, 1));
        expect(
          f.scroll.offset,
          closeTo(coupledHeight ? offset : offset + 44, 1),
        );
        f.top = 44;
        f.height = 300;
        await f.pump(tester);
        expect(f.rect(id).top, closeTo(y, 1));
        expect(f.scroll.offset, closeTo(offset, 1));
      },
    );
  }

  testWidgets('subpixel viewport animation preserves reading anchor', (
    tester,
  ) async {
    final f = _ScreenAnchorFixture()..freezeList = true;
    await f.mount(tester);
    final id = f.firstVisible();
    final viewport = f.viewport.currentContext!.findRenderObject() as RenderBox;
    final before = f.rect(id).top - viewport.localToGlobal(Offset.zero).dy;
    expect(f.scroll.offset, greaterThan(100));
    final samples = <double>[];
    for (var i = 1; i <= 10; i++) {
      f.height = 300 - i * 0.2;
      await tester.pumpWidget(f.build());
      await tester.pump(const Duration(milliseconds: 16));
      expect(f.rows[id]?.currentContext, isNotNull);
      final box = f.viewport.currentContext!.findRenderObject() as RenderBox;
      samples.add(f.rect(id).top - box.localToGlobal(Offset.zero).dy);
    }
    debugPrintSynchronously(
      'READING_SUBPIXEL_ORACLE ${jsonEncode({'id': id, 'before': before, 'after': samples.last, 'samples': samples, 'heightBefore': 300, 'heightAfter': f.height})}',
    );
    expect(samples.last, closeTo(before, 1));
    for (final y in samples) {
      expect(y, closeTo(before, 1));
    }
  });

  testWidgets('same visible row ID anchors real long-line width reflow', (
    tester,
  ) async {
    final f = _ScreenAnchorFixture();
    await f.mount(tester);
    final id = f.firstVisible();
    final y = f.rect(id).top, shortHeight = f.rect(id).height;
    final element = f.rows[id]!.currentContext;
    f.longId = id;
    await f.pump(tester);
    final wideHeight = f.rect(id).height, wideOffset = f.scroll.offset;
    expect(wideHeight, greaterThan(shortHeight));
    expect(f.rect(id).top, closeTo(y, 1));
    f.width = 230;
    await f.pump(tester);
    expect(f.rows[id]!.currentContext, same(element));
    final viewport = f.viewport.currentContext!.findRenderObject() as RenderBox;
    expect(
      viewport.size.height,
      300,
      reason: 'this is real row reflow, not viewport-height compensation',
    );
    expect(f.rect(id).height, greaterThan(wideHeight));
    expect(f.rect(id).top, closeTo(y, 1));
    f.width = 450;
    await f.pump(tester);
    expect(f.rect(id).top, closeTo(y, 1));
    expect(f.scroll.offset, closeTo(wideOffset, 1));
  });

  for (final ownSend in [true, false]) {
    testWidgets(
      'screen anchor yields to ${ownSend ? 'own send' : 'new session'}',
      (tester) async {
        final f = _ScreenAnchorFixture();
        await f.mount(tester);
        final pixels = f.scroll.offset;
        if (ownSend) {
          f.own = true;
        } else {
          f.session = 'session-2';
        }
        f.height = 275;
        await f.pump(tester);
        expect(
          f.scroll.offset,
          closeTo(pixels, 1),
          reason: 'previous screen anchor must not take control',
        );
        if (ownSend) expect(f.added, contains('own-added'));
      },
    );
  }

  for (final mode in [
    'history',
    'default',
    'stale-owner',
    'near-bottom',
    'drag',
  ]) {
    testWidgets('reverse viewport height correction $mode', (tester) async {
      final scroll = ScrollController();
      final anchor = GlobalKey();
      var current = true;
      final preserve = mode != 'default';
      final nearBottom = mode == 'near-bottom';
      final id = nearBottom ? 'row-0' : 'row-8';
      Widget view(double height) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 350,
              height: height,
              child: ChatMessageList(
                messages: List.generate(
                  40,
                  (i) => TextMessage(
                    id: 'row-$i',
                    authorId: '1',
                    text: 'message $i',
                  ),
                ),
                currentUserId: '1',
                scrollController: scroll,
                targetMsgId: id,
                targetMessageKey: anchor,
                preserveReadingPosition: preserve,
                isCurrent: () => current,
                onMessageLongPress: (_) {},
                onMessageDoubleTap: (_) {},
                messageContentBuilder: (_, message, _) =>
                    SizedBox(height: 48, child: Text(message.id)),
              ),
            ),
          ),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        scroll.dispose();
      });
      await tester.pumpWidget(view(300));
      await tester.pumpAndSettle();
      if (!nearBottom) {
        scroll.jumpTo(350);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(anchor), findsOneWidget);
      final y = tester.getTopLeft(find.byKey(anchor)).dy;
      final pixels = scroll.offset;
      final element = tester.element(find.byKey(anchor));
      if (mode == 'stale-owner') current = false;
      TestGesture? gesture;
      if (mode == 'drag') {
        gesture = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
        expect(scroll.position.isScrollingNotifier.value, isTrue);
      }
      await tester.pumpWidget(view(275));
      if (mode == 'drag') {
        await tester.pump();
        expect(
          scroll.position.isScrollingNotifier.value,
          isTrue,
          reason: 'layout correction must not cancel the active drag',
        );
        await gesture!.cancel();
        await tester.pumpAndSettle();
      } else {
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(anchor)), same(element));
        expect(
          tester.getTopLeft(find.byKey(anchor)).dy,
          closeTo(mode == 'history' ? y : y - 25, 1),
        );
        expect(
          scroll.offset,
          closeTo(mode == 'history' ? pixels + 25 : pixels, 1),
        );
        await tester.pumpWidget(view(300));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(y, 1));
        expect(scroll.offset, closeTo(pixels, 1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            messages: const [],
            currentUserId: 'u1',
            onMessageLongPress: (_) {},
            onMessageDoubleTap: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('空消息列表 → 渲染 ListView 不崩溃', (tester) async {
    await pump(tester);
    expect(find.byType(ChatMessageList), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('列表为 reverse=true（新消息在底部）', (tester) async {
    await pump(tester);
    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.reverse, isTrue);
  });
  testWidgets(
    'Scroll edges dispatch older/newer once while a page is pending',
    (tester) async {
      var older = 0, newer = 0, blocked = false;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageList(
              messages: const [],
              currentUserId: '1',
              onMessageLongPress: (_) {},
              onMessageDoubleTap: (_) {},
              onEndReached: () {
                older++;
                return blocked ? pending.future : Future<void>.value();
              },
              onStartReached: () async {
                newer++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      older = 0;
      blocked = true;
      final context = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .context;
      void finish(double pixels) => ScrollEndNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          pixels: pixels,
          viewportDimension: 400,
          axisDirection: AxisDirection.up,
          devicePixelRatio: 1,
        ),
        context: context,
      ).dispatch(context);
      finish(1000);
      finish(1000);
      await tester.pump();
      expect(older, 1);
      pending.complete();
      await tester.pump();
      finish(500);
      await tester.pump();
      expect(older, 1);
      finish(0);
      await tester.pump();
      expect(newer, 1);
    },
  );
  testWidgets(
    'Real ListView scroll extents trigger bounded older/newer requests',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final pending = Completer<void>();
      var older = 0, newer = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: ChatMessageList(
                messages: List.generate(
                  40,
                  (i) => TextMessage(
                    id: 'message-$i',
                    authorId: '1',
                    text: 'row $i\nsecond line\nthird line',
                  ),
                ),
                currentUserId: '1',
                scrollController: scroll,
                onMessageLongPress: (_) {},
                onMessageDoubleTap: (_) {},
                onEndReached: () {
                  older++;
                  return pending.future;
                },
                onStartReached: () async {
                  newer++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(older, 1);
      scroll.jumpTo(0);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(older, 1);
      pending.complete();
      await tester.pump();
      scroll.jumpTo(0);
      await tester.pump();
      expect(newer, 1);
    },
  );
}
