/// 消息快捷操作菜单组件
///
/// 提供右键/辅助点击时的快捷操作菜单
library;

import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 消息快捷操作菜单组件
class MessageQuickActionMenu {
  /// 显示重试菜单（用于发送失败的消息）
  static void showRetryMenu({
    required BuildContext context,
    required Message message,
    required VoidCallback onRetry,
    required VoidCallback onDelete,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildListTile(
                context: context,
                icon: CupertinoIcons.refresh,
                iconColor: AppColors.iosOrange,
                title: t.chat.chatResend,
                onTap: () {
                  Navigator.pop(context);
                  onRetry();
                },
              ),
              _buildListTile(
                context: context,
                icon: CupertinoIcons.delete,
                iconColor: AppColors.iosRed,
                title: t.common.chatDeleteMessage,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
              AppSpacing.verticalRegular,
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
    showCupertinoModalPopup<void>(
      context: context,
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
          decoration: const BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSpacing.verticalSmall,
                // 顶部指示条
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.iosGray5,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AppSpacing.verticalRegular,

                // 复制 (仅文本)
                if (message is TextMessage)
                  _buildListTile(
                    context: context,
                    icon: CupertinoIcons.doc_on_doc,
                    title: t.common.buttonCopy,
                    onTap: () {
                      Navigator.pop(context);
                      onCopy();
                    },
                  ),

                // 转发
                _buildListTile(
                  context: context,
                  icon: CupertinoIcons.forward,
                  title: t.chat.forward,
                  onTap: () {
                    Navigator.pop(context);
                    onForward();
                  },
                ),

                // 收藏
                _buildListTile(
                  context: context,
                  icon: CupertinoIcons.heart,
                  title: t.main.favorites,
                  onTap: () {
                    Navigator.pop(context);
                    onCollect();
                  },
                ),

                // 回复
                _buildListTile(
                  context: context,
                  icon: CupertinoIcons.reply,
                  title: t.chat.reply,
                  onTap: () {
                    Navigator.pop(context);
                    onReply();
                  },
                ),

                // 保存 (图片/视频/文件)
                if (message is ImageMessage ||
                    message is FileMessage ||
                    message is VideoMessage)
                  _buildListTile(
                    context: context,
                    icon: CupertinoIcons.arrow_down_to_line,
                    title: t.common.chatSaveImage,
                    onTap: () async {
                      Navigator.pop(context);
                      await onSaveFile(
                        parseModelString(
                          message.metadata?['name'],
                          defaultValue: message.id,
                        ),
                        parseModelString(
                          message.metadata?['uri'] ??
                              message.metadata?['source'],
                        ),
                      );
                    },
                  ),

                // 分割线
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: CupertinoColors.separator.withValues(alpha: 0.3),
                ),

                // 撤回 (仅限自己且在有效期内)
                if (canRevoke)
                  _buildListTile(
                    context: context,
                    icon: CupertinoIcons.arrow_uturn_left,
                    iconColor: AppColors.iosOrange,
                    title: t.chat.revoke,
                    onTap: () {
                      Navigator.pop(context);
                      onRevoke();
                    },
                  ),

                // 删除
                _buildListTile(
                  context: context,
                  icon: CupertinoIcons.delete,
                  iconColor: AppColors.iosRed,
                  title: t.common.buttonDelete,
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),

                AppSpacing.verticalRegular,
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建列表项（替代 Material ListTile）
  static Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.primary, size: 24),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(fontSize: FontSizeType.body.size)),
          ],
        ),
      ),
    );
  }
}
