import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_middle_panel.dart';

Widget _host(int currentTab) {
  return MaterialApp(
    home: Scaffold(
      body: WebMiddlePanel(
        currentTab: currentTab,
        tabs: const [
          _StateProbe(key: ValueKey('tab-a'), label: 'A'),
          _StateProbe(key: ValueKey('tab-b'), label: 'B'),
        ],
      ),
    ),
  );
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key, required this.label});

  final String label;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  late final Object identity = Object();

  @override
  Widget build(BuildContext context) {
    return Text('${widget.label}:${identity.hashCode}');
  }
}

void main() {
  testWidgets('切换时保持 IndexedStack 子页状态并执行轻量淡入位移', (tester) async {
    await tester.pumpWidget(_host(0));
    final aBefore = tester.widget<Text>(find.textContaining('A:')).data;
    final bBefore = tester.widget<Text>(
      find.textContaining('B:', skipOffstage: false),
    ).data;

    await tester.pumpWidget(_host(1));

    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(const ValueKey('web-middle-panel-transition')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    final slide = tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey('web-middle-panel-transition')),
    );
    expect(opacity.opacity, 0.96);
    expect(slide.offset.dx, greaterThan(0));
    expect(find.byType(IndexedStack), findsOneWidget);
    expect(tester.widget<Text>(find.textContaining('A:', skipOffstage: false)).data, aBefore);
    expect(tester.widget<Text>(find.textContaining('B:')).data, bBefore);

    await tester.pumpAndSettle();
    final settledOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(const ValueKey('web-middle-panel-transition')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    final settledSlide = tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey('web-middle-panel-transition')),
    );
    expect(settledOpacity.opacity, 1);
    expect(settledSlide.offset, Offset.zero);
    expect(tester.takeException(), isNull);
  });
}
