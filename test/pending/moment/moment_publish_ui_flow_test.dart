import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_create_page.dart';

Widget _buildMomentCreatePage() {
  return TranslationProvider(
    child: const MaterialApp(home: MomentCreatePage()),
  );
}

void main() {
  testWidgets('moment create page renders publish inputs and controls', (
    tester,
  ) async {
    await tester.pumpWidget(_buildMomentCreatePage());
    await tester.pump();

    expect(find.byType(MomentCreatePage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byType(TextButton), findsWidgets);
  });
}
