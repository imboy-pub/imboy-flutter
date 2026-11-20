import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message.dart';
import 'package:imboy/component/chat/message_quote_builder.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 引用卡片消息（频道名片/频道内容分享/红包…）时，引用块必须给出可读摘要。
///
/// 修复前 `messageMsgWidget` 的 default 分支对 CustomMessage 一律返回
/// `SizedBox.shrink()` —— 引用一条卡片消息，引用区整块空白。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> prepareCurrentUser() async {
    await prepareWebWriter();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, 'test_author_id');
    await StorageService.to.setString(
      Keys.currentUser,
      '{"uid":"test_author_id","nickname":"测试账号","account":"","email":"","mobile":"","avatar":"","role":null,"gender":0,"region":"","sign":"","setting":{}}',
    );
  }

  testWidgets('引用频道卡片显示内容摘要而不是空白', (tester) async {
    await prepareCurrentUser();
    final msg = CustomMessage(
      id: 'q1',
      authorId: '7',
      createdAt: DateTime(2026),
      metadata: const <String, dynamic>{
        'msg_type': 'channel_card',
        'channel_id': '42',
        'content': '书法频道：横画的起笔',
      },
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  messageMsgWidget(context, msg, txtColor: Colors.black),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('横画的起笔'), findsOneWidget);
  });

  testWidgets('撤回的本地原消息隐藏引用原文并保留回复正文', (tester) async {
    const reply = CustomMessage(
      id: 'reply',
      authorId: 'peer',
      metadata: {
        'quote_text': 'reply body',
        'quote_msg': {
          'id': 'source',
          'type': 'text',
          'text': 'cached original',
        },
      },
    );
    const source = TextMessage(
      id: 'source',
      authorId: 'viewer',
      text: 'revoked',
      metadata: {'status': '30'},
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: QuoteMessageBuilder(
              type: 'C2C',
              user: const User(id: 'viewer'),
              message: reply,
              conversationMessages: const [source],
            ),
          ),
        ),
      ),
    );

    expect(find.text('reply body'), findsOneWidget);
    expect(find.text('cached original'), findsNothing);
  });

  testWidgets('优化列表刷新原消息状态后隐藏现有引用', (tester) async {
    await prepareCurrentUser();
    const reply = CustomMessage(
      id: 'reply',
      authorId: 'test_author_id',
      metadata: {
        'msg_type': 'quote',
        'quote_text': 'reply body',
        'quote_msg': {
          'id': 'source',
          'authorId': 'peer',
          'type': 'text',
          'text': 'cached original',
        },
      },
    );
    const source = TextMessage(id: 'source', authorId: 'peer', text: 'origin');

    Widget page(Message original) => TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            messages: [reply, original],
            currentUserId: 'test_author_id',
            onMessageLongPress: (_) {},
            onMessageDoubleTap: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(page(source));
    expect(find.text('cached original'), findsOneWidget);
    await tester.pumpWidget(page(source.copyWith(metadata: {'status': 30})));
    expect(find.text('cached original'), findsNothing);
    expect(find.text('reply body'), findsOneWidget);
  });

  testWidgets('未知类型的引用块不再抛异常', (tester) async {
    await prepareCurrentUser();
    final msg = CustomMessage(
      id: 'q2',
      authorId: '7',
      createdAt: DateTime(2026),
      metadata: const <String, dynamic>{'msg_type': 'whatever_private_type'},
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  messageMsgWidget(context, msg, txtColor: Colors.black),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
