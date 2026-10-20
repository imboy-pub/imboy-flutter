import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/message_channel_card_builder.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_share_payload.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  testWidgets('文章转发使用可渲染卡片并打开对应文章路由', (tester) async {
    final extra = channelArticleShareExtra(
      '42',
      ChannelMessageModel(
        id: 100,
        channelId: 42,
        authorId: 7,
        content: '文章摘要',
        msgType: ChannelMessageType.text,
        createdAt: DateTime(2026),
      ),
    );
    final msg = extra['msg'] as Map<String, dynamic>;
    expect(msg['msg_type'], 'channel_card');
    final payload = msg['payload'] as Map<String, dynamic>;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ChannelCardMessageBuilder(
              user: const User(id: '8'),
              message: CustomMessage(
                id: 'share1',
                authorId: '7',
                createdAt: DateTime(2026),
                metadata: payload,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/channel/:id/article/:mid',
          builder: (_, state) => Scaffold(
            body: Text(
              'article:${state.pathParameters['id']}/${state.pathParameters['mid']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('文章摘要'));
    await tester.pumpAndSettle();
    expect(find.text('article:42/100'), findsOneWidget);
  });
}
