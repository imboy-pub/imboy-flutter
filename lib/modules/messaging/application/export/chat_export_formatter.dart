/// 聊天导出格式化器 —— 纯函数，UTF-8 `.txt` 与安全转义 `.html`
/// （W1-C / chat_export_share_v1）。
///
/// 冻结契约（PLAN_SNAPSHOT §4.6 导出合同 + W1-C 任务书）：
/// - txt 行格式稳定为 `[时间] 发送者: 内容`，按 createdAt 从旧到新排序，
///   相同 createdAt 保持原始传入顺序（稳定排序）。
/// - html 对 `<>&"'` 全转义，正文换行转 `<br>`，最小内联样式骨架。
/// - 媒体类型只输出安全描述占位（zh-CN 常量兜底，翻译经
///   [ChatExportPlaceholders] 参数显式传入，W5-G3-5）。
/// - 拒绝导出的类型（见 chat_export_admission.dart）不出现在任何输出。
/// - 输出不得包含禁止字段（peer_id/conversation_uk3/sender_did/
///   sender_dtype/content key/descriptor/burn_read_at/服务端主键/成员列表）。
library;

import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_document.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_placeholders.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 导出格式化器（纯静态，不可实例化）。
abstract final class ChatExportFormatter {
  /// 过滤出允许导出的条目（保持传入顺序）。
  static List<ChatExportEntry> exportableEntries(ChatExportDocument doc) {
    return doc.entries
        .where((e) => evaluateChatExportAdmission(e).allowed)
        .toList(growable: false);
  }

  /// 渲染单条正文（txt/html 共用；正文值本身不转义，转义在 html 侧做）。
  ///
  /// - text/textStream → 可见全文（缺正文退 `[消息]`）
  /// - quote → 可见文本扁平化：回复正文 + 被引用文本，非空项以空格连接
  /// - image/imageMulti → `[图片]`；voice → `[语音]`；video → `[视频]`
  /// - file → `[文件] 文件名`；location → `[位置] 标题`（缺失仅占位）
  /// - expression → `[表情]`（任务书显式映射，忽略 label 文本）
  /// - 其余允许类型 → 安全描述（description），缺失退 `[消息]`
  static String bodyText(
    ChatExportEntry entry, {
    ChatExportPlaceholders placeholders = ChatExportPlaceholders.zhCn,
  }) {
    final type = normalizeChatExportMsgType(entry.msgType);
    switch (type) {
      case MessageType.text:
      case MessageType.textStream:
        final t = (entry.text ?? '').trim();
        return t.isNotEmpty ? t : placeholders.messageFallback;
      case MessageType.quote:
        final own = (entry.text ?? '').trim();
        final quoted = (entry.quotedText ?? '').trim();
        if (own.isEmpty && quoted.isEmpty) {
          return placeholders.messageFallback;
        }
        return <String>[
          if (own.isNotEmpty) own,
          if (quoted.isNotEmpty) quoted,
        ].join(' ');
      case MessageType.image:
      case MessageType.imageMulti:
        return placeholders.image;
      case MessageType.voice:
        return placeholders.voice;
      case MessageType.video:
        return placeholders.video;
      case MessageType.file:
        final name = (entry.description ?? '').trim();
        return name.isEmpty ? placeholders.file : '${placeholders.file} $name';
      case MessageType.location:
        final title = (entry.description ?? '').trim();
        return title.isEmpty
            ? placeholders.location
            : '${placeholders.location} $title';
      case MessageType.expression:
        return placeholders.expression;
      default:
        final d = (entry.description ?? '').trim();
        return d.isNotEmpty ? d : placeholders.messageFallback;
    }
  }

  /// 格式化为 UTF-8 `.txt` 字符串（纯文本，不转义，换行原样保留）。
  static String formatAsTxt(
    ChatExportDocument doc, {
    ChatExportPlaceholders placeholders = ChatExportPlaceholders.zhCn,
  }) {
    final entries = _sortedByCreatedAtStable(exportableEntries(doc));
    final sb = StringBuffer();
    sb
      ..writeln('${placeholders.conversationLabel}: ${doc.conversationTitle}')
      ..writeln(
        '${placeholders.exportedAtLabel}: '
        '${_formatLocalTime(doc.exportedAt)}',
      )
      ..writeln('${placeholders.countLabel}: ${entries.length}')
      ..writeln('-' * 32);
    for (final e in entries) {
      sb.writeln(
        '[${_formatLocalTime(e.createdAt)}] ${e.senderName}: '
        '${bodyText(e, placeholders: placeholders)}',
      );
    }
    return sb.toString();
  }

  /// 格式化为安全转义的 `.html` 字符串。
  ///
  /// 所有用户可控内容（会话名/发送者/正文）经 `_escapeHtml` 转义
  /// （`<>&"'` 五字符全转义），正文换行转 `<br>`。
  static String formatAsHtml(
    ChatExportDocument doc, {
    ChatExportPlaceholders placeholders = ChatExportPlaceholders.zhCn,
  }) {
    final entries = _sortedByCreatedAtStable(exportableEntries(doc));
    final rawTitle = doc.conversationTitle.trim().isNotEmpty
        ? doc.conversationTitle.trim()
        : placeholders.htmlTitle;
    final title = _escapeHtml(rawTitle);
    final sb = StringBuffer();
    sb
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="${placeholders.htmlLang}">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln('<title>$title</title>')
      ..writeln(_htmlStyle());
    sb
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<h1>$title</h1>')
      ..writeln(
        '<p class="meta">${placeholders.exportedAtLabel}: '
        '${_escapeHtml(_formatLocalTime(doc.exportedAt))} · '
        '${placeholders.countLabel}: ${entries.length}</p>',
      );
    for (final e in entries) {
      sb.writeln(
        '<p class="entry"><span class="time">['
        '${_escapeHtml(_formatLocalTime(e.createdAt))}]</span> '
        '<span class="sender">${_escapeHtml(e.senderName)}</span>: '
        '${_newlinesToBr(_escapeHtml(bodyText(e, placeholders: placeholders)))}'
        '</p>',
      );
    }
    sb
      ..writeln('</body>')
      ..writeln('</html>');
    return sb.toString();
  }

  /// 最小内联样式骨架（单列自适应正文 + 暗色跟随系统），W5-G3-3 拆出。
  static String _htmlStyle() {
    final sb = StringBuffer();
    sb
      ..writeln('<style>')
      ..writeln(
        "body{font-family:system-ui,-apple-system,'PingFang SC',"
        "'Microsoft YaHei',sans-serif;max-width:720px;margin:0 auto;"
        'padding:16px;color:#1c1c1e;background:#fff;}',
      )
      ..writeln('h1{font-size:18px;margin:0 0 4px;}')
      ..writeln('.meta{color:#8a8a8e;font-size:12px;margin:0 0 16px;}')
      ..writeln(
        '.entry{font-size:14px;line-height:1.7;margin:6px 0;'
        'word-break:break-word;}',
      )
      ..writeln('.time{color:#8a8a8e;font-size:12px;}')
      ..writeln('.sender{font-weight:600;}')
      ..writeln(
        '@media (prefers-color-scheme:dark){body{background:#000;'
        'color:#f2f2f7}.time,.meta{color:#98989d}}',
      )
      ..writeln('</style>');
    return sb.toString();
  }

  /// 稳定排序：createdAt 从旧到新；相同时间按原始传入顺序。
  /// Dart `List.sort` 非稳定，故以原始下标做决胜比较。
  static List<ChatExportEntry> _sortedByCreatedAtStable(
    List<ChatExportEntry> entries,
  ) {
    final indexed = List<(int, ChatExportEntry)>.generate(
      entries.length,
      (i) => (i, entries[i]),
    );
    indexed.sort((a, b) {
      final byTime = a.$2.createdAt.compareTo(b.$2.createdAt);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    return List<ChatExportEntry>.generate(
      indexed.length,
      (i) => indexed[i].$2,
      growable: false,
    );
  }

  /// 本地时间 `yyyy-MM-dd HH:mm:ss`（纯 Dart 手写，零 intl 依赖）。
  static String _formatLocalTime(DateTime t) =>
      '${_fourDigits(t.year)}-${_twoDigits(t.month)}-${_twoDigits(t.day)} '
      '${_twoDigits(t.hour)}:${_twoDigits(t.minute)}:${_twoDigits(t.second)}';

  static String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';

  static String _fourDigits(int n) =>
      n >= 1000 ? '$n' : n.toString().padLeft(4, '0');

  /// HTML 转义：`<>&"'` 五字符全转义（& 必须最先）。
  static String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  /// 换行转 `<br>`：先归一 `\r\n`/`\r` 为 `\n`（在转义后的文本上调用）。
  static String _newlinesToBr(String s) => s
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', '<br>');
}
