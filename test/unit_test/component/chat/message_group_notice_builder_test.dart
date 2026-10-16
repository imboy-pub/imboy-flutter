import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/message_group_notice_builder.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_normalizer.dart';

void main() {
  testWidgets('群公告消息保留类型、显示标题并跳转群公告页', (tester) async {
    expect(
      MessageTypeNormalizer.normalize(msgType: 'groupNotice', payload: {}),
      'groupNotice',
    );
    Object? pushedExtra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => const GroupNoticeMessageTypePlugin().build(
                CustomMessage(
                  id: 'notice_1',
                  authorId: '456',
                  metadata: {
                    'id': '9',
                    'group_id': '123',
                    'title': '周日闭馆通知',
                    'content': '本周日场馆维护，暂停营业一天',
                  },
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
          path: '/group/announcement',
          builder: (context, state) {
            pushedExtra = state.extra;
            return const Scaffold(body: Text('公告页'));
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('周日闭馆通知'), findsOneWidget);
    expect(find.text('本周日场馆维护，暂停营业一天'), findsOneWidget);
    await tester.tap(find.text('周日闭馆通知'));
    await tester.pumpAndSettle();
    expect(find.text('公告页'), findsOneWidget);
    expect(pushedExtra, {'groupId': '123'});
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('标题缺失退化为「群公告」，无 groupId 时卡片不可点', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => const GroupNoticeMessageTypePlugin().build(
                CustomMessage(
                  id: 'notice_2',
                  authorId: '456',
                  metadata: <String, dynamic>{},
                ),
                MessageRenderContext(
                  context: context,
                  type: 'C2G',
                  user: const User(id: '456'),
                  isSentByMe: false,
                  bubbleWrapper: (child) => child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('群公告'), findsOneWidget);
    final listTile = tester.widget<ListTile>(find.byType(ListTile));
    expect(listTile.onTap, isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
