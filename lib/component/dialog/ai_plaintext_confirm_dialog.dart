/// LT02-SEC-01（AI-ID=B）：AI 明文会话首次发送前的显式确认弹窗。
///
/// 当前实现变体为 AI-ID=B；当前决策包已建立，但用户尚未选择。弹窗必须
/// 明示「本会话消息和附件不是端到端加密」；用户拒绝 = 不落确认记录 =
/// 共享门 fail-closed（消息按策略加密/拒发）。昵称、头像或 AI badge 的
/// 展示不构成身份确认——只有本弹窗的用户显式操作才落五元组确认记录。
///
/// 弹窗由 [registerAiPlaintextPromptHandler] 注册进
/// `AiPlaintextGate.promptHandler`（ChatPage initState 单次调用）；
/// 非 UI 语境（消息重试等）不注册使用，保持不弹窗、不放行。
library;

import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/service/e2ee/ai_plaintext_gate.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/i18n/strings.g.dart';

/// 弹出 AI 明文会话确认；返回 true 仅当用户显式点击「已知晓，继续发送」。
///
/// 安全默认（review CONCERN-a）：**取消**键是 isDefaultAction——回车/键盘
/// 焦点默认走拒绝方向；放行明文必须用户显式点按确认键。
Future<bool> showAiPlaintextConfirmDialog(
  BuildContext context, {
  required String targetUid,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(t.common.aiPlaintextConfirmTitle),
      content: Column(
        children: [
          const SizedBox(height: AppSpacing.small),
          Text(t.common.aiPlaintextConfirmBody),
          const SizedBox(height: AppSpacing.small),
          Text(
            t.common.aiPlaintextConfirmNote,
            style: ctx.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosOrange,
            ),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t.common.aiPlaintextConfirmOk),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t.common.aiPlaintextConfirmCancel),
        ),
      ],
    ),
  );
  return result == true;
}

/// 把本弹窗注册为共享身份门的 UI 确认处理器（幂等）。
///
/// 经全局 [navigatorKey] 取 context：消息发送与附件上传的判定点在
/// service 层，不持有 BuildContext。取不到 context（页面未挂载等）
/// 一律按用户拒绝处理（fail-closed）。
///
/// C1（review 条件，2026-09-09）：确认表 schema 由 store 懒初始化自动
/// 创建（见 [SqliteAiPlaintextConfirmationStore]，不依赖本调用点）；
/// 此处仅做一次防御性预热，让首条 AI 会话的判定零额外 DDL 开销。
void registerAiPlaintextPromptHandler() {
  if (AiPlaintextGate.promptHandler != null) return;
  AiPlaintextGate.promptHandler = (req) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    return showAiPlaintextConfirmDialog(ctx, targetUid: req.targetUid);
  };
  unawaited(
    SqliteAiPlaintextConfirmationStore().ensureSchema().then(
      (_) {},
      onError: (_) {},
    ),
  );
}
