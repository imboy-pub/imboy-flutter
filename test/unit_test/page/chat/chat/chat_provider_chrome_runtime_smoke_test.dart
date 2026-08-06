/// Phase 2.1.b-2 探查 — chat_provider Chrome 端运行时 build 烟测
///
/// 目的：验证 chat_provider 的 Notifier.build() 在 Chrome 平台能否运行时执行
/// 而不抛异常。如果 GREEN → Phase 2.1.b-4 可安全做 `ref.watch(chatProvider)`
/// 接线；如果 RED → 暴露具体运行时阻塞点（ChatAudioHandler / voicePlayback /
/// MessagingFacade.onlineStatusStream / Connectivity / Timer 等）。
///
/// 不调 `initChatService`（那会触发 SqliteChatService(ref) 创建，是 Phase 2.1.b-3
/// 之外的探查）。仅触发 ChatNotifier 的 build()。
@TestOn('chrome')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';

void main() {
  test('ref.read(chatProvider) 触发 build() 在 chrome 不抛', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 触发 build()。若 ChatAudioHandler / voicePlayback 等依赖在 web 不可用，
    // 这一行会抛 → 失败信息会指出具体阻塞依赖。
    final state = container.read(chatProvider);

    // 默认 state 应当是初始 ChatState（messages=const []）
    expect(state.messages, isEmpty);
    expect(state.connected, isTrue);
    expect(state.composerHeight, 52.0);
  });

  test('ref.read(chatProvider.notifier) 在 chrome 不抛', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(chatProvider.notifier);

    // notifier 实例应当可拿到，syncMessagesToState 是 chat_state 的纯接缝
    expect(notifier, isNotNull);
    // 不调 initChatService（避免 SqliteChatService 副作用）
  });
}
