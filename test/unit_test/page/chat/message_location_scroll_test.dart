import 'package:flutter/widgets.dart';
import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';

void main() {
  test('scroll errors reach the caller instead of claiming success', () async {
    final provider = Provider<SqliteChatService>(SqliteChatService.new);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(provider);
    addTearDown(service.dispose);
    service.attachScrollMethods(
      scrollToMessageId:
          (
            id, {
            duration = Duration.zero,
            curve = Curves.linear,
            alignment = 0,
            offset = 0,
          }) async {
            throw StateError('scroll failed');
          },
      scrollToIndex: (
        index, {
        duration = Duration.zero,
        curve = Curves.linear,
        alignment = 0,
        offset = 0,
      }) async {},
    );
    await expectLater(service.scrollToMessage('target'), throwsStateError);
  });
  for (final reversed in [false, true]) {
    testWidgets('MSG05 manager bottom respects reversed=$reversed', (
      tester,
    ) async {
      final scope = ProviderContainer();
      final subscription = scope.listen(
        messageScrollManagerProvider,
        (_, _) {},
      );
      final controller = ScrollController();
      final manager = scope.read(messageScrollManagerProvider.notifier);
      if (reversed) {
        manager.attachScrollController(controller, reversed: true);
      } else {
        // Exercise the unchanged Native default rather than an explicit false.
        manager.attachScrollController(controller);
      }
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ListView(
              controller: controller,
              reverse: reversed,
              children: List.generate(40, (_) => const SizedBox(height: 80)),
            ),
          ),
        );
        final bottom = reversed
            ? controller.position.minScrollExtent
            : controller.position.maxScrollExtent;
        controller.jumpTo(reversed ? bottom + 101 : bottom - 101);
        expect(scope.read(messageScrollManagerProvider).isAtBottom, false);
        controller.jumpTo(reversed ? bottom + 100 : bottom - 100);
        expect(scope.read(messageScrollManagerProvider).isAtBottom, true);
        controller.jumpTo(reversed ? bottom + 250 : bottom - 250);
        await manager.scrollToBottom(animated: false);
        expect(controller.offset, bottom);
        expect(scope.read(messageScrollManagerProvider).isAtBottom, true);
        manager.detachScrollController(controller);
        final detached = scope.read(messageScrollManagerProvider);
        controller.jumpTo(reversed ? bottom + 250 : bottom - 250);
        expect(
          identical(scope.read(messageScrollManagerProvider), detached),
          true,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        manager.detachScrollController(controller);
        subscription.close();
        scope.dispose();
        controller.dispose();
      }
    });
  }
  for (final reversed in [false, true]) {
    testWidgets(
      'MSG05 interrupted return checks real position reversed=$reversed',
      (tester) async {
        final scope = ProviderContainer();
        final subscription = scope.listen(
          messageScrollManagerProvider,
          (_, _) {},
        );
        final controller = ScrollController();
        final manager = scope.read(messageScrollManagerProvider.notifier);
        manager.attachScrollController(controller, reversed: reversed);
        TestGesture? gesture;
        try {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: ListView(
                controller: controller,
                reverse: reversed,
                children: List.generate(40, (_) => const SizedBox(height: 80)),
              ),
            ),
          );
          final bottom = reversed
              ? controller.position.minScrollExtent
              : controller.position.maxScrollExtent;
          controller.jumpTo(reversed ? bottom + 1200 : bottom - 1200);
          final returning = manager.scrollToBottom();
          await tester.pump(const Duration(milliseconds: 60));
          gesture = await tester.startGesture(
            tester.getCenter(find.byType(ListView)),
          );
          await tester.pump();
          await returning;
          expect((controller.offset - bottom).abs(), greaterThan(100));
          expect(scope.read(messageScrollManagerProvider).isAtBottom, false);
        } finally {
          await gesture?.up();
          await tester.pumpWidget(const SizedBox.shrink());
          manager.detachScrollController(controller);
          subscription.close();
          scope.dispose();
          controller.dispose();
        }
      },
    );
  }
}
