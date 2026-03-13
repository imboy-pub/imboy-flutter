import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_feed_page.dart';

Widget _buildMomentFeedPage() {
  return TranslationProvider(
    child: const MaterialApp(home: MomentFeedPage()),
  );
}

void main() {
  testWidgets('moment feed page renders loading state and create entry', (
    tester,
  ) async {
    await tester.pumpWidget(_buildMomentFeedPage());
    await tester.pump();

    expect(find.byType(MomentFeedPage), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
  });
}
