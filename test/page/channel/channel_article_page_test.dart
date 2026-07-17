// ChannelArticlePage Widget 测试
//
// 验证频道沉浸式全屏阅读页：
// - 用假 message 构造并 pump，长正文完整渲染（不折叠 / 无省略号）
// - 无评论时展示空态占位 + 评论计数为 0
//
// 依赖注入：channelServiceProvider override 注入 mock，getComments 返回空，
// 不触发真实网络。channelDetailProvider 用默认 build()（channel=null，标题回退）。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_article_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_article_page.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/channel_message_model.dart';

class _MockChannelService extends Mock implements ChannelService {}

// 超过 280 字符的正文——feed 卡片会折叠为 280 + 省略号，阅读页必须完整展示。
final _longContent = '沉浸式全屏阅读正文段落。' * 40;

ChannelMessageModel _fakeMessage({String? content}) => ChannelMessageModel(
  id: 9001,
  channelId: 1001,
  authorId: 2002,
  authorName: '频道作者',
  content: content ?? _longContent,
  msgType: ChannelMessageType.text,
  createdAt: DateTime(2024, 1, 1),
  viewCount: 123,
);

Widget _buildTestApp(ChannelService service, ChannelMessageModel? message) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: ChannelArticlePage(channelId: '1001', message: message),
      ),
    ),
  );
}

void main() {
  late _MockChannelService service;

  setUp(() {
    service = _MockChannelService();
    when(
      () => service.getComments(
        channelId: any(named: 'channelId'),
        messageId: any(named: 'messageId'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);
  });

  testWidgets('长正文完整渲染且不折叠 / renders full body without truncation', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(service, _fakeMessage()));
    await tester.pumpAndSettle();

    // 正文完整出现在 SelectableText 中（未被截断为 280 + 省略号）
    final bodyFinder = find.byWidgetPredicate(
      (w) => w is SelectableText && w.data == _longContent,
    );
    expect(bodyFinder, findsOneWidget);

    // 未出现折叠省略号截断的正文
    final truncated = '${_longContent.substring(0, 280).trim()}…';
    expect(find.text(truncated), findsNothing);
  });

  testWidgets('imageText：payload.title 作顶部标题、content 作正文', (tester) async {
    final msg = ChannelMessageModel(
      id: 9001,
      channelId: 1001,
      authorId: 2002,
      authorName: '频道作者',
      content: '完整正文内容段落',
      msgType: ChannelMessageType.imageText,
      payload: const {'title': '文章大标题', 'images': <dynamic>[]},
      createdAt: DateTime(2024, 1, 1),
      viewCount: 1,
    );
    await tester.pumpWidget(_buildTestApp(service, msg));
    await tester.pumpAndSettle();

    // 顶部标题取 payload.title
    expect(find.text('文章大标题'), findsOneWidget);
    // content 完整作正文（SelectableText），不被切首行
    final bodyFinder = find.byWidgetPredicate(
      (w) => w is SelectableText && w.data == '完整正文内容段落',
    );
    expect(bodyFinder, findsOneWidget);
  });

  testWidgets('无评论时展示空态占位 / shows empty placeholder when no comments', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(service, _fakeMessage(content: '短正文')),
    );
    await tester.pumpAndSettle();

    verify(
      () => service.getComments(
        channelId: '1001',
        messageId: '9001',
        cursor: 0,
        limit: 20,
      ),
    ).called(1);
    expect(find.text(t.channel.noComments), findsOneWidget);
  });

  testWidgets('message 为空时降级空态 / degrades to empty view when message is null', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(service, null));
    await tester.pumpAndSettle();

    // 未加载评论（message 为空直接返回）
    verifyNever(
      () => service.getComments(
        channelId: any(named: 'channelId'),
        messageId: any(named: 'messageId'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    );
    expect(find.text(t.common.loadError), findsOneWidget);
  });
}
