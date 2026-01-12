import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';
import 'package:imboy/page/mine/user_collect/user_collect_logic.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'message_handling_mixin.dart';

/// UI事件处理相关的Mixin
/// 负责处理消息的点击、长按、双击等UI事件
mixin UIEventHandlerMixin<T extends StatefulWidget> on State<T> {
  // 获取当前聊天页面逻辑对象
  ChatLogic get logic => getx.Get.find<ChatLogic>();
  
  // 获取当前用户ID
  String get currentUserId => UserRepoLocal.to.currentUid;
  
  // 获取聊天类型
  String get chatType => widget is UIEventHandlerMixinState 
      ? (widget as UIEventHandlerMixinState).chatType 
      : throw UnimplementedError('chatType must be provided');
  
  // 获取对方ID
  String get peerId => widget is UIEventHandlerMixinState 
      ? (widget as UIEventHandlerMixinState).peerId 
      : throw UnimplementedError('peerId must be provided');
  
  // 获取对方头像
  String get peerAvatar => widget is UIEventHandlerMixinState 
      ? (widget as UIEventHandlerMixinState).peerAvatar 
      : throw UnimplementedError('peerAvatar must be provided');
  
  // 获取对方标题
  String get peerTitle => widget is UIEventHandlerMixinState 
      ? (widget as UIEventHandlerMixinState).peerTitle 
      : throw UnimplementedError('peerTitle must be provided');

  /// 消息点击事件
  void onMessageTap(
    BuildContext context,
    Message message, {
    int? index,
    TapUpDetails? details,
  }) {
    iPrint('onMessageTap: ${message.id}');
    
    if (message is ImageMessage) {
      // 图片消息点击，打开图片浏览器
      _openImageGallery(context, message);
    } else if (message is FileMessage) {
      // 文件消息点击，打开文件
      _handleFileMessage(context, message);
    } else if (message is CustomMessage) {
      // 自定义消息点击，根据类型处理
      _handleCustomMessage(context, message);
    } else if (message is TextMessage) {
      // 文本消息点击，检查是否有链接
      _handleTextMessage(context, message);
    }
  }

  /// 消息长按事件
  void onMessageLongPress(
    BuildContext context,
    Message message, {
    int? index,
    LongPressStartDetails? details,
  }) {
    iPrint('onMessageLongPress: ${message.id}');
    
    // 显示消息操作菜单
    _showMessageActionMenu(context, message);
  }

  /// 消息双击事件
  void onMessageDoubleTap(BuildContext context, Message message, {int? index}) {
    iPrint('onMessageDoubleTap: ${message.id}');
    
    // 双击消息，如果是文本消息则复制文本
    if (message is TextMessage) {
      _copyTextMessage(message);
    } else if (message is FileMessage) {
      // 文件消息双击，打开文件
      _handleFileMessage(context, message);
    } else if (message is ImageMessage) {
      // 图片消息双击，打开图片浏览器
      _openImageGallery(context, message);
    } else if (message is CustomMessage) {
      // 自定义消息双击，根据类型处理
      String txt = message.metadata?['quote_text'] ?? '';
      if (txt.isNotEmpty) {
        _handleTextMessage(context, TextMessage(
          authorId: message.authorId,
          createdAt: message.createdAt,
          id: message.id,
          text: txt,
        ));
      }
    }
  }

  /// 消息头像点击事件
  void onAvatarTap(BuildContext context, User user) {
    iPrint('onAvatarTap: ${user.id}');
    
    // 点击头像，查看用户详情
    _showUserProfile(context, user);
  }

  /// 消息状态点击事件
  void onMessageStatusTap(
    BuildContext context,
    Message message, {
    int? index,
    TapUpDetails? details,
  }) {
    iPrint('onMessageStatusTap: ${message.id}');
    
    // 点击消息状态，如果是发送中或已发送状态，重新发送
    if (message.status == MessageStatus.sending ||
        message.status == MessageStatus.sent) {
      _retrySendMessage(context, message);
    }
  }

  /// 打开图片浏览器
  void _openImageGallery(BuildContext context, ImageMessage message) {
    final imageGalleryLogic = getx.Get.put(IMBoyImageGalleryController());
    
    // 获取当前聊天中的所有图片消息
    final chatController = logic.chatController;
    if (chatController == null) {
      return;
    }
    
    final imageMessages = chatController.messages
        .whereType<ImageMessage>()
        .cast<ImageMessage>()
        .toList();
    
    // 找到当前图片在列表中的索引
    final currentIndex = imageMessages.indexWhere((img) => img.id == message.id);
    
    // 打开图片浏览器
    if (currentIndex >= 0 && currentIndex < imageMessages.length) {
      final imageMessage = imageMessages[currentIndex];
      imageGalleryLogic.onImagePressed(imageMessage.id, imageMessage.source);
    }
  }

  /// 处理文件消息
  void _handleFileMessage(BuildContext context, FileMessage message) {
    // 显示文件操作选项
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
                title: const Text('打开文件'),
                onTap: () {
                  Navigator.pop(context);
                  // logic.openFile(message.name, message.source);
                  // 暂时注释掉，等待ChatLogic中添加该方法
                  EasyLoading.showToast('文件打开功能暂未实现');
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('下载文件'),
                onTap: () {
                  Navigator.pop(context);
                  logic.saveFile(message.name, message.source);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('分享文件'),
                onTap: () {
                  Navigator.pop(context);
                  // logic.shareFile(message.name, message.source);
                  // 暂时注释掉，等待ChatLogic中添加该方法
                  EasyLoading.showToast('文件分享功能暂未实现');
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
        // 名片消息，查看用户详情
        final uid = message.metadata?['uid'];
        if (uid != null) {
          _showUserProfileById(context, uid);
        }
        break;
      case 'location':
        // 位置消息，打开地图
        _showLocationOnMap(context, message);
        break;
      case 'voice':
        // 语音消息，播放语音
        // 语音消息不需要详情弹窗，直接播放
        _playVoiceMessage(message);
        break;
      case 'video':
        // 视频消息，播放视频
        _playVideoMessage(context, message);
        break;
      default:
        // 其他自定义消息，显示详情
        // if (message.metadata?['custom_type'] != 'voice') {
        //   _showCustomMessageDetails(context, message);
        // }
    }
  }

  /// 处理文本消息
  void _handleTextMessage(BuildContext context, TextMessage message) {
    // 检查文本中是否包含链接
    final text = message.text;
    if (_containsUrl(text)) {
      // 如果包含链接，显示打开链接的选项
      _showLinkOptions(context, text);
    }
  }

  /// 复制文本消息
  void _copyTextMessage(TextMessage message) {
    final text = message.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      EasyLoading.showToast('已复制到剪贴板');
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
        onReply: () {
          _handleReplyMessage(message);
        },
        onCopy: () {
          _handleCopyMessage(message);
        },
        onEdit: () {
          _handleEditMessage(message);
        },
        onDelete: () {
          _handleDeleteMessage(context, message);
        },
        onForward: () {
          _handleForwardMessage(message);
        },
        onReaction: (emoji) {
          _handleMessageReaction(message, emoji);
        },
        onRevoke: message.authorId == currentUserId ? () {
          iPrint('点击撤回按钮，先关闭底部菜单');
          _handleRevokeMessage(message);
        } : null,
        onSave: _canSaveMessage(message) ? () {
          _handleSaveMessage(message);
        } : null,
        onCollect: _canCollectMessage(message) ? () {
          _handleCollectMessage(message);
        } : null,
        onDeleteForEveryone: message.authorId == currentUserId ? () {
          _handleDeleteMessageForEveryone(context, message);
        } : null,
        canEdit: canEditMessage(message),
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  /// 显示用户详情
  void _showUserProfile(BuildContext context, User user) {
    // 导航到用户详情页面
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => UserProfilePage(userId: user.id),
    //   ),
    // );
  }

  /// 根据用户ID显示用户详情
  void _showUserProfileById(BuildContext context, String userId) {
    // 导航到用户详情页面
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => UserProfilePage(userId: userId),
    //   ),
    // );
  }

  /// 在地图上显示位置
  void _showLocationOnMap(BuildContext context, CustomMessage message) {
    // final latitude = message.metadata?['latitude'];
    // final longitude = message.metadata?['longitude'];
    // if (latitude != null && longitude != null) {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => MapPage(
    //         latitude: latitude,
    //         longitude: longitude,
    //       ),
    //     ),
    //   );
    // }
  }

  /// 播放语音消息（支持点击播放/暂停/继续播放）
  void _playVoiceMessage(CustomMessage message) {
    try {
      final voiceUrl = message.metadata?['uri']?.toString() ?? '';
      final duration = message.metadata?['duration_ms'];

      if (voiceUrl.isEmpty) {
        EasyLoading.showToast('语音文件无效');
        return;
      }

      // 调用逻辑层播放语音
      logic.playVoice(
        voiceUrlOrPath: voiceUrl,
        messageId: message.id,
        duration: duration is int ? duration : 0,
      );

      if (duration is int && duration > 0) {
        final seconds = (duration / 1000).round();
        // 只在首次播放时显示时长提示
        EasyLoading.showToast('语音时长: $seconds 秒');
      }
    } catch (e) {
      iPrint('播放语音消息异常: $e');
      EasyLoading.showError('播放失败: ${e.toString()}');
    }
  }

  /// 播放视频消息
  void _playVideoMessage(BuildContext context, CustomMessage message) {
    // final videoUrl = message.metadata?['uri'];
    // if (videoUrl != null) {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => VideoPlayerPage(videoUrl: videoUrl),
    //     ),
    //   );
    // }
  }

  /// 检查文本是否包含URL
  bool _containsUrl(String text) {
    // 简单的URL检测
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
                title: const Text('打开链接'),
                onTap: () {
                  Navigator.pop(context);
                  // logic.openUrl(text);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制链接'),
                onTap: () {
                  Navigator.pop(context);
                  // Clipboard.setData(ClipboardData(text: text));
                  EasyLoading.showToast('已复制链接');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('分享链接'),
                onTap: () {
                  Navigator.pop(context);
                  // logic.shareText(text);
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
    // 调用逻辑层重试发送消息
    logic.retryMessage(message.id, chatType);
  }

  /// 处理回复消息
  void _handleReplyMessage(Message message) {
    // 设置回复消息
    if (this is UIEventHandlerMixinState) {
      (this as UIEventHandlerMixinState).setQuoteMessage?.call(message);
    }
  }

  /// 处理删除消息
  void _handleDeleteMessage(BuildContext context, Message message) {
    // 调用消息处理相关的删除方法
    // 这里需要与MessageHandlingMixin协作
    if (this is UIEventHandlerMixinState) {
      (this as UIEventHandlerMixinState).onDeleteMessageForMe?.call(context, message);
    }
  }

  /// 处理撤回消息
  void _handleRevokeMessage(Message message) {
    // 调用消息处理相关的撤回方法
    // 这里需要与MessageHandlingMixin协作
    try {
      // 直接调用当前State对象的onRevokeMessage方法
      if (this is UIEventHandlerMixinState) {
        (this as UIEventHandlerMixinState).onRevokeMessage?.call(message);
      }
    } catch (e, stack) {
      iPrint('处理撤回消息异常: $e\n$stack');
      EasyLoading.showError('撤回操作异常，请重试');
    }
  }

  /// 处理转发消息
  void _handleForwardMessage(Message message) {
    // 调用消息处理相关的转发方法
    // 这里需要与MessageHandlingMixin协作
    if (this is UIEventHandlerMixinState) {
      (this as UIEventHandlerMixinState).onForwardMessage?.call(message);
    }
  }

  /// 处理收藏消息
  void _handleCollectMessage(Message message) {
    debugPrint("_handleCollectMessage: 开始收藏消息 ${message.id}, 类型: ${message.runtimeType}");
    
    // 调用消息处理相关的收藏方法
    // 这里需要与MessageHandlingMixin协作
    try {
      if (widget is UIEventHandlerMixinState) {
        debugPrint("_handleCollectMessage: 调用onCollectMessage回调");
        (widget as UIEventHandlerMixinState).onCollectMessage?.call(message);
      } else {
        debugPrint("_handleCollectMessage: widget不是UIEventHandlerMixinState类型，尝试直接调用collectMessage");
        // 如果widget不是UIEventHandlerMixinState类型，直接调用collectMessage方法
        if (this is MessageHandlingMixin) {
          (this as MessageHandlingMixin).collectMessage(message);
        } else {
          debugPrint("_handleCollectMessage: 当前对象也不是MessageHandlingMixin类型，收藏失败");
        }
      }
    } catch (e, stack) {
      debugPrint("_handleCollectMessage: 收藏消息异常: $e\n$stack");
      // 显示错误提示
      EasyLoading.showError('收藏失败，请重试');
    }
  }

  /// 处理复制消息
  void _handleCopyMessage(Message message) {
    if (message is TextMessage) {
      _copyTextMessage(message);
    }
  }

  /// 处理保存消息
  void _handleSaveMessage(Message message) {
    // 调用消息处理相关的保存方法
    // 这里需要与MessageHandlingMixin协作
    if (this is UIEventHandlerMixinState) {
      (this as UIEventHandlerMixinState).onSaveMessageContent?.call(message);
    }
  }

  /// 处理编辑消息
  void _handleEditMessage(Message message) {
    if (message is TextMessage) {
      // 设置编辑消息
      if (this is UIEventHandlerMixinState) {
        (this as UIEventHandlerMixinState).onSetEditMessage?.call(message);
      }
    }
  }

  /// 处理消息反应
  void _handleMessageReaction(Message message, String emoji) {
    // 处理消息反应，发送反应消息
    iPrint('Message reaction: $emoji for message ${message.id}');
    // 这里需要实现消息反应的逻辑
    EasyLoading.showToast('已发送反应: $emoji');
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
    // 使用UserCollectLogic的静态方法检查消息是否可以收藏
    int kind = UserCollectLogic.getCollectKind(message);
    debugPrint("_canCollectMessage: message type=${message.runtimeType}, kind=$kind");
    return kind > 0;
  }

  /// 处理删除消息（所有人）
  void _handleDeleteMessageForEveryone(BuildContext context, Message message) {
    // 处理删除所有人的消息
    iPrint('Delete message for everyone: ${message.id}');
    // 这里需要实现删除所有人的消息的逻辑
    if (this is UIEventHandlerMixinState) {
      (this as UIEventHandlerMixinState).onDeleteMessageForEveryone?.call(context, message);
    }
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
}

/// UI事件处理Mixin状态接口
/// 用于提供必要的状态信息给UIEventHandlerMixin
abstract class UIEventHandlerMixinState {
  String get chatType;
  String get peerId;
  String get peerAvatar;
  String get peerTitle;
  void Function(Message?)? get setQuoteMessage;
  void Function(BuildContext, Message)? get onDeleteMessageForMe;
  void Function(BuildContext, Message)? get onDeleteMessageForEveryone;
  void Function(Message)? get onRevokeMessage;
  void Function(Message)? get onForwardMessage;
  void Function(Message)? get onCollectMessage;
  void Function(Message)? get onSaveMessageContent;
  void Function(TextMessage)? get onSetEditMessage;
}