import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';

class _TestChannelDetailNotifier extends ChannelDetailNotifier {
  final ChannelModel channel;
  final List<ChannelMessageModel> initialMessages;

  _TestChannelDetailNotifier(this.channel, this.initialMessages);

  @override
  Future<void> loadChannel(String channelId) async {
    state = state.copyWith(
      channel: channel,
      messages: initialMessages,
      hasMore: false,
      isLoading: false,
    );
    debugSetChannelId(channel.id.toString());
  }

  @override
  Future<void> loadMessages(
    String channelId, {
    int? cursor,
    int limit = 20,
  }) async {}
}

ChannelMessageModel _buildMessage(int id) {
  return ChannelMessageModel(
    id: id,
    channelId: 1001,
    content: 'Test message',
    msgType: 'channel_text',
    createdAt: DateTime.now(),
  );
}

ChannelModel _buildChannel() {
  return ChannelModel(
    id: 1001,
    name: 'My Channel',
    creatorId: 1002,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    userRole: ChannelUserRole.admin,
    isSubscribed: true,
  );
}

void main() {
  testWidgets('ChannelDetailPage removes message after deleted event', (
    tester,
  ) async {
    final channel = _buildChannel();
    final providerOverride = channelDetailProvider.overrideWith(
      () => _TestChannelDetailNotifier(channel, [_buildMessage(1)]),
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [providerOverride],
          child: MaterialApp(
            home: ChannelDetailPage(
              channelId: channel.id.toString(),
              autoLoadStats: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsOneWidget);

    AppEventBus.fire(
      const ChannelMessageDeletedEvent(
        channelId: '1001',
        messageId: '1',
        reason: 'deleted',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test message'), findsNothing);
  });
}
