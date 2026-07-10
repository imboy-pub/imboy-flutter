/// 聊天事件订阅管理器
///
/// 负责管理所有聊天相关的事件流订阅，包括消息接收、状态更新、错误处理等
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/common_events.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../chat_provider.dart';
import '../../widget/chat_input.dart';

/// 聊天事件订阅管理器
///
/// 封装所有事件监听器的创建和取消逻辑
class ChatEventSubscriptionManager {
  /// 构造函数
  ChatEventSubscriptionManager({
    required this.widgetRef,
    required this.peerId,
    required this.peerTitle,
    required this.chatType,
    required this.conversationUk3,
    required this.msgIds,
    required this.editingMessageIdSetter,
    required this.chatInputKey,
    required this.isBurnMessageChecker,
    required this.conversationGetter,
    required this.newGroupNameSetter,
  });

  /// Riverpod WidgetRef
  final WidgetRef widgetRef;

  /// 对方 ID
  final String peerId;

  /// 对方标题
  final String peerTitle;

  /// 聊天类型
  final String chatType;

  /// 会话唯一标识
  final String conversationUk3;

  /// 消息ID集合（用于去重）
  final Set<String> msgIds;

  /// 编辑消息ID设置回调
  final void Function(String?) editingMessageIdSetter;

  /// 聊天输入框的 GlobalKey
  final GlobalKey<ChatInputState> chatInputKey;

  /// 检查是否为阅后即焚消息的回调
  final bool Function(Message) isBurnMessageChecker;

  /// 获取当前会话的回调
  final ConversationModel Function() conversationGetter;

  /// 设置新群组名称的回调
  final void Function(String) newGroupNameSetter;

  // Stream 订阅实例
  StreamSubscription<ChatExtendEvent>? _ssMsgExt;
  StreamSubscription<DataWrapperEvent<dynamic>>? _ssMsg;
  StreamSubscription<DataWrapperEvent<dynamic>>? _ssMsgState;
  StreamSubscription<DataWrapperEvent<dynamic>>? _ssStreamDelta;
  StreamSubscription<ReEditMessageEvent>? _ssReEdit;
  StreamSubscription<AppErrorEvent>? _ssAppError;

  /// AI 流式回复的增量分片（stream_id -> {index -> delta}）。
  /// 按 index 存储：天然去重（同 index 覆盖）+ 乱序容错（拼接前按 index 排序）。
  final Map<String, Map<int, String>> _streamChunks = {};

  /// 设置所有事件监听器
  void setupEventListeners({required VoidCallback onMountedStateChanged}) {
    try {
      _setupChatExtendListener();
      _setupMessageListener();
      _setupStreamDeltaListener();
      _setupMessageStateListener(onMountedStateChanged);
      _setupReEditListener();
      _setupAppErrorListener(onMountedStateChanged);
    } catch (e) {
      iPrint(
        '[chat_event_subscription_manager] _setupAppErrorListener error: $e',
      );
    }
  }

  /// 监听聊天扩展事件（加入群组、清理消息、删除消息等）
  void _setupChatExtendListener() {
    _ssMsgExt = AppEventBus.on<ChatExtendEvent>().listen((
      ChatExtendEvent obj,
    ) async {
      try {
        // 监听新成员加入
        if (obj.type == 'join_group' &&
            obj.payload['groupId'] == peerId &&
            (obj.payload['isFirst'] ?? false) == true) {
          final currentCount = widgetRef.read(chatProvider).memberCount;
          widgetRef
              .read(chatProvider.notifier)
              .updateMemberCount(currentCount + 1);
          final newName = await widgetRef
              .read(chatProvider.notifier)
              .groupTitle(peerId, peerTitle, currentCount + 1);
          newGroupNameSetter(newName);
        } else if (obj.type == 'clean_msg' &&
            ((obj.payload['uk3'] ?? '') == conversationUk3)) {
          // 清空聊天记录：重置分页游标并清空 ChatService 中的消息
          widgetRef.read(chatProvider.notifier).updateNextAutoId(0);
          // 清空 ChatService 中的现有消息，确保 UI 显示最新的空消息列表
          widgetRef.read(chatProvider.notifier).chatService?.setMessages([]);
          iPrint('清空聊天记录: 已清空 ChatService 消息，重新加载');
          // 从数据库重新加载（此时数据库已无消息）
          await widgetRef
              .read(chatProvider.notifier)
              .loadMoreMessages(conversationGetter(), isInitial: true);

          // 触发会话列表刷新，确保会话列表显示已清空
          AppEventBus.fire(
            ChatExtendEvent(
              type: 'refresh_conversations',
              payload: {'uk3': conversationUk3},
            ),
          );
        } else if (obj.type == 'delete_msg' &&
            obj.payload['conversation'] != null) {
          final conv = conversationGetter();
          if (obj.payload['conversation'].id == conv.id) {
            widgetRef
                .read(chatProvider.notifier)
                .chatService
                ?.removeMessageById(obj.payload['msg']?.id as String? ?? '');
          }
        }
      } catch (e) {
        iPrint('[chat_event_subscription_manager] removeMessageById error: $e');
      }
    }, onError: (Object error) {});
  }

  /// 监听新消息事件
  void _setupMessageListener() {
    _ssMsg = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((event) async {
      // 检查数据类型，处理 Message 及其子类型
      // flutter_chat_core 包中的消息类型：TextMessage, ImageMessage 等
      // 它们的 runtimeType 是 'TextMessage' 等，不是抽象的 'Message'
      final dataType = event.dataType.toLowerCase();
      final isMessageType =
          dataType == 'message' ||
          dataType == 'textmessage' ||
          dataType == 'imagemessage' ||
          dataType == 'videomessage' ||
          dataType == 'audiomessage' ||
          dataType == 'filemessage' ||
          dataType == 'locationmessage' ||
          dataType == 'custommessage';

      if (!isMessageType) {
        return;
      }

      // 安全地转换数据
      if (event.data is! Message) {
        return;
      }

      final Message msg = event.data as Message;
      try {
        final String msgConversationUk3 =
            msg.metadata?['conversation_uk3'] as String? ?? '';
        if (msgConversationUk3 != conversationUk3 || msgIds.contains(msg.id)) {
          return;
        }
        msgIds.add(msg.id);
        final i =
            widgetRef
                .read(chatProvider.notifier)
                .chatService
                ?.messages
                .indexWhere((e) => e.id == msg.id) ??
            -1;
        if (i == -1) {
          widgetRef
              .read(chatProvider.notifier)
              .chatService
              ?.insertMessage(
                msg,
                index:
                    widgetRef
                        .read(chatProvider.notifier)
                        .chatService
                        ?.messages
                        .length ??
                    0,
              );
          if (msg is ImageMessage) {
            // 图片画廊已迁移至 Riverpod，由 ChatProvider 处理
          }
        } else {
          // 同 id 已存在——若是 AI 流式占位气泡（TextStreamMessage），
          // 用后端权威定稿（走 QoS 可靠投递的 text 帧）替换，修正流式
          // ephemeral 帧可能的丢字缺失；其他重复消息保持原"跳过"语义。
          final cs = widgetRef.read(chatProvider.notifier).chatService;
          final old = cs?.messages[i];
          if (old is TextStreamMessage) {
            await cs?.updateMessage(old, msg);
            // 定稿替换后清理流式状态，防本地 chunks + 全局 notifier state 泄漏
            _streamChunks.remove(msg.id);
            widgetRef
                .read(chatStreamStateNotifierProvider.notifier)
                .remove(msg.id);
          }
        }
        // 为节省内存，5秒后从 msgIds 移出 msg.id
        Future<dynamic>.delayed(
          const Duration(seconds: 5),
          () => msgIds.remove(msg.id),
        );
      } catch (e) {
        iPrint('[chat_event_subscription_manager] remove error: $e');
      }
    }, onError: (Object error) {});
  }

  /// 监听 AI 流式增量帧（stream_delta），驱动逐字气泡（复活流式渲染死基础设施）
  ///
  /// 首帧插入 TextStreamMessage 占位并 startStream；后续按 index 累积增量 updateStream，
  /// FlyerChatTextStreamMessage 自行 diff 出增量做淡入；is_end 切完成态。
  /// 定稿由后端权威 text 帧经 _setupMessageListener 原地替换（见该方法 else 分支）。
  ///
  /// ⚠️ 全程无 await：同一 event loop 内串行原子处理，避免同 streamId 多帧因 await
  /// 让步交错导致丢字/错序/状态回退（insertMessage 内部同步且有 isDisposed 保护）。
  void _setupStreamDeltaListener() {
    _ssStreamDelta = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
      event,
    ) {
      if (event.dataType != 'stream_delta') {
        return;
      }
      final data = event.data;
      if (data is! Map) {
        return;
      }
      final payload = data['payload'];
      if (payload is! Map) {
        iPrint(
          '[chat_event_subscription_manager] stream_delta payload 非 Map，丢弃',
        );
        return;
      }
      final streamId =
          payload['stream_id']?.toString() ?? data['id']?.toString() ?? '';
      if (streamId.isEmpty) {
        return;
      }
      // 归属判定：帧 type 须与当前会话一致；C2C 还需 from==peerId(对端 uid)；
      // C2S(bot) 会话 uk3 不依赖 peerId(from 是 bot 字面标识)，同 chatType 即归属。
      final frameType = data['type']?.toString() ?? '';
      if (frameType != chatType) {
        return;
      }
      final from = data['from']?.toString() ?? '';
      if (chatType == 'C2C' && from != peerId) {
        return;
      }
      try {
        final cs = widgetRef.read(chatProvider.notifier).chatService;
        if (cs == null) {
          return;
        }
        final notifier = widgetRef.read(
          chatStreamStateNotifierProvider.notifier,
        );
        final delta = payload['delta']?.toString() ?? '';
        final isEnd = payload['is_end'] == true;
        final indexRaw = payload['index'];
        final index = indexRaw is int ? indexRaw : 0;

        // 按 index 存增量（去重/乱序容错）；chunks 空 = 该 stream 首帧
        final chunks = _streamChunks.putIfAbsent(
          streamId,
          () => <int, String>{},
        );
        if (chunks.isEmpty && !cs.messages.any((m) => m.id == streamId)) {
          final createdRaw = data['created_at'];
          final createdAt = createdRaw is int
              ? DateTime.fromMillisecondsSinceEpoch(createdRaw)
              : DateTime.now();
          final streamMsg = TextStreamMessage(
            id: streamId,
            authorId: from,
            streamId: streamId,
            createdAt: createdAt,
            metadata: {'conversation_uk3': conversationUk3},
          );
          // 不 await：insertMessage 内部同步，保持本回调原子性
          cs.insertMessage(streamMsg, index: cs.messages.length);
          notifier.startStream(streamId);
        }

        chunks[index] = delta;
        // 按 index 升序拼接累积全文（widget 自行 diff 出增量做淡入）
        final acc = _joinChunks(chunks);
        notifier.updateStream(streamId, acc);

        // 结束帧：切完成态（定稿权威文本走 text 帧覆盖 + 清理，见 _setupMessageListener）
        if (isEnd) {
          notifier.completeStream(streamId, acc);
        }
      } catch (e) {
        iPrint('[chat_event_subscription_manager] stream_delta error: $e');
      }
    }, onError: (Object error) {});
  }

  /// 按 index 升序拼接 delta 分片为累积全文
  String _joinChunks(Map<int, String> chunks) {
    final keys = chunks.keys.toList()..sort();
    final buf = StringBuffer();
    for (final k in keys) {
      buf.write(chunks[k]);
    }
    return buf.toString();
  }

  /// 监听消息状态更新事件
  void _setupMessageStateListener(VoidCallback onMountedStateChanged) {
    _ssMsgState = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((event) {
      // 检查数据类型，只处理消息列表类型的事件
      if (event.dataType != 'MessageList' && event.dataType != 'messages') {
        return;
      }

      // 安全地转换数据
      if (event.data is! List) {
        return;
      }

      final List<Message> e = (event.data as List).cast<Message>();
      try {
        if (e.isEmpty) return;
        Message msg = e.first;
        iPrint('收到消息状态更新事件: msgId=${msg.id}, type=${msg.runtimeType}');
        final i =
            widgetRef
                .read(chatProvider.notifier)
                .chatService
                ?.messages
                .indexWhere((e) => e.id == msg.id) ??
            -1;
        final messageCount =
            widgetRef
                .read(chatProvider.notifier)
                .chatService
                ?.messages
                .length ??
            0;
        iPrint('在消息列表中查找消息: index=$i, 总消息数=$messageCount');
        if (i > -1 &&
            widgetRef.read(chatProvider.notifier).chatService != null) {
          final old = widgetRef
              .read(chatProvider.notifier)
              .chatService!
              .messages[i];
          iPrint('更新消息UI: ${msg.id}');
          widgetRef
              .read(chatProvider.notifier)
              .chatService!
              .updateMessage(
                widgetRef.read(chatProvider.notifier).chatService!.messages[i],
                msg,
              );
          final didBecomeSeen =
              old.status != MessageStatus.seen &&
              msg.status == MessageStatus.seen;
          if (didBecomeSeen &&
              isBurnMessageChecker(msg) &&
              (msg.metadata?['burn_read_at'] ?? 0) == 0) {
            widgetRef
                .read(chatProvider.notifier)
                .markBurnReadAt(
                  conversationGetter(),
                  msg.id,
                  readAtMs: DateTimeHelper.millisecond(),
                );
          }
        } else {
          iPrint('消息未找到或组件未挂载: msgId=${msg.id}');
        }
      } catch (e) {
        iPrint('[chat_event_subscription_manager] iPrint error: $e');
      }
    }, onError: (Object error) {});
  }

  /// 监听重新编辑消息事件
  void _setupReEditListener() {
    _ssReEdit = AppEventBus.on<ReEditMessageEvent>().listen((msg) async {
      try {
        if (msg.messageId != null && msg.messageId!.isNotEmpty) {
          // 设置当前正在编辑的消息ID
          editingMessageIdSetter(msg.messageId);
          iPrint('重新编辑消息: messageId=${msg.messageId}, text=${msg.text}');
        }
        // 将消息文本填充到输入框
        chatInputKey.currentState?.setText(msg.text);
      } catch (e) {
        iPrint('[chat_event_subscription_manager] setText error: $e');
      }
    }, onError: (Object error) {});
  }

  /// 监听全局错误事件（如 not_a_friend）
  void _setupAppErrorListener(VoidCallback onMountedStateChanged) {
    _ssAppError = AppEventBus.on<AppErrorEvent>().listen((error) {
      try {
        // 只处理聊天相关的错误
        if (error.errorType == 'not_a_friend' ||
            error.message.contains('非好友')) {
          // 这里需要 context 来显示 SnackBar，由调用者处理
          iPrint('✅ [AppErrorEvent] 收到错误: ${error.message}');
        }
      } catch (e) {
        iPrint('[chat_event_subscription_manager] iPrint error: $e');
      }
    }, onError: (Object error) {});
  }

  /// 显示错误 SnackBar（需要由调用者提供 BuildContext）
  /// 3 秒后自动消失，无需额外确认按钮（避免出现"点了无反应"的伪按钮）
  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// 取消所有订阅
  void dispose() {
    _ssMsgExt?.cancel();
    _ssMsg?.cancel();
    _ssMsgState?.cancel();
    _ssStreamDelta?.cancel();
    _ssReEdit?.cancel();
    _ssAppError?.cancel();
    // 清理本会话未完成（未定稿）的流式状态，防全局 notifier state 泄漏。
    // try 兜住：dispose 时页面可能已 unmount，widgetRef.read 可能抛。
    try {
      final notifier = widgetRef.read(chatStreamStateNotifierProvider.notifier);
      for (final id in _streamChunks.keys) {
        notifier.remove(id);
      }
    } catch (_) {}
    _streamChunks.clear();
  }
}
