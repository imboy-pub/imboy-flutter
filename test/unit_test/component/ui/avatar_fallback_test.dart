import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';

void main() {
  testWidgets('名称为空时使用人物图标，不显示问号', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarFallbackContent(name: ' ', color: Colors.blue),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('有名称时保留首字识别', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarFallbackContent(name: '测试频道', color: Colors.blue),
        ),
      ),
    );

    expect(find.text('测'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
  });
}
