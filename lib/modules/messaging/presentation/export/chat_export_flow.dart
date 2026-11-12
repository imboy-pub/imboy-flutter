/// 导出平台总装入口（W3-J / chat_export_share_v1）。
///
/// Central Wiring 一行接线（ChatPage → MessageMultiSelectActionBar.onExport）：
///
/// ```dart
/// onExport: (messages) => runChatExportFlow(
///   context,
///   conversationUk3: _conversationUk3,
///   conversationTitle: widget.peerTitle,
///   messages: messages,
///   chatType: widget.type,
///   toId: widget.peerId,
/// ),
/// ```
///
/// 组装平台默认依赖：SharePlus 网关 + 系统临时目录 + rollout flag 判定
/// （`chat_export_share_v1`，默认 false）+ E2EEService 只读加密判定 +
/// E2EE 确认弹窗 + 当前 locale 占位文案；流程终态 toast 反馈
/// （取消/未开放静默）。
library;

import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_controller.dart';
import 'package:imboy/modules/messaging/infrastructure/export/chat_export_e2ee_guard.dart';
import 'package:imboy/modules/messaging/infrastructure/export/chat_export_message_mapper.dart';
import 'package:imboy/modules/messaging/infrastructure/export/chat_export_temp_file_io.dart';
import 'package:imboy/modules/messaging/infrastructure/export/share_plus_chat_share_gateway.dart';
import 'package:imboy/modules/messaging/presentation/export/chat_export_e2ee_confirm_dialog.dart';
import 'package:imboy/modules/messaging/presentation/export/chat_export_translations.dart';

/// 执行「导出并系统分享」全流程（单次导出新建一次性 controller）。
///
/// 返回终态供调用方/测试断言；`flagDisabled`（未灰度）与用户取消路径
/// **静默**（无 toast、零副作用）。
Future<ChatExportResult> runChatExportFlow(
  BuildContext context, {
  required String conversationUk3,
  required String conversationTitle,
  required List<core.Message> messages,
  required String chatType,
  String? toId,
  Future<String> Function(core.UserID authorId)? senderNameResolver,
}) async {
  // 灰度前置判定（W5-G3-2）：关闭时直接走既有 flagDisabled 静默路径，
  // 不做逐消息映射（每条一次 DB 发送者名查询）等无谓工作。controller
  // 内的同款判定保留，作注入型调用的防御（双保险）。
  if (!AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1)) {
    return ChatExportResult(status: ChatExportStatus.flagDisabled);
  }
  final controller = ChatExportController(
    gateway: const SharePlusChatShareGateway(),
    tempFileWriter: IoChatExportTempFileWriter(),
    isFlagEnabled: () =>
        AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1),
    isEncryptedConversation: () => isEncryptedConversationForExport(
      chatType: chatType,
      toId: toId,
      // S1-L4：历史 E2EE 行判定用本次导出消息级 metadata（无新 DB 查询）——
      // 部署策略翻为不加密时，历史密文行仍必须走「离开加密环境」确认。
      messages: messages,
    ),
    confirmLeaveEncryptedEnvironment: () async {
      // 本闭包在 controller 第 3 步才被调用——此前已跨过逐消息映射
      // （每条 DB 查询）与加密判定的多次 await，context 可能已卸载。
      // 卸载即无法取得用户同意：fail-closed 返回 false（视同拒绝，
      // 走 e2eeDeclined 静默零副作用路径，W5-G3-1）。
      if (!context.mounted) return false;
      return showChatExportE2eeConfirmDialog(context);
    },
    translations: currentChatExportPlaceholderTranslations,
    // 诊断日志缝（W5-G3 复审）：application 层保持纯 Dart 不 import
    // Flutter，iPrint 在此（presentation 层）接线，与下方错误码日志同惯例。
    diagnosticLogger: iPrint,
  );
  final entries = await chatExportEntriesFromMessages(
    messages,
    senderNameResolver: senderNameResolver ?? defaultChatExportSenderName,
  );
  final result = await controller.export(
    ChatExportRequest(
      conversationUk3: conversationUk3,
      conversationTitle: conversationTitle,
      entries: entries,
    ),
  );
  _toastFor(result);
  return result;
}

void _toastFor(ChatExportResult result) {
  switch (result.status) {
    case ChatExportStatus.shared:
      unawaited(AppLoading.showToast(t.chat.exportShared));
    case ChatExportStatus.error:
      // 稳定错误码进日志（iPrint，与 messaging 模块其余日志同惯例）便于
      // 排查；UI 统一 exportFailed（按错误码差异化 i18n 提示留待后续）。
      iPrint(
        '⚠️ [chat_export] 导出失败: ${result.errorCode ?? 'unknown'}'
        '（stable code: temp_file_write_failed / share_failed / '
        'share_invalid_params）',
      );
      unawaited(AppLoading.showToast(t.chat.exportFailed));
    case ChatExportStatus.nothingToExport:
      unawaited(AppLoading.showToast(t.chat.exportNothingToExport));
    case ChatExportStatus.canceled:
    case ChatExportStatus.e2eeDeclined:
    case ChatExportStatus.flagDisabled:
      // 用户主动取消 / 未灰度：静默，零打扰。
      break;
  }
}
