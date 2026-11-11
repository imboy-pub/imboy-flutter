/// 聊天导出文档 DTO —— 一次导出的完整输入（W1-C / chat_export_share_v1）。
library;

import 'chat_export_entry.dart';

/// 导出文档：会话显示名 + 条目列表 + 导出时间（不可变）。
class ChatExportDocument {
  ChatExportDocument({
    required this.conversationTitle,
    required List<ChatExportEntry> entries,
    required this.exportedAt,
  }) : entries = List.unmodifiable(entries);

  /// 会话显示名（C2C 对端昵称 / C2G 群名），仅用于文档头展示。
  /// 不得填 conversation_uk3 等内部标识。
  final String conversationTitle;

  /// 待导出条目。顺序为调用方给出顺序；格式化时按 createdAt 从旧到新
  /// 稳定排序，并在渲染前应用类型准入（拒绝项不出现在输出）。
  final List<ChatExportEntry> entries;

  /// 导出时间（本地时区）。
  final DateTime exportedAt;
}
