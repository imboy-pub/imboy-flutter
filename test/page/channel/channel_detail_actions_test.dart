import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/events/common_events.dart';

ChannelMessageModel _buildMessage({
  required int id,
  bool pinned = false,
}) {
  return ChannelMessageModel(
    id: id,
    channelId: 1001,
    content: 'hello',
    msgType: 'channel_text',
    createdAt: DateTime.now(),
    isPinned: pinned,
  );
}

void main() {
  group('ChannelDetailNotifier local updates', () {
    late ProviderContainer container;
    late ChannelDetailNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(channelDetailProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('updateMessagePinned flips just one message', () {
      final messageA = _buildMessage(id: 1, pinned: false);
      final messageB = _buildMessage(id: 2, pinned: true);
      notifier.state = notifier.state.copyWith(messages: [messageA, messageB]);

      notifier.updateMessagePinned('1', true);

      final state = container.read(channelDetailProvider);
      expect(state.messages.firstWhere((msg) => msg.id == 1).isPinned,
          isTrue);
      expect(state.messages
          .firstWhere((msg) => msg.id == 2)
          .isPinned, isTrue);
    });

    test('removeMessageLocally drops the targeted message only', () {
      final messageA = _buildMessage(id: 1);
      final messageB = _buildMessage(id: 2);
      notifier.state = notifier.state.copyWith(messages: [messageA, messageB]);

      notifier.removeMessageLocally('1');

      final state = container.read(channelDetailProvider);
      expect(state.messages.length, 1);
      expect(state.messages.single.id, 2);
    });

    test('handleMessageDeletedEvent removes matching channel message', () {
      final message = _buildMessage(id: 1);
      notifier.state = notifier.state.copyWith(messages: [message]);
      notifier.debugSetChannelId('1001');

      notifier.handleMessageDeletedEvent(
        const ChannelMessageDeletedEvent(
          channelId: '1001',
          messageId: '1',
          reason: 'deleted',
        ),
      );

      final state = container.read(channelDetailProvider);
      expect(state.messages, isEmpty);
    });

    test('handleMessageDeletedEvent ignores other channels', () {
      final message = _buildMessage(id: 1);
      notifier.state = notifier.state.copyWith(messages: [message]);
      notifier.debugSetChannelId('1001');

      notifier.handleMessageDeletedEvent(
        const ChannelMessageDeletedEvent(
          channelId: '9999',
          messageId: '1',
          reason: 'deleted',
        ),
      );

      final state = container.read(channelDetailProvider);
      expect(state.messages.length, 1);
    });
  });

  group('ChannelDetailNotifier publish permission guard', () {
    late ProviderContainer container;
    late ChannelDetailNotifier notifier;

    ChannelModel buildChannel(ChannelUserRole role) {
      return ChannelModel(
        id: 1001,
        name: 'Test',
        creatorId: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userRole: role,
      );
    }

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(channelDetailProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('publishMessage returns false when user role is subscriber',
        () async {
      notifier.debugSetChannelId('1001');
      notifier.state = notifier.state
          .copyWith(channel: buildChannel(ChannelUserRole.subscriber));

      final result = await notifier
          .publishMessage(content: 'hi', msgType: 'channel_text');

      expect(result, isFalse);
      // State must not flip to isPublishing; no network call should be attempted.
      expect(container.read(channelDetailProvider).isPublishing, isFalse);
      expect(container.read(channelDetailProvider).messages, isEmpty);
    });

    test('publishMessage returns false when user role is none', () async {
      notifier.debugSetChannelId('1001');
      notifier.state = notifier.state
          .copyWith(channel: buildChannel(ChannelUserRole.none));

      final result = await notifier
          .publishMessage(content: 'hi', msgType: 'channel_text');

      expect(result, isFalse);
      expect(container.read(channelDetailProvider).isPublishing, isFalse);
    });

    test('publishMessage short-circuits before toggling isPublishing '
        'for non-publishing roles', () async {
      notifier.debugSetChannelId('1001');
      notifier.state = notifier.state
          .copyWith(channel: buildChannel(ChannelUserRole.subscriber));

      // If the guard is missing, the notifier would set isPublishing=true,
      // attempt a network call, and then reset it. We assert the state
      // never transitions through isPublishing=true.
      bool sawPublishing = false;
      final sub = container.listen<ChannelDetailState>(
        channelDetailProvider,
        (_, next) {
          if (next.isPublishing) sawPublishing = true;
        },
      );
      addTearDown(sub.close);

      await notifier.publishMessage(content: 'hi', msgType: 'channel_text');

      expect(sawPublishing, isFalse,
          reason: 'Guard must reject before mutating isPublishing');
    });
  });
}
