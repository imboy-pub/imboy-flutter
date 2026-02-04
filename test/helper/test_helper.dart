/// 测试辅助工具类
///
/// 用于解决测试环境中的依赖问题（如 StorageService、SharedPreferences 等）
library;

import 'package:imboy/store/model/conversation_model.dart';

/// 会话模型测试辅助类
///
/// 提供不依赖 StorageService 的 content 计算方法
class ConversationTestHelper {
  /// 计算会话内容（不读取草稿）
  ///
  /// 在测试环境中使用，跳过 StorageService 的草稿读取
  static String computeContentWithoutDraft(ConversationModel conv) {
    // 处理系统提示信息
    String sysPrompt = _parseSysPrompt(conv.payload?['sys_prompt'] ?? '');
    if (sysPrompt.isNotEmpty) {
      return sysPrompt;
    }

    // 跳过草稿检查（测试环境）
    String str = '未知消息';

    // 优先检查 lastMsgStatus 字段（撤回状态 30-39）
    if (conv.lastMsgStatus != null) {
      if (conv.lastMsgStatus == 30) {
        // 对方撤回 (status=30)
        String title = conv.title;
        if (title.isEmpty) {
          title = conv.payload?['peer_name'] ?? '';
        }
        String suffix = '';
        if (title.length > 12) {
          title = title.substring(0, 12);
          suffix = '...';
        }
        String displayName = '"$title$suffix"';
        return '"$displayName" 撤回了一条消息';
      } else if (conv.lastMsgStatus == 31) {
        // 自己撤回 (status=31)
        return '你撤回了一条消息';
      }
    }

    // 普通消息类型
    if (conv.msgType == 'text' || conv.msgType == '') {
      return conv.subtitle;
    } else if (conv.msgType == 'quote') {
      return conv.subtitle;
    } else if (conv.msgType == 'image') {
      str = '[图片]';
    } else if (conv.msgType == 'file') {
      str = '[文件]';
    } else if (conv.msgType == 'voice' || conv.msgType == 'audio') {
      str = '[语音]';
    } else if (conv.msgType == 'video') {
      str = '[视频]';
    } else if (conv.msgType == 'location') {
      // 位置消息：从 payload 中提取位置标签和地址
      final locationLabel = conv.payload?['location_label'] ?? '';
      final locationAddress = conv.payload?['location_address'] ?? '';
      if (locationLabel.isNotEmpty || locationAddress.isNotEmpty) {
        str = '[位置]';
        if (locationLabel.isNotEmpty) {
          str += ' $locationLabel';
        }
        if (locationAddress.isNotEmpty) {
          str += ' $locationAddress';
        }
      }
    }

    return str;
  }

  /// 解析系统提示
  static String _parseSysPrompt(String sysPrompt) {
    if (sysPrompt.isEmpty) {
      return '';
    }

    // 简单的字符串检查（测试环境）
    if (sysPrompt.contains('in_denylist') ||
        sysPrompt.contains('not_a_friend')) {
      return '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。';
    }

    // 如果是 JSON 字符串，尝试解析
    if (sysPrompt.startsWith('{')) {
      if (sysPrompt.contains('"in_denylist":true') ||
          sysPrompt.contains('"not_a_friend":true')) {
        return '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。';
      }
    }

    return sysPrompt;
  }

  /// 创建测试用的会话模型
  ///
  /// 提供预配置的测试数据
  static ConversationModel createTestConversation({
    String? peerId,
    String? type,
    String? title,
    String? avatar,
    String? msgType,
    String? subtitle,
    int? lastMsgStatus,
    String? lastMsgId,
    int? unreadNum,
    Map<String, dynamic>? payload,
  }) {
    return ConversationModel(
      id: 1,
      peerId: peerId ?? 'test_user_123',
      type: type ?? 'C2C',
      title: title ?? '测试用户',
      avatar: avatar ?? 'https://example.com/avatar.png',
      msgType: msgType ?? 'text',
      subtitle: subtitle ?? '这是一条测试消息',
      lastMsgId: lastMsgId ?? 'msg_123',
      lastTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      unreadNum: unreadNum ?? 0,
      lastMsgStatus: lastMsgStatus,
      payload: payload,
      isShow: 1,
    );
  }
}
