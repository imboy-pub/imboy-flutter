import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';
import 'package:imboy/page/mine/user_collect/user_collect_provider.dart';

/// UI事件处理器
///
/// 负责处理聊天页面的各种UI交互事件
/// 这是一个纯辅助类，不管理状态，只处理事件
class UIEventHandler {
  /// 构造函数
  UIEventHandler({
    required this.ref,
    required this.chatType,
    required this.peerId,
    required this.peerAvatar,
    required this.peerTitle,
    required this.currentUserId,
    required this.onReplyMessage,
    required this.onDeleteMessage,
    required this.onRevokeMessage,
    required this.onForwardMessage,
    required this.onCollectMessage,
    required this.onSaveMessageContent,
    required this.onSetEditMessage,
    required this.onDeleteMessageForEveryone,
    required this.onSetQuoteMessage,
    required this.onPlayVoice,
    required this.onSaveFile,
    required this.onRetryMessage,
    required this.chatController,
  });

  /// WidgetRef 用于访问 Provider
  final WidgetRef ref;

  /// 聊天类型
  final String chatType;

  /// 对方ID
  final String peerId;

  /// 对方头像
  final String peerAvatar;

  /// 对方标题
  final String peerTitle;

  /// 当前用户ID
  final String currentUserId;

  /// 聊天控制器
  final dynamic chatController;

  // ===== 回调函数 =====

  /// 回复消息回调
  final void Function(Message message) onReplyMessage;

  /// 删除消息回调
  final void Function(BuildContext context, Message message) onDeleteMessage;

  /// 撤回消息回调
  final void Function(Message message) onRevokeMessage;

  /// 转发消息回调
  final void Function(Message message) onForwardMessage;

  /// 收藏消息回调
  final void Function(Message message) onCollectMessage;

  /// 保存消息内容回调
  final void Function(Message message) onSaveMessageContent;

  /// 设置编辑消息回调
  final void Function(TextMessage message) onSetEditMessage;

  /// 删除消息（所有人）回调
  final void Function(BuildContext context, Message message)
  onDeleteMessageForEveryone;

  /// 设置引用消息回调
  final void Function(Message? message) onSetQuoteMessage;

  /// 播放语音回调
  final void Function({
    required String voiceUrlOrPath,
    required String messageId,
    required int duration,
  })
  onPlayVoice;

  /// 保存文件回调
  final void Function(String name, String uri) onSaveFile;

  /// 重试消息回调
  final void Function(String messageId, String chatType) onRetryMessage;

  // ===== 公共事件处理方法 =====

  /// 处理消息点击事件
  void handleMessageTap(
    BuildContext context,
    Message message, {
    int? index,
    TapUpDetails? details,
  }) {
    iPrint('onMessageTap: ${message.id}');

    if (message is ImageMessage) {
      _openImageGallery(context, message);
    } else if (message is FileMessage) {
      _handleFileMessage(context, message);
    } else if (message is CustomMessage) {
      _handleCustomMessage(context, message);
    } else if (message is TextMessage) {
      _handleTextMessage(context, message);
    }
  }

  /// 处理消息长按事件
  void handleMessageLongPress(
    BuildContext context,
    Message message, {
    int? index,
    LongPressStartDetails? details,
  }) {
    iPrint('onMessageLongPress: ${message.id}');
    _showMessageActionMenu(context, message);
  }

  /// 处理消息双击事件
  void handleMessageDoubleTap(
    BuildContext context,
    Message message, {
    int? index,
  }) {
    iPrint('onMessageDoubleTap: ${message.id}');

    if (message is TextMessage) {
      _copyTextMessage(message);
    } else if (message is FileMessage) {
      _handleFileMessage(context, message);
    } else if (message is ImageMessage) {
      _openImageGallery(context, message);
    } else if (message is CustomMessage) {
      final txt = message.metadata?['quote_text'] ?? '';
      if (txt.isNotEmpty) {
        _handleTextMessage(
          context,
          TextMessage(
            authorId: message.authorId,
            createdAt: message.createdAt,
            id: message.id,
            text: txt,
          ),
        );
      }
    }
  }

  /// 处理头像点击事件
  void handleAvatarTap(BuildContext context, User user) {
    iPrint('onAvatarTap: ${user.id}');
    _showUserProfile(context, user);
  }

  /// 处理消息状态点击事件
  void handleMessageStatusTap(
    BuildContext context,
    Message message, {
    int? index,
    TapUpDetails? details,
  }) {
    iPrint('onMessageStatusTap: ${message.id}');

    if (message.status == MessageStatus.sending ||
        message.status == MessageStatus.sent) {
      _retrySendMessage(context, message);
    }
  }

  // ===== 私有方法 =====

  /// 打开图片浏览器
  void _openImageGallery(BuildContext context, ImageMessage message) {
    final imageGalleryNotifier = ref.read(imageGalleryProvider.notifier);

    if (chatController == null) {
      return;
    }

    final imageMessages = chatController.messages
        .whereType<ImageMessage>()
        .cast<ImageMessage>()
        .toList();

    final currentIndex = imageMessages.indexWhere(
      (img) => img.id == message.id,
    );

    if (currentIndex >= 0 && currentIndex < imageMessages.length) {
      final imageMessage = imageMessages[currentIndex];
      imageGalleryNotifier.onImagePressed(imageMessage.id, imageMessage.source);
    }
  }

  /// 处理文件消息
  void _handleFileMessage(BuildContext context, FileMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(t.chatOpenFile),
                onTap: () {
                  Navigator.pop(context);
                  EasyLoading.showToast(t.fileOpenNotImplemented);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(t.chatDownloadFile),
                onTap: () {
                  Navigator.pop(context);
                  onSaveFile(message.name, message.source);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(t.chatShareFile),
                onTap: () {
                  Navigator.pop(context);
                  EasyLoading.showToast(t.fileShareNotImplemented);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理自定义消息
  void _handleCustomMessage(BuildContext context, CustomMessage message) {
    final customType = message.metadata?['custom_type'];

    switch (customType) {
      case 'visit_card':
        final uid = message.metadata?['uid'];
        if (uid != null) {
          _showUserProfileById(context, uid);
        }
        break;
      case 'location':
        _showLocationOnMap(context, message);
        break;
      case 'voice':
        _playVoiceMessage(message);
        break;
      case 'video':
        _playVideoMessage(context, message);
        break;
    }
  }

  /// 处理文本消息
  void _handleTextMessage(BuildContext context, TextMessage message) {
    final text = message.text;
    if (_containsUrl(text)) {
      _showLinkOptions(context, text);
    }
  }

  /// 复制文本消息
  void _copyTextMessage(TextMessage message) {
    final text = message.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      EasyLoading.showToast(t.copiedToClipboard);
    }
  }

  /// 显示消息操作菜单
  void _showMessageActionMenu(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MessageActionMenu(
        message: message,
        isSentByMe: message.authorId == currentUserId,
        onReply: () => onReplyMessage(message),
        onCopy: () => _handleCopyMessage(message),
        onEdit: () => _handleEditMessage(message),
        onDelete: () => onDeleteMessage(context, message),
        onForward: () => onForwardMessage(message),
        onReaction: (emoji) => _handleMessageReaction(message, emoji),
        onRevoke: message.authorId == currentUserId
            ? () {
                iPrint('点击撤回按钮，先关闭底部菜单');
                onRevokeMessage(message);
              }
            : null,
        onSave: _canSaveMessage(message)
            ? () => onSaveMessageContent(message)
            : null,
        onCollect: _canCollectMessage(message)
            ? () => onCollectMessage(message)
            : null,
        onDeleteForEveryone: message.authorId == currentUserId
            ? () => onDeleteMessageForEveryone(context, message)
            : null,
        canEdit: canEditMessage(message),
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  /// 显示用户详情
  void _showUserProfile(BuildContext context, User user) {
    // TODO: 实现用户详情页面跳转
    iPrint('显示用户详情: ${user.id}');
  }

  /// 根据用户ID显示用户详情
  void _showUserProfileById(BuildContext context, String userId) {
    // TODO: 实现用户详情页面跳转
    iPrint('显示用户详情: $userId');
  }

  /// 在地图上显示位置
  void _showLocationOnMap(BuildContext context, CustomMessage message) {
    // TODO: 实现地图页面跳转
    iPrint('显示位置消息: ${message.id}');
  }

  /// 播放语音消息
  void _playVoiceMessage(CustomMessage message) {
    try {
      final voiceUrl = message.metadata?['uri']?.toString() ?? '';
      final duration = message.metadata?['duration_ms'];

      if (voiceUrl.isEmpty) {
        EasyLoading.showToast(t.voiceFileInvalid);
        return;
      }

      onPlayVoice(
        voiceUrlOrPath: voiceUrl,
        messageId: message.id,
        duration: duration is int ? duration : 0,
      );

      if (duration is int && duration > 0) {
        final seconds = (duration / 1000).round();
        EasyLoading.showToast('${t.voiceDuration}: $seconds ${t.seconds}');
      }
    } catch (e) {
      iPrint('播放语音消息异常: $e');
      EasyLoading.showError('${t.playbackFailed}: ${e.toString()}');
    }
  }

  /// 播放视频消息
  void _playVideoMessage(BuildContext context, CustomMessage message) {
    // TODO: 实现视频播放页面跳转
    iPrint('播放视频消息: ${message.id}');
  }

  /// 检查文本是否包含URL
  bool _containsUrl(String text) {
    final urlPattern = RegExp(
      r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[/\w .-]*/?',
    );
    return urlPattern.hasMatch(text);
  }

  /// 显示链接选项
  void _showLinkOptions(BuildContext context, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: Text(t.chatOpenLink),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现打开链接
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(t.chatCopyLink),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: text));
                  EasyLoading.showToast(t.copiedLink);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(t.chatShareLink),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现分享链接
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 重试发送消息
  void _retrySendMessage(BuildContext context, Message message) {
    onRetryMessage(message.id, chatType);
  }

  /// 处理复制消息
  void _handleCopyMessage(Message message) {
    if (message is TextMessage) {
      _copyTextMessage(message);
    }
  }

  /// 处理编辑消息
  void _handleEditMessage(Message message) {
    if (message is TextMessage) {
      onSetEditMessage(message);
    }
  }

  /// 处理消息反应
  void _handleMessageReaction(Message message, String emoji) {
    iPrint('Message reaction: $emoji for message ${message.id}');
    EasyLoading.showToast('${t.reactionSent}: $emoji');
  }

  /// 检查消息是否可以保存
  bool _canSaveMessage(Message message) {
    if (message is ImageMessage) {
      return true;
    } else if (message is FileMessage) {
      return true;
    } else if (message is CustomMessage) {
      final customType = message.metadata?['custom_type'] ?? '';
      return customType == 'video' || customType == 'audio';
    }
    return false;
  }

  /// 检查消息是否可以收藏
  bool _canCollectMessage(Message message) {
    int kind = UserCollectHelper.getCollectKind(message);
    debugPrint(
      "_canCollectMessage: message type=${message.runtimeType}, kind=$kind",
    );
    return kind > 0;
  }

  /// 检查消息是否可以编辑
  ///
  /// 规则：
  /// 1. 必须是当前用户发送的消息
  /// 2. 必须是文本消息
  /// 3. 发送时间在 15 分钟内（与后端保持一致）
  bool canEditMessage(Message message) {
    if (message.authorId != currentUserId) return false;
    if (message is! TextMessage) return false;

    final nowMs = DateTimeHelper.millisecond();
    final messageTimeMs = message.createdAt?.millisecondsSinceEpoch ?? nowMs;
    final timeDiffMs = nowMs - messageTimeMs;

    return timeDiffMs < 15 * 60 * 1000; // 15分钟 = 900000毫秒
  }

  /// 设置引用消息
  void setQuoteMessage(Message? message) {
    onSetQuoteMessage(message);
  }
}
