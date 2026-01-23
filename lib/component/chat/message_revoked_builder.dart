import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart' show UserRepoLocal;

class RevokedMessageBuilder extends StatelessWidget {
  const RevokedMessageBuilder({
    super.key,
    required this.user,
    required this.message,
  });

  final User user;
  final CustomMessage message;

  @override
  Widget build(BuildContext context) {
    // 获取消息元数据
    final Map<String, dynamic> metadata = message.metadata ?? {};
    final int? status = metadata['status'] as int?;
    final bool userIsAuthor = user.id == message.authorId;
    final String text = metadata['text'] ?? '';
    final int nowMs = DateTimeHelper.millisecond();

    // 调试输出
    iPrint(
      '撤回消息渲染: msgId=${message.id}, status=$status, userIsAuthor=$userIsAuthor',
    );
    iPrint('消息元数据: ${metadata.toString()}');

    // WebSocket API v2.0: 根据 status 字段确定撤回类型
    bool isPeerRevoked = IMBoyMessageStatus.isPeerRevoked(status);
    bool isMyRevoked = IMBoyMessageStatus.isMyRevoked(status);

    // 检查是否可以重新编辑（仅限自己撤回的消息且在2小时内）
    bool canEdit =
        isMyRevoked &&
        userIsAuthor &&
        text.isNotEmpty &&
        ((nowMs - message.createdAt!.millisecondsSinceEpoch) < 120 * 60 * 1000);

    // 重新编辑按钮
    Widget editButton = canEdit
        ? GestureDetector(
            onTap: () {
              iPrint("触发重新编辑: msgId=${message.id}, text=$text");
              AppEventBus.fire(
                ReEditMessageEvent(text: text, messageId: message.id),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t.reEdit,
                style: TextStyle(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchConversationAndContact(),
      builder: (context, snapshot) {
        String nickname = '';

        if (isPeerRevoked) {
          // 对方撤回的消息
          if (snapshot.connectionState == ConnectionState.waiting) {
            nickname = '"..."';
          } else {
            // 优先使用会话模型中的title，其次使用联系人信息
            String contactTitle = _getContactTitleFromConversation(
              snapshot.data?['conversation'],
              metadata,
            );
            nickname = '"$contactTitle"';
          }
        } else {
          // 自己撤回的消息
          nickname = t.you;
        }

        return Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: (isMyRevoked || userIsAuthor)
                      ? const EdgeInsets.only(right: 10, left: 0)
                      : const EdgeInsets.only(left: 50),
                  child: Text(
                    // 使用字符串替换传递撤回者信息
                    nickname == t.you
                        ? t.messageWasWithdrawn
                        : t.messageWasWithdrawnWithTitle(param: nickname),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              editButton,
            ],
          ),
        );
      },
    );
  }

  /// 获取会话模型和联系人信息
  Future<Map<String, dynamic>?> _fetchConversationAndContact() async {
    try {
      // 从消息元数据中获取会话UK3
      String conversationUk3 = message.metadata?['conversation_uk3'] ?? '';
      // 根据会话UK3解析出类型和peerId
      final parts = conversationUk3.split('_');
      if (parts.length >= 3) {
        // 将类型转换为大写，因为数据库中存储的是大写
        String type = parts[0].toUpperCase();
        final String peerId = parts[1] == UserRepoLocal.to.currentUid
            ? parts[2]
            : parts[1];

        iPrint(
          '解析会话UK3: type=$type, peerId=$peerId, ${UserRepoLocal.to.currentUid} ',
        );

        // 获取会话模型
        final conversation = await ConversationRepo().findByPeerId(
          type,
          peerId,
        );

        iPrint('获取到的会话模型: ${conversation?.title}');
        return {'conversation': conversation};
      }

      return null;
    } catch (e) {
      iPrint('获取会话模型失败: $e');
      return null;
    }
  }

  /// 获取联系人标题，优先使用会话模型中的title
  /// 联系人title显示规则： remark > nickname > account
  String _getContactTitleFromConversation(
    ConversationModel? conversation,
    Map<String, dynamic> metadata,
  ) {
    // 优先使用会话模型中的title
    if (conversation != null && conversation.title.trim().isNotEmpty) {
      return conversation.title;
    }

    // 如果没有会话和联系人信息，尝试从元数据中获取
    String peerName = metadata['peer_name'] ?? '';
    if (peerName.trim().isNotEmpty) {
      return peerName;
    }

    // 最后使用用户ID的前几位
    return message.authorId.substring(0, math.min(8, message.authorId.length));
  }
}
