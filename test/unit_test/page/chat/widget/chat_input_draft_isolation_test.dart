import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/utils/chat_draft_keys.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    String uid, {
    GlobalKey<ChatInputState>? inputKey,
  }) async {
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
                key: inputKey,
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

  testWidgets('flushDraft: <300ms 持久化后立即卸载，重挂恢复文本与光标', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await StorageService.to.setString(Keys.currentUid, '1001');
    final height = ValueNotifier<double>(52);
    addTearDown(height.dispose);
    final inputKey = GlobalKey<ChatInputState>();
    Widget composer() => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ChatInput(
              key: inputKey,
              type: 'C2G',
              peerId: '995301',
              composerHeight: height,
              onSendPressed: (_) async => true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(composer());
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      '最后一段输入',
    );
    field(tester).controller!.selection = const TextSelection.collapsed(
      offset: 4,
    );
    await tester.pump(); // 不推进防抖时钟
    expect(
      AccountDraftStore.capture('C2G', '995301').read().text,
      isNot('最后一段输入'),
      reason: '300ms 未到时不应由普通防抖落盘',
    );

    final start = tester.binding.clock.now();
    final oldState = inputKey.currentState!;
    await oldState.flushDraft(); // 必须等待异步持久化完成，不能只启动写入
    await tester.pumpWidget(const SizedBox.shrink()); // 模拟多选 action bar 替换输入区
    expect(oldState.mounted, isFalse);
    await StorageService.to.reload(); // 丢弃内存缓存的乐观值，检查底层已提交的数据
    final draft = AccountDraftStore.capture('C2G', '995301').read();
    expect(draft.text, '最后一段输入');
    expect(draft.cursor, 4);
    expect(AccountDraftStore.capture('C2G', '995302').read().text, isEmpty);

    await tester.pumpWidget(composer()); // 退出多选后新建 ChatInputState
    await tester.pump();
    expect(inputKey.currentState, isNot(same(oldState)));
    expect(field(tester).controller!.text, '最后一段输入');
    expect(field(tester).controller!.selection.baseOffset, 4);
    expect(
      tester.binding.clock.now().difference(start),
      lessThan(const Duration(milliseconds: 300)),
      reason: '全程不推进 300ms 防抖时钟，不能靠自然到期蒙混过关',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

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

  testWidgets('late save after account switch is ignored', (tester) async {
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
    expect(field(tester).controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('flushDraft after account switch never writes the old draft', (
    tester,
  ) async {
    final inputKey = GlobalKey<ChatInputState>();
    await mount(tester, '1001', inputKey: inputKey);
    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'stale A',
    );
    await tester.pump();
    await StorageService.to.setString(Keys.currentUid, '1002');
    await inputKey.currentState!.flushDraft();
    await StorageService.to.reload();
    final a = chatDraftKeys('1001', 'C2G', '995301')!;
    final b = chatDraftKeys('1002', 'C2G', '995301')!;
    expect(StorageService.to.getKeys(), isNot(contains(a.text)));
    expect(StorageService.to.getKeys(), isNot(contains(b.text)));
    await mount(tester, '1002');
    expect(field(tester).controller!.text, isEmpty);
    await mount(tester, '1001');
    expect(field(tester).controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cleanup before debounce rejects late draft and preserves B', (
    tester,
  ) async {
    await mount(tester, '1001');
    final owner = AccountLocalTaskOwner.capture();
    final a = chatDraftKeys('1001', 'C2G', '995301')!;
    final b = chatDraftKeys('1002', 'C2G', '995301')!;
    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'late A',
    );
    await StorageService.to.setString(Keys.currentUid, '1002');
    await StorageService.to.setString(b.text, 'B draft');
    final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(owner);
    try {
      await cleanup.stopped;
      await StorageService.to.remove(a.text);
      await StorageService.to.remove(a.cursor);
    } finally {
      cleanup.release();
    }
    await tester.pump(const Duration(milliseconds: 350));
    expect(StorageService.to.getKeys(), isNot(contains(a.text)));
    expect(StorageService.to.getKeys(), isNot(contains(a.cursor)));
    expect(StorageService.to.getString(b.text), 'B draft');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful send reset is not recreated by empty debounce', (
    tester,
  ) async {
    await mount(tester, '1001');
    await save(tester, 'send this', 3);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('send_button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    final keys = chatDraftKeys('1001', 'C2G', '995301')!;
    expect(StorageService.to.getKeys(), isNot(contains(keys.text)));
    expect(StorageService.to.getKeys(), isNot(contains(keys.cursor)));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
