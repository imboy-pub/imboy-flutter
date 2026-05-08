/// 消息快捷操作菜单组件
///
/// 提供右键/辅助点击时的快捷操作菜单
library;

import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';

/// 消息快捷操作菜单组件
class MessageQuickActionMenu {
  /// 显示重试菜单（用于发送失败的消息）
  static void showRetryMenu({
    required BuildContext context,
    required Message message,
    required VoidCallback onRetry,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.refresh, color: AppColors.iosOrange),
                title: Text(t.chatResend),
                onTap: () {
                  Navigator.pop(context);
                  onRetry();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.iosRed),
                title: Text(t.chatDeleteMessage),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 显示快捷操作菜单
  static void showQuickActionMenu({
    required BuildContext context,
    required Message message,
    required VoidCallback onReply,
    required Future<void> Function(String, String) onSaveFile,
    required VoidCallback onCopy,
    required VoidCallback onForward,
    required VoidCallback onCollect,
    required VoidCallback onRevoke,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isMe = message.authorId == UserRepoLocal.to.currentUid;
        // 检查是否在撤回有效期内（例如2分钟）
        final canRevoke =
            isMe &&
            DateTime.now().difference(
                  DateTime.fromMillisecondsSinceEpoch(
                    message.createdAt!.millisecondsSinceEpoch,
                  ),
                ) <
                const Duration(minutes: 2);

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // 顶部指示条
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // 复制 (仅文本)
                if (message is TextMessage)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded),
                    title: Text(t.buttonCopy),
                    onTap: () {
                      Navigator.pop(context);
                      onCopy();
                    },
                  ),

                // 转发
                ListTile(
                  leading: const Icon(Icons.forward_rounded),
                  title: Text(t.forward),
                  onTap: () {
                    Navigator.pop(context);
                    onForward();
                  },
                ),

                // 收藏
                ListTile(
                  leading: const Icon(Icons.favorite_border_rounded),
                  title: Text(t.favorites),
                  onTap: () {
                    Navigator.pop(context);
                    onCollect();
                  },
                ),

                // 回复
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: Text(t.reply),
                  onTap: () {
                    Navigator.pop(context);
                    onReply();
                  },
                ),

                // 保存 (图片/视频/文件)
                if (message is ImageMessage ||
                    message is FileMessage ||
                    message is VideoMessage)
                  ListTile(
                    leading: const Icon(Icons.save_alt_rounded),
                    title: Text(t.chatSaveImage), // 这里可能需要通用的 save 文本
                    onTap: () async {
                      Navigator.pop(context);
                      await onSaveFile(
                        message.metadata?['name'] ?? message.id,
                        message.metadata?['uri'] ??
                            message.metadata?['source'] ??
                            '',
                      );
                    },
                  ),

                const Divider(),

                // 撤回 (仅限自己且在有效期内)
                if (canRevoke)
                  ListTile(
                    leading: Icon(
                      Icons.undo_rounded,
                      color: AppColors.iosOrange,
                    ),
                    title: Text(t.revoke),
                    onTap: () {
                      Navigator.pop(context);
                      onRevoke();
                    },
                  ),

                // 删除
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.iosRed,
                  ),
                  title: Text(t.buttonDelete),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
