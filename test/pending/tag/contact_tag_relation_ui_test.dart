import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_page.dart';

Widget _buildContactTagPage() {
  return const ProviderScope(
    child: MaterialApp(
      home: ContactSettingTagPage(
        peerId: 'u_1001',
        peerAccount: 'alice',
        peerAvatar: '',
        peerNickname: 'Alice',
        peerGender: 1,
        peerTitle: '',
        peerSign: '',
        peerRegion: '',
        peerSource: '',
        peerRemark: 'old-remark',
        peerTag: 'tag_a,tag_b',
      ),
    ),
  );
}

void main() {
  testWidgets('contact tag page renders remark editor and tag chips', (
    tester,
  ) async {
    await tester.pumpWidget(_buildContactTagPage());
    await tester.pump();

    expect(find.byType(ContactSettingTagPage), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('tag_a'), findsOneWidget);
    expect(find.text('tag_b'), findsOneWidget);
  });

  testWidgets('save action becomes enabled after remark changed', (
    tester,
  ) async {
    await tester.pumpWidget(_buildContactTagPage());
    await tester.pump();

    final buttonsBefore = tester.widgetList<TextButton>(find.byType(TextButton));
    expect(buttonsBefore.any((button) => button.onPressed == null), isTrue);

    await tester.enterText(find.byType(TextFormField), 'new-remark');
    await tester.pump();

    final buttonsAfter = tester.widgetList<TextButton>(find.byType(TextButton));
    expect(buttonsAfter.any((button) => button.onPressed != null), isTrue);
  });
}
