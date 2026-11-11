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
  final controller = ChatExportController(
    gateway: const SharePlusChatShareGateway(),
    tempFileWriter: IoChatExportTempFileWriter(),
    isFlagEnabled: () =>
        AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1),
    isEncryptedConversation: () =>
        isEncryptedConversationForExport(chatType: chatType, toId: toId),
    confirmLeaveEncryptedEnvironment: () =>
        showChatExportE2eeConfirmDialog(context),
    translations: currentChatExportPlaceholderTranslations,
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
