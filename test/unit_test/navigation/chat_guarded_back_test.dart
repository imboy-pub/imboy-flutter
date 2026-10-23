import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/app_back_scope.dart';
import 'package:imboy/page/chat/chat/chat_back_handler.dart';

class _ChatHost extends StatefulWidget {
  const _ChatHost({super.key, this.gallery = false});
  final bool gallery;
  @override
  State<_ChatHost> createState() => _ChatHostState();
}

class _ChatHostState extends State<_ChatHost> {
  final _images = PageController();
  late bool gallery = widget.gallery;
  var panels = true;
  var hides = 0;
  var closes = 0;
  void openGallery() => setState(() => gallery = true);
  @override
  void dispose() {
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppBackScope<void>(
    canPop: !gallery && !panels,
    edgeGestureEnabled: !gallery,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || gallery) return;
      await popChatAfterHidingPanels(
        context,
        () => setState(() {
          hides++;
          panels = false;
        }),
      );
    },
    child: Scaffold(
      body: Stack(
        children: [
          const Center(child: Text('chat host')),
          if (gallery)
            IMBoyImageGallery(
              images: const [PreviewImage(id: 'one', uri: '')],
              pageController: _images,
              onClosePressed: () => setState(() {
                gallery = false;
                closes++;
              }),
            ),
        ],
      ),
    ),
  );
}

Future<(GlobalKey<NavigatorState>, GlobalKey<_ChatHostState>)> _open(
  WidgetTester tester, {
  bool gallery = false,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  final host = GlobalKey<_ChatHostState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('previous page')),
    ),
  );
  navigator.currentState!.push(
    CupertinoPageRoute<void>(
      builder: (_) => _ChatHost(key: host, gallery: gallery),
    ),
  );
  await tester.pumpAndSettle();
  return (navigator, host);
}

void main() {
  testWidgets(
    'repeated system back awaits panel close once and pops only chat',
    (tester) async {
      final (navigator, host) = await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      expect(host.currentState!.hides, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('previous page'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
    },
  );

  testWidgets(
    'a dialog opened while panels close is never popped by stale chat back',
    (tester) async {
      final (_, host) = await _open(tester);
      await tester.binding.handlePopRoute();
      showDialog<void>(
        context: host.currentContext!,
        builder: (_) => const AlertDialog(title: Text('new dialog')),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('new dialog'), findsOneWidget);
      expect(find.text('chat host'), findsOneWidget);
      expect(host.currentState!.hides, 1);
    },
  );

  testWidgets(
    'new gallery on the same route cancels an older delayed chat pop',
    (tester) async {
      final (navigator, host) = await _open(tester);
      await tester.binding.handlePopRoute();
      host.currentState!.openGallery();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(IMBoyImageGallery), findsOneWidget);
      expect(find.text('chat host'), findsOneWidget);
      expect(host.currentState!.hides, 1);
      expect(host.currentState!.closes, 0);
      expect(navigator.currentState!.canPop(), isTrue);
    },
  );

  testWidgets(
    'replacement during panel close is never popped by disposed chat',
    (tester) async {
      final (navigator, _) = await _open(tester);
      await tester.binding.handlePopRoute();
      navigator.currentState!.pushReplacement(
        CupertinoPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('replacement page')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('replacement page'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
    },
  );

  for (final edge in [false, true]) {
    testWidgets(
      'gallery and chat scopes: ${edge ? 'edge' : 'system'} closes gallery alone',
      (tester) async {
        final (navigator, host) = await _open(tester, gallery: true);
        if (edge) {
          await tester.dragFrom(const Offset(3, 300), const Offset(280, 0));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(host.currentState!.closes, 1);
        expect(host.currentState!.hides, 0);
        expect(find.byType(IMBoyImageGallery), findsNothing);
        expect(find.text('chat host'), findsOneWidget);
        expect(navigator.currentState!.canPop(), isTrue);
      },
    );
  }
}
