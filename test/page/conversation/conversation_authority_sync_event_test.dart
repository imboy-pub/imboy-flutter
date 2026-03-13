import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/conversation_api.dart';

class _FakeConversationApi extends ConversationApi {
  _FakeConversationApi({
    this.entries = const <Map<String, dynamic>>[],
    this.shouldThrow = false,
  });

  final List<Map<String, dynamic>> entries;
  final bool shouldThrow;

  @override
  Future<List<Map<String, dynamic>>> listMine({int? lastServerTs}) async {
    if (shouldThrow) {
      throw StateError('fake conversation authority failure');
    }
    return entries;
  }
}

class _TestConversationNotifier extends ConversationNotifier {
  _TestConversationNotifier({required ConversationApi api})
    : super(conversationApi: api);
}

void main() {
  group('Conversation authority sync event', () {
    test('fires success event for empty authoritative list', () async {
      final events = <ConversationAuthoritySyncEvent>[];
      final sub = AppEventBus.on<ConversationAuthoritySyncEvent>().listen(
        events.add,
      );

      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(
              api: _FakeConversationApi(entries: const []),
            ),
          ),
        ],
      );

      await container
          .read(conversationProvider.notifier)
          .syncAuthoritativeConversations(trigger: 'page_init');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      container.dispose();

      expect(events.length, 1);
      final event = events.single;
      expect(event.trigger, 'page_init');
      expect(event.source, 'server_authoritative_pull');
      expect(event.fetchedCount, 0);
      expect(event.syncedCount, 0);
      expect(event.success, isTrue);
    });

    test('fires failed event when authoritative api throws', () async {
      final events = <ConversationAuthoritySyncEvent>[];
      final sub = AppEventBus.on<ConversationAuthoritySyncEvent>().listen(
        events.add,
      );

      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(
              api: _FakeConversationApi(shouldThrow: true),
            ),
          ),
        ],
      );

      await container
          .read(conversationProvider.notifier)
          .syncAuthoritativeConversations(trigger: 'websocket_connected');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      container.dispose();

      expect(events.length, 1);
      final event = events.single;
      expect(event.trigger, 'websocket_connected');
      expect(event.source, 'server_authoritative_pull');
      expect(event.fetchedCount, 0);
      expect(event.syncedCount, 0);
      expect(event.success, isFalse);
    });
  });
}
