import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';

void main() {
  Future<void> mount(WidgetTester tester, String uid) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await StorageService.to.setString(Keys.currentUid, uid);
    final height = ValueNotifier<double>(52);
    addTearDown(height.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                type: 'C2G',
                peerId: '995301',
                composerHeight: height,
                onSendPressed: (_) async => true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  CupertinoTextField field(WidgetTester tester) =>
      tester.widget(find.byKey(const Key('chat_message_input')));

  Future<void> save(WidgetTester tester, String text, int cursor) async {
    await tester.enterText(find.byKey(const Key('chat_message_input')), text);
    field(tester).controller!.selection = TextSelection.collapsed(
      offset: cursor,
    );
    await tester.pump(const Duration(milliseconds: 350));
  }

  setUp(() async => StorageService.to.clear());
  tearDown(() async => StorageService.to.clear());

  testWidgets('conversation summary reads only the current account draft', (
    tester,
  ) async {
    final conversation = ConversationModel.empty().copyWith(
      type: 'C2G',
      peerId: 995301,
    );
    await StorageService.to.setString('draftC2G_995301', 'ownerless');
    await mount(tester, '1001');
    expect(conversation.content, isNot(contains('ownerless')));
    await save(tester, 'account A summary', 3);
    expect(conversation.content, contains('account A summary'));
    await mount(tester, '1002');
    expect(conversation.content, isNot(contains('account A summary')));
    await save(tester, 'account B summary', 5);
    expect(conversation.content, contains('account B summary'));
    await mount(tester, '1001');
    expect(conversation.content, contains('account A summary'));
    await mount(tester, '');
    expect(conversation.content, isNot(contains('summary')));
    expect(conversation.content, isNot(contains('ownerless')));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('same group keeps each account draft and cursor separate', (
    tester,
  ) async {
    await mount(tester, '1001');
    await save(tester, 'account A draft', 3);
    await mount(tester, '1002');
    expect(field(tester).controller!.text, isEmpty);
    await save(tester, 'account B draft', 7);
    await mount(tester, '1001');
    expect(field(tester).controller!.text, 'account A draft');
    expect(field(tester).controller!.selection.baseOffset, 3);
    await mount(tester, '1002');
    expect(field(tester).controller!.text, 'account B draft');
    expect(field(tester).controller!.selection.baseOffset, 7);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy ownerless drafts are never restored', (tester) async {
    await StorageService.to.setString('draftC2G_995301', 'ownerless');
    await StorageService.to.setString('draftCursorC2G_995301', '4');
    await mount(tester, '1001');
    expect(field(tester).controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('missing UID neither restores nor persists a draft', (
    tester,
  ) async {
    await mount(tester, '');
    await save(tester, 'anonymous', 2);
    expect(
      StorageService.to.getKeys().where((key) => key.startsWith('draft')),
      isEmpty,
    );
    await mount(tester, '1001');
    expect(field(tester).controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late save remains bound to the creating account', (
    tester,
  ) async {
    await mount(tester, '1001');
    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'pending A',
    );
    field(tester).controller!.selection = const TextSelection.collapsed(
      offset: 4,
    );
    await StorageService.to.setString(Keys.currentUid, '1002');
    await tester.pump(const Duration(milliseconds: 350));
    await mount(tester, '1002');
    expect(field(tester).controller!.text, isEmpty);
    await mount(tester, '1001');
    expect(field(tester).controller!.text, 'pending A');
    expect(field(tester).controller!.selection.baseOffset, 4);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
