import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';

void main() {
  test('scroll errors reach the caller instead of claiming success', () async {
    final provider = Provider<SqliteChatService>(SqliteChatService.new);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(provider);
    addTearDown(service.dispose);
    service.attachScrollMethods(
      scrollToMessageId:
          (
            id, {
            duration = Duration.zero,
            curve = Curves.linear,
            alignment = 0,
            offset = 0,
          }) async {
            throw StateError('scroll failed');
          },
      scrollToIndex: (
        index, {
        duration = Duration.zero,
        curve = Curves.linear,
        alignment = 0,
        offset = 0,
      }) async {},
    );
    await expectLater(service.scrollToMessage('target'), throwsStateError);
  });
}
