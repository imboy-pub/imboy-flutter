import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/message_channel_card_builder.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_share_payload.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';

/// 频道内容分享到聊天的渲染契约。
///
/// 钉住两条真机缺陷（2026-10-30）：
///   1. 频道消息分享写的私有 msg_type `channel_message` 没有任何渲染器注册，
///      收发双方都只看到「不支持的消息类型 (channel_message)」；
///   2. 业务字段被包在 `payload` 里，而卡片只读 metadata 顶层 ——
///      卡片看得见、点不动（channel_id 为空直接 return）。
void main() {
  ChannelMessageModel post() => ChannelMessageModel(
    id: 100,
    channelId: 42,
    authorId: 7,
    content: '文章摘要',
    msgType: ChannelMessageType.text,
    createdAt: DateTime(2026),
  );

  test('分享 payload 用已注册的 channel_card，且业务字段在顶层', () {
    final msg =
        channelPostShareExtra('42', post())['msg'] as Map<String, dynamic>;

    expect(msg['msg_type'], MessageType.channelCard);
    expect(msg['channel_id'], '42');
    expect(msg['message_id'], '100');
    expect(msg['content'], '文章摘要');
    // 扁平形状：任何 builder 都能从 metadata 顶层直接取到
    expect(msg.containsKey('payload'), isFalse);
  });

  test('频道名片分享同样是扁平形状', () {
    final msg =
        channelCardShareExtra(
              ChannelModel(
                id: 42,
                name: '书法频道',
                avatar: 'a.png',
                creatorId: 7,
                subscriberCount: 12,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            )['msg']
            as Map<String, dynamic>;

    expect(msg['msg_type'], MessageType.channelCard);
    expect(msg['channel_id'], '42');
    expect(msg['channel_name'], '书法频道');
    expect(msg['subscriber_count'], 12);
  });

  for (final legacy in [true, false]) {
    testWidgets('频道卡片可点进文章（${legacy ? '历史嵌套 payload' : '扁平 payload'}）', (
      tester,
    ) async {
      final msg =
          channelPostShareExtra('42', post())['msg'] as Map<String, dynamic>;
      // 历史行：业务字段落在嵌套 payload 内（≤2026-10-30 的落库形状）
      final metadata = legacy ? {'payload': msg} : msg;

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
                  metadata: Map<String, dynamic>.from(metadata),
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
}
