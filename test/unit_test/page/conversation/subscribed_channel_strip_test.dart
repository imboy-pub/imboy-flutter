import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart';
import 'package:imboy/page/conversation/widget/subscribed_channel_strip.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';

class MockSubscribedChannelStripNotifier
    extends SubscribedChannelStripNotifier {
  final List<SubscribedChannelSummary> _data;
  MockSubscribedChannelStripNotifier(this._data);

  @override
  Future<List<SubscribedChannelSummary>> build() async {
    return _data;
  }
}

SubscribedChannelSummary _createMockSummary({
  required bool isMuted,
  required int unreadCount,
}) {
  return SubscribedChannelSummary(
    channel: ChannelModel(
      id: 1001,
      name: '测试频道',
      description: '简介',
      subscriberCount: 10,
      isSubscribed: true,
      userRole: ChannelUserRole.subscriber,
      creatorId: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    subscription: ChannelSubscriptionModel(
      channelId: 1001,
      subscribedAt: DateTime.now(),
      unreadCount: unreadCount,
      isMuted: isMuted,
    ),
    lastMessagePreview: '新消息内容',
    lastMessageTime: DateTime.now().millisecondsSinceEpoch,
  );
}

Widget _app(Widget child, ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );

void main() {
  testWidgets('当频道未静音且有未读消息时，未读角标为红色且不渲染静音图标', (WidgetTester tester) async {
    final summary = _createMockSummary(isMuted: false, unreadCount: 5);
    final container = ProviderContainer(
      overrides: [
        subscribedChannelStripProvider.overrideWith(
          () => MockSubscribedChannelStripNotifier([summary]),
        ),
      ],
    );

    await tester.pumpWidget(_app(const SubscribedChannelStrip(), container));
    await tester.pumpAndSettle();

    // 应该显示未读消息数 5
    expect(find.text('5'), findsOneWidget);

    // 应该没有静音斜线铃铛图标
    expect(find.byIcon(CupertinoIcons.bell_slash_fill), findsNothing);
  });

  testWidgets('当频道开启免打扰且有未读消息时，未读角标为灰色且渲染静音图标', (WidgetTester tester) async {
    final summary = _createMockSummary(isMuted: true, unreadCount: 8);
    final container = ProviderContainer(
      overrides: [
        subscribedChannelStripProvider.overrideWith(
          () => MockSubscribedChannelStripNotifier([summary]),
        ),
      ],
    );

    await tester.pumpWidget(_app(const SubscribedChannelStrip(), container));
    await tester.pumpAndSettle();

    // 应该显示未读消息数 8
    expect(find.text('8'), findsOneWidget);

    // 应该显示静音斜线铃铛图标
    expect(find.byIcon(CupertinoIcons.bell_slash_fill), findsOneWidget);
  });
}
