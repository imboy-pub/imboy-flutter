import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/tag/group_tag_page.dart';

Widget _buildGroupTagPage() {
  return TranslationProvider(
    child: const ProviderScope(
      child: MaterialApp(home: GroupTagPage(groupId: 'g_1001')),
    ),
  );
}

void main() {
  testWidgets('group tag page renders loading state and add action', (
    tester,
  ) async {
    await tester.pumpWidget(_buildGroupTagPage());

    expect(find.byType(GroupTagPage), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('add tag dialog can be opened and closed', (tester) async {
    await tester.pumpWidget(_buildGroupTagPage());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    final dialogButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    expect(dialogButtons, findsNWidgets(2));

    await tester.tap(dialogButtons.first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AlertDialog), findsNothing);
  });
}
