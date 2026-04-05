import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/events/common_events.dart';

ChannelMessageModel _buildMessage({
  required String id,
  bool pinned = false,
}) {
  return ChannelMessageModel(
    id: id,
    channelId: 'ch-test',
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
      final messageA = _buildMessage(id: 'msg-a', pinned: false);
      final messageB = _buildMessage(id: 'msg-b', pinned: true);
      notifier.state = notifier.state.copyWith(messages: [messageA, messageB]);

      notifier.updateMessagePinned('msg-a', true);

      final state = container.read(channelDetailProvider);
      expect(state.messages.firstWhere((msg) => msg.id == 'msg-a').isPinned,
          isTrue);
      expect(state.messages
          .firstWhere((msg) => msg.id == 'msg-b')
          .isPinned, isTrue);
    });

    test('removeMessageLocally drops the targeted message only', () {
      final messageA = _buildMessage(id: 'msg-a');
      final messageB = _buildMessage(id: 'msg-b');
      notifier.state = notifier.state.copyWith(messages: [messageA, messageB]);

      notifier.removeMessageLocally('msg-a');

      final state = container.read(channelDetailProvider);
      expect(state.messages.length, 1);
      expect(state.messages.single.id, 'msg-b');
    });

    test('handleMessageDeletedEvent removes matching channel message', () {
      final message = _buildMessage(id: 'msg-1');
      notifier.state = notifier.state.copyWith(messages: [message]);
      notifier.debugSetChannelId('ch-test');

      notifier.handleMessageDeletedEvent(
        const ChannelMessageDeletedEvent(
          channelId: 'ch-test',
          messageId: 'msg-1',
          reason: 'deleted',
        ),
      );

      final state = container.read(channelDetailProvider);
      expect(state.messages, isEmpty);
    });

    test('handleMessageDeletedEvent ignores other channels', () {
      final message = _buildMessage(id: 'msg-1');
      notifier.state = notifier.state.copyWith(messages: [message]);
      notifier.debugSetChannelId('ch-test');

      notifier.handleMessageDeletedEvent(
        const ChannelMessageDeletedEvent(
          channelId: 'other',
          messageId: 'msg-1',
          reason: 'deleted',
        ),
      );

      final state = container.read(channelDetailProvider);
      expect(state.messages.length, 1);
    });
  });
}
