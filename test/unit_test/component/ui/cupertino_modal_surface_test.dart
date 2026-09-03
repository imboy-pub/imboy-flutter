import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/cupertino_modal_surface.dart';

void main() {
  testWidgets('弹窗表面使用当前主题色且承接底部安全区', (tester) async {
    const surface = Color(0xFF123456);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
          ).copyWith(surface: surface),
        ),
        home: const Scaffold(body: CupertinoModalSurface(child: Text('sheet'))),
      ),
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CupertinoModalSurface),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, surface);
    expect(
      find.descendant(
        of: find.byType(CupertinoModalSurface),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
  });
}
