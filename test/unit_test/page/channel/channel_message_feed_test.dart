import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_message_feed.dart';
import 'package:imboy/store/model/channel_model.dart';

class _EmptyChannelDetailNotifier extends ChannelDetailNotifier {
  final ChannelModel channel;

  _EmptyChannelDetailNotifier(this.channel);

  @override
  ChannelDetailState build() {
    super.build();
    return ChannelDetailState(
      channel: channel,
      messages: const [],
      isLoading: false,
      hasMore: false,
    );
  }

  @override
  Future<void> loadChannel(String channelId) async {}
}

ChannelModel _channel({
  required ChannelUserRole role,
  required bool subscribed,
  bool hasPurchased = false,
}) => ChannelModel(
  id: 1001,
  name: '测试频道',
  description: '频道简介',
  userRole: role,
  isSubscribed: subscribed,
  hasPurchased: hasPurchased,
  creatorId: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Widget _app(ChannelModel channel) => TranslationProvider(
  child: ProviderScope(
    overrides: [
      channelDetailProvider.overrideWith(
        () => _EmptyChannelDetailNotifier(channel),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ChannelMessageFeed(channelId: '1001')),
    ),
  ),
);

void main() {
  testWidgets('访客空态只给订阅主 CTA', (tester) async {
    await tester.pumpWidget(
      _app(_channel(role: ChannelUserRole.none, subscribed: false)),
    );

    expect(find.text(t.channel.noMessagesVisitor), findsOneWidget);
    expect(find.text(t.channel.noMessagesVisitorDesc), findsOneWidget);
    expect(find.text(t.channel.subscribe), findsOneWidget);
    expect(find.text(t.channel.publishFirstContent), findsNothing);
  });

  testWidgets('订阅者空态说明等待内容，不误导为可发布', (tester) async {
    await tester.pumpWidget(
      _app(_channel(role: ChannelUserRole.subscriber, subscribed: true)),
    );

    expect(find.text(t.channel.noMessagesSubscribed), findsOneWidget);
    expect(find.text(t.channel.noMessagesSubscribedDesc), findsOneWidget);
    expect(find.text(t.channel.subscribe), findsNothing);
    expect(find.text(t.channel.publishFirstContent), findsNothing);
  });

  testWidgets('已购买用户即使订阅状态不同步也不显示访客 CTA', (tester) async {
    await tester.pumpWidget(
      _app(
        _channel(
          role: ChannelUserRole.none,
          subscribed: false,
          hasPurchased: true,
        ),
      ),
    );

    expect(find.text(t.channel.noMessagesSubscribed), findsOneWidget);
    expect(find.text(t.channel.subscribe), findsNothing);
    expect(find.text(t.channel.noMessagesVisitor), findsNothing);
  });

  testWidgets('管理者空态只给发布第一条内容 CTA', (tester) async {
    await tester.pumpWidget(
      _app(_channel(role: ChannelUserRole.admin, subscribed: true)),
    );

    // Verify the new premium "Start Growing" welcome card components (English default in tests)
    expect(find.text('Channel "测试频道" created'), findsOneWidget);
    expect(find.text('Start growing "测试频道"'), findsOneWidget);
    expect(find.text('Share to My Status'), findsOneWidget);
    expect(find.text('Invite Admins'), findsOneWidget);
  });
}
