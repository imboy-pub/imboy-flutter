/// 消息快捷操作菜单组件
///
/// 提供右键/辅助点击时的快捷操作菜单
library;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';

import 'package:imboy/i18n/strings.g.dart';

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
                leading: const Icon(Icons.refresh, color: Colors.orange),
                title: Text(t.chatResend),
                onTap: () {
                  Navigator.pop(context);
                  onRetry();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
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
              // 根据消息类型显示不同的选项
              if (message is TextMessage) ...[
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(t.buttonCopy),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.text));
                    EasyLoading.showToast(t.copied);
                  },
                ),
              ],
              if (message is ImageMessage) ...[
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: Text(t.chatSaveImage),
                  onTap: () async {
                    Navigator.pop(context);
                    await onSaveFile(
                      message.text ?? message.id,
                      message.source,
                    );
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(t.chatReply),
                onTap: () {
                  Navigator.pop(context);
                  onReply();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
