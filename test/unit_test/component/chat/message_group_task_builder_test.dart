import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/message_group_task_builder.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_normalizer.dart';

void main() {
  testWidgets('待办消息保留类型、显示标题并打开正确详情', (tester) async {
    expect(
      MessageTypeNormalizer.normalize(msgType: 'groupTask', payload: {}),
      'groupTask',
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => const GroupTaskMessageTypePlugin().build(
                CustomMessage(
                  id: 'vote_abc',
                  authorId: '456',
                  metadata: {'title': '去哪儿旅游', 'group_id': '123', 'id': 'abc'},
                ),
                MessageRenderContext(
                  context: context,
                  type: 'C2G',
                  user: const User(id: '456'),
                  isSentByMe: true,
                  bubbleWrapper: (child) => child,
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/group/:groupId/task/:voteId',
          builder: (context, state) => Scaffold(
            body: Text(
              '${state.pathParameters['groupId']}/${state.pathParameters['voteId']}',
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('去哪儿旅游'), findsOneWidget);
    await tester.tap(find.text('去哪儿旅游'));
    await tester.pumpAndSettle();
    expect(find.text('123/abc'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
