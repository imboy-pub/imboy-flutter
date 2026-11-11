/// E2EE 会话导出前「内容将离开加密环境」安全确认弹窗
/// （W3-J / chat_export_share_v1，EXP-02）。
///
/// PLAN §4.6 冻结合同：E2EE 会话必须在系统分享前明确提示内容将离开
/// 加密环境。**取消 = 零副作用**：弹窗只回答 bool，不落盘、不调网关；
/// 「确定」也不会直接导出——只把决定交回 [ChatExportController] 流程。
///
/// 稳定 Key（W3-K 集成测试定位用，勿改值）：
/// - `export_e2ee_confirm`：弹窗本体；
/// - `export_confirm_ok`：确认（仍要导出）按钮；
/// - `export_confirm_cancel`：取消按钮。
///
/// 安全默认：**取消键 isDefaultAction**——回车/焦点默认走拒绝方向；
/// 离开加密环境必须用户显式点确认（与 AI 明文确认弹窗同一 fail-safe
/// 范式）。
library;

import 'package:flutter/cupertino.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 弹窗稳定 Key 契约（W3-K 依赖，勿改值）。
abstract final class ChatExportDialogKeys {
  static const Key confirm = ValueKey('export_e2ee_confirm');
  static const Key ok = ValueKey('export_confirm_ok');
  static const Key cancel = ValueKey('export_confirm_cancel');
}

/// 弹窗内容（独立 Widget 便于 widget 测试直接 pump）。
class ChatExportE2eeConfirmDialog extends StatelessWidget {
  const ChatExportE2eeConfirmDialog({super.key, this.onConfirm, this.onCancel});

  /// 点「仍要导出」；null = 测试/预览语境（不响应）。
  final VoidCallback? onConfirm;

  /// 点「取消」；null = 测试/预览语境（不响应）。
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      key: ChatExportDialogKeys.confirm,
      title: Text(t.chat.exportE2eeConfirmTitle),
      content: Column(
        children: [
          const SizedBox(height: AppSpacing.small),
          Text(t.chat.exportE2eeConfirmBody),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          key: ChatExportDialogKeys.ok,
          onPressed: () => onConfirm?.call(),
          child: Text(t.chat.exportConfirmOk),
        ),
        CupertinoDialogAction(
          key: ChatExportDialogKeys.cancel,
          // 安全默认：回车/焦点默认走取消（拒绝离开加密环境）。
          isDefaultAction: true,
          onPressed: () => onCancel?.call(),
          child: Text(t.chat.exportConfirmCancel),
        ),
      ],
    );
  }
}

/// 弹出 E2EE 导出确认；返回 true 仅当用户显式点「仍要导出」。
///
/// barrierDismissible=false：误触外围不得被解释为同意。
Future<bool> showChatExportE2eeConfirmDialog(BuildContext context) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ChatExportE2eeConfirmDialog(
      onConfirm: () => Navigator.of(ctx).pop(true),
      onCancel: () => Navigator.of(ctx).pop(false),
    ),
  );
  return result == true;
}
