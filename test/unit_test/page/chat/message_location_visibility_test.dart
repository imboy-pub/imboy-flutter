import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/message_location_visibility.dart';

void main() {
  testWidgets('only the mounted target inside the viewport is located', (
    tester,
  ) async {
    final target = GlobalKey();
    final scroll = ScrollController();
    expect(isLocationTargetVisible(target), isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 400),
                  SizedBox(key: target, height: 40, width: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(target.currentContext, isNotNull);
    expect(isLocationTargetVisible(target), isFalse);
    scroll.jumpTo(240);
    await tester.pump();
    expect(isLocationTargetVisible(target), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(isLocationTargetVisible(target), isFalse);
    scroll.dispose();
  });

  testWidgets('switching the requested target drops the old visible key', (
    tester,
  ) async {
    final target = GlobalKey();
    var selected = 0;
    late StateSetter setSelection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setSelection = setState;
                  return Column(
                    children: [
                      SizedBox(
                        key: selected == 0 ? target : null,
                        height: 40,
                        width: 40,
                      ),
                      const SizedBox(height: 400),
                      SizedBox(
                        key: selected == 1 ? target : null,
                        height: 40,
                        width: 40,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(isLocationTargetVisible(target), isTrue);
    setSelection(() => selected = 1);
    await tester.pump();
    expect(isLocationTargetVisible(target), isFalse);
  });
}
