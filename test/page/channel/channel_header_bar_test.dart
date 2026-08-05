import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';

ChannelModel _channel({bool subscribed = false}) => ChannelModel(
  id: 1001,
  name: '测试频道',
  description: '频道简介',
  subscriberCount: 12,
  isSubscribed: subscribed,
  userRole: subscribed ? ChannelUserRole.subscriber : ChannelUserRole.none,
  creatorId: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

Widget _themedApp(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('统计加载时显示等高 skeleton，不渲染伪造的 0 统计', (tester) async {
    await tester.pumpWidget(
      _app(ChannelHeaderBar(channel: _channel(), onActionTap: () {})),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('0'), findsNothing);
    expect(find.textContaining(t.channel.subscribers), findsNothing);
  });

  testWidgets('操作 pending 时按钮禁用并显示 spinner', (tester) async {
    await tester.pumpWidget(
      _app(
        ChannelHeaderBar(
          channel: _channel(),
          onActionTap: () {},
          isActionPending: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('统计返回后显示真实紧凑统计', (tester) async {
    await tester.pumpWidget(
      _app(
        ChannelHeaderBar(
          channel: _channel(subscribed: true),
          stats: ChannelStatsModel(
            channelId: 1001,
            subscriberCount: 12,
            totalMessages: 8,
            totalViews: 20,
            totalReactions: 3,
          ),
        ),
      ),
    );

    expect(find.textContaining(t.channel.subscribers), findsOneWidget);
    expect(find.textContaining(t.channel.messages), findsOneWidget);
  });

  testWidgets('暗色主题和动态字号下仍保留订阅语义', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      _themedApp(ChannelHeaderBar(channel: _channel(), onActionTap: () {})),
    );

    expect(find.bySemanticsLabel(t.channel.subscribe), findsOneWidget);
    expect(find.text(t.channel.subscribe), findsOneWidget);
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
  });

  testWidgets('管理者头部只显示管理动作，不显示订阅 CTA', (tester) async {
    final managed = ChannelModel(
      id: 1001,
      name: '管理频道',
      description: '频道简介',
      subscriberCount: 12,
      userRole: ChannelUserRole.admin,
      isSubscribed: true,
      creatorId: 1,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(
      _app(ChannelHeaderBar(channel: managed, onActionTap: () {})),
    );

    expect(find.text(t.main.manage), findsOneWidget);
    expect(find.text(t.channel.subscribe), findsNothing);
    expect(find.text(t.channel.subscribed), findsNothing);
  });

  test('英文频道文案已生成且不是中文回退', () async {
    final en = await AppLocale.enUs.build();

    expect(en.channel.subscribe, 'Subscribe');
    expect(en.channel.writeArticle, 'Write Post');
  });
}
