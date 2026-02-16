/// 迁移示例：如何使用新的处理器模块
///
/// 这个文件展示如何在现有的 ChatNotifier 中集成新的处理器
/// 不需要修改原有的 chat_provider.dart，可以作为参考
library;

import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';

// 导入新的处理器模块
import 'package:imboy/page/chat/chat/providers/chat_audio_handler.dart';
import 'package:imboy/page/chat/chat/providers/chat_message_sender.dart';
import 'package:imboy/page/chat/chat/providers/chat_message_loader.dart';
import 'package:imboy/page/chat/chat/providers/chat_e2ee_handler.dart';

// 导入现有服务
import 'package:imboy/store/model/conversation_model.dart';

/// 迁移指南示例
///
/// 在现有的 ChatNotifier 中添加处理器集成：
///
/// ```dart
/// class ChatNotifier extends _$ChatNotifier {
///   // 1. 添加处理器实例
///   late final ChatAudioHandler _audioHandler;
///   late final ChatMessageSender _messageSender;
///   late final ChatMessageLoader _messageLoader;
///   late final ChatE2EEHandler _e2eeHandler;
///
///   @override
///   ChatState build() {
///     // 2. 初始化处理器
///     _audioHandler = ChatAudioHandler();
///     _messageSender = ChatMessageSender();
///     _messageLoader = ChatMessageLoader();
///     _e2eeHandler = ChatE2EEHandler();
///
///     // 设置消息获取回调
///     _audioHandler.setMessagesGetter(() => _chatService?.messages.toList() ?? []);
///
///     ref.onDispose(_dispose);
///     return const ChatState();
///   }
///
///   void _dispose() {
///     _audioHandler.dispose();
///     _messageLoader.dispose();
///   }
/// }
/// ```

/// 使用处理器替换原有方法的示例
///
/// === 原始代码 ===
/// ```dart
/// Future<void> playVoice({
///   required String voiceUrlOrPath,
///   required String messageId,
///   required int duration,
/// }) async {
///   await voicePlaybackService.play(
///     audioPath: voiceUrlOrPath,
///     messageId: messageId,
///     durationMs: duration,
///   );
/// }
/// ```
///
/// === 迁移后代码 ===
/// ```dart
/// Future<void> playVoice({
///   required String voiceUrlOrPath,
///   required String messageId,
///   required int duration,
/// }) async {
///   await _audioHandler.playVoice(
///     voiceUrlOrPath: voiceUrlOrPath,
///     messageId: messageId,
///     duration: duration,
///   );
/// }
/// ```

/// 消息发送迁移示例
///
/// === 原始代码 (_sendWsMsg 方法约 200 行) ===
/// ```dart
/// Future<bool> _sendWsMsg(MessageModel obj) async {
///   if (obj.status != IMBoyMessageStatus.sending) {
///     return true;
///   }
///   // ... 200+ 行加密和发送逻辑
/// }
/// ```
///
/// === 迁移后代码 ===
/// ```dart
/// Future<bool> _sendWsMsg(MessageModel obj) async {
///   final result = await _messageSender.send(obj);
///   return result == MessageSendResult.success;
/// }
/// ```

/// 消息加载迁移示例
///
/// === 原始代码 (loadMoreMessages 方法约 120 行) ===
/// ```dart
/// Future<List<Message>> loadMoreMessages(
///   ConversationModel obj, {
///   bool isInitial = false,
/// }) async {
///   // ... 分页和转换逻辑
/// }
/// ```
///
/// === 迁移后代码 ===
/// ```dart
/// Future<List<Message>> loadMoreMessages(
///   ConversationModel conversation, {
///   bool isInitial = false,
/// }) async {
///   if (isInitial) {
///     state = state.copyWith(
///       nextAutoId: 0,
///       hasMoreMessage: true,
///       currentConversationId: conversation.uk3,
///     );
///     _chatService?.setMessages([]);
///   }
///
///   if (state.isLoading) return [];
///   state = state.copyWith(isLoading: true);
///
///   final existingIds = _chatService?.messages.map((e) => e.id).toSet() ?? {};
///   final result = await _messageLoader.loadMore(
///     conversation,
///     state.nextAutoId,
///     existingIds,
///   );
///
///   state = state.copyWith(
///     isLoading: false,
///     hasMoreMessage: result.hasMore,
///     nextAutoId: result.nextCursor ?? state.nextAutoId,
///   );
///
///   if (result.messages.isNotEmpty) {
///     if (isInitial) {
///       _chatService?.setMessages(result.messages);
///     } else {
///       _chatService?.insertAllMessages(result.messages, index: 0);
///     }
///   }
///
///   return result.messages;
/// }
/// ```

/// E2EE 加密迁移示例
///
/// === 原始代码 ===
/// ```dart
/// final needEncrypt = action.isEmpty &&
///     E2EEService.shouldEncryptOutgoingPayload(obj.type ?? 'C2C', payloadWithTs);
///
/// if (needEncrypt) {
///   // ... 100+ 行加密逻辑
///   final deviceKeys = await E2EEService.getUserDevicePublicKeys(obj.toId ?? '');
///   // ...
/// }
/// ```
///
/// === 迁移后代码 ===
/// ```dart
/// final needEncrypt = _e2eeHandler.shouldEncrypt(
///   obj.type ?? 'C2C',
///   payloadWithTs,
///   action,
/// );
///
/// if (needEncrypt) {
///   final result = await _e2eeHandler.encrypt(
///     obj.type ?? 'C2C',
///     obj.toId ?? '',
///     payload,
///   );
///
///   if (result.success) {
///     e2ee = result.e2eeMetadata;
///     finalPayload = result.ciphertext;
///   }
/// }
/// ```

/// 迁移步骤总结
///
/// 1. 在 ChatNotifier 类顶部添加处理器实例声明
/// 2. 在 build() 方法中初始化处理器
/// 3. 在 ref.onDispose() 中调用处理器的 dispose()
/// 4. 逐个方法替换为处理器调用
/// 5. 运行测试确保功能正常
/// 6. 删除原有的重复代码
///
/// 预期效果：
/// - chat_provider.dart 行数: 2462 → ~800 行
/// - 可维护性大幅提升
/// - 单元测试更容易编写
class MigrationExample {
  /// 这是一个示例类，展示迁移模式
  /// 实际使用时请参考上面的文档注释

  final ChatAudioHandler audioHandler = ChatAudioHandler();
  final ChatMessageSender messageSender = ChatMessageSender();
  final ChatMessageLoader messageLoader = ChatMessageLoader();
  final ChatE2EEHandler e2eeHandler = ChatE2EEHandler();

  /// 示例：使用音频处理器
  Future<void> examplePlayVoice() async {
    await audioHandler.playVoice(
      voiceUrlOrPath: '/path/to/audio.mp3',
      messageId: 'msg_123',
      duration: 5000,
    );
  }

  /// 示例：使用消息加载器
  Future<List<Message>> exampleLoadMessages(
    ConversationModel conversation,
  ) async {
    final result = await messageLoader.loadMore(
      conversation,
      0, // cursor
      {}, // existingIds
    );
    return result.messages;
  }

  /// 示例：使用 E2EE 处理器
  Future<Map<String, dynamic>?> exampleEncrypt(
    String chatType,
    String recipientId,
    Map<String, dynamic> payload,
  ) async {
    final result = await e2eeHandler.encrypt(chatType, recipientId, payload);
    if (result.success) {
      return {
        'e2ee': result.e2eeMetadata,
        'ciphertext': result.ciphertext,
      };
    }
    return null;
  }

  /// 清理资源
  void dispose() {
    audioHandler.dispose();
    messageLoader.dispose();
  }
}
