import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';

/// 文本流消息的实时状态管理
class ChatStreamStateNotifier extends Notifier<Map<String, StreamState>> {
  @override
  Map<String, StreamState> build() => {};

  void startStream(String messageId) {
    state = {...state, messageId: const StreamStateLoading()};
  }

  void updateStream(String messageId, String accumulatedText) {
    state = {...state, messageId: StreamStateStreaming(accumulatedText)};
  }

  void completeStream(String messageId, String finalText) {
    state = {...state, messageId: StreamStateCompleted(finalText)};
  }

  void errorStream(String messageId, Object error, {String? partial}) {
    state = {
      ...state,
      messageId: StreamStateError(error, accumulatedText: partial),
    };
  }

  StreamState getState(String messageId) {
    return state[messageId] ?? const StreamStateLoading();
  }

  void clearCompleted() {
    state = Map<String, StreamState>.fromEntries(
      state.entries.where((e) => e.value is! StreamStateCompleted),
    );
  }
}

/// 全局文本流消息状态 Provider
final chatStreamStateNotifierProvider =
    NotifierProvider<ChatStreamStateNotifier, Map<String, StreamState>>(
      ChatStreamStateNotifier.new,
    );
