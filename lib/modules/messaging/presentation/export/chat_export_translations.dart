/// 导出占位文案的 i18n 桥接（W3-J / chat_export_share_v1）。
///
/// 把 `t.chat.exportPlaceholder*` / `t.chat.exportLabel*` 映射为
/// [ChatExportPlaceholders.applyTranslations] 的键空间——W1-C 格式化器
/// 纯函数签名不变，运行时输出随当前 locale。
library;

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_placeholders.dart';

/// 当前 locale 的导出占位文案映射（每次导出前重新求值，切语言即时生效）。
Map<String, String> currentChatExportPlaceholderTranslations() {
  return <String, String>{
    ChatExportTranslationKey.image: t.chat.exportPlaceholderImage,
    ChatExportTranslationKey.voice: t.chat.exportPlaceholderVoice,
    ChatExportTranslationKey.video: t.chat.exportPlaceholderVideo,
    ChatExportTranslationKey.file: t.chat.exportPlaceholderFile,
    ChatExportTranslationKey.location: t.chat.exportPlaceholderLocation,
    ChatExportTranslationKey.expression: t.chat.exportPlaceholderExpression,
    ChatExportTranslationKey.messageFallback: t.chat.exportPlaceholderMessage,
    ChatExportTranslationKey.conversationLabel: t.chat.exportLabelConversation,
    ChatExportTranslationKey.exportedAtLabel: t.chat.exportLabelExportedAt,
    ChatExportTranslationKey.countLabel: t.chat.exportLabelCount,
    ChatExportTranslationKey.htmlTitle: t.chat.exportHtmlTitle,
    ChatExportTranslationKey.htmlLang: t.chat.exportHtmlLang,
  };
}
