import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';

Future<(GlobalKey<NavigatorState>, PageController)> _mountGallery(
  WidgetTester tester,
) async {
  final navigator = GlobalKey<NavigatorState>();
  final controller = PageController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('previous page')),
    ),
  );
  navigator.currentState!.push(
    CupertinoPageRoute<void>(
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('chat body')),
                IMBoyImageGallery(
                  images: const [
                    PreviewImage(id: 'one', uri: ''),
                    PreviewImage(id: 'two', uri: ''),
                  ],
                  pageController: controller,
                  onClosePressed: () => setState(() {}),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (navigator, controller);
}

void main() {
  for (final useEdge in [false, true]) {
    testWidgets(
      'gallery ${useEdge ? 'left edge' : 'system back'} invokes local close without exiting',
      (tester) async {
        var platformPops = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'SystemNavigator.pop') platformPops++;
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final navigator = GlobalKey<NavigatorState>();
        final controller = PageController();
        addTearDown(controller.dispose);
        var closes = 0;
        var visible = true;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('previous page')),
          ),
        );
        navigator.currentState!.push(
          CupertinoPageRoute<void>(
            builder: (_) => StatefulBuilder(
              builder: (context, update) => Scaffold(
                body: Stack(
                  children: [
                    const Center(child: Text('chat body')),
                    if (visible)
                      IMBoyImageGallery(
                        images: const [PreviewImage(id: 'one', uri: '')],
                        pageController: controller,
                        onClosePressed: () => update(() {
                          closes++;
                          visible = false;
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (useEdge) {
          await tester.dragFrom(const Offset(3, 300), const Offset(280, 0));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(closes, 1);
        expect(platformPops, 0);
        expect(find.text('chat body'), findsOneWidget);
        expect(navigator.currentState!.canPop(), isTrue);
      },
    );
  }

  testWidgets(
    'root route gallery edge closes the internal layer without popping',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final controller = PageController();
      addTearDown(controller.dispose);
      var visible = true;
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: StatefulBuilder(
            builder: (_, update) => Scaffold(
              body: Stack(
                children: [
                  const Center(child: Text('root chat')),
                  if (visible)
                    IMBoyImageGallery(
                      images: const [PreviewImage(id: 'one', uri: '')],
                      pageController: controller,
                      onClosePressed: () => update(() {
                        visible = false;
                        closes++;
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(3, 300), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(find.byType(IMBoyImageGallery), findsNothing);
      expect(find.text('root chat'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
    },
  );

  testWidgets('gallery horizontal swipe in body still changes image', (
    tester,
  ) async {
    final (_, controller) = await _mountGallery(tester);
    await tester.flingFrom(const Offset(700, 300), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();
    expect(controller.page, 1);
  });
}
