/// 导出临时文件模型 + 安全文件名生成 + 可测试清理策略
/// （W1-C / chat_export_share_v1）。
///
/// 本文件只建模与决策，**不做任何 IO**：实际落盘/删除由 W3-J 平台层
/// （share_plus 适配器）执行。
library;

import 'dart:convert';
import 'dart:math';

/// 一次导出产生的临时文件描述（不可变）。
class ChatExportArtifact {
  const ChatExportArtifact({
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.conversationUk3,
  });

  /// 由 [generateChatExportFileName] 生成的安全文件名
  /// （仅时间戳+随机后缀，禁止含昵称/uid/手机号/会话名）。
  final String fileName;

  /// MIME 类型（`text/plain; charset=utf-8` 或 `text/html; charset=utf-8`）。
  final String mimeType;

  /// 导出正文的 UTF-8 字节数（用于展示与上限校验）。
  final int byteSize;

  /// 所属会话 uk3。**仅用于临时文件清理范围圈定**，禁止写入导出正文、
  /// 文件名或分享内容（禁止字段清单见 chat_export_entry.dart）。
  final String conversationUk3;

  /// 按导出正文构建产物：生成安全文件名并计算 UTF-8 字节数。
  factory ChatExportArtifact.fromContent({
    required String content,
    required String extension,
    required String conversationUk3,
    DateTime? now,
    Random? random,
  }) {
    final isHtml = extension == 'html';
    return ChatExportArtifact(
      fileName: generateChatExportFileName(
        extension: extension,
        now: now,
        random: random,
      ),
      mimeType: isHtml
          ? 'text/html; charset=utf-8'
          : 'text/plain; charset=utf-8',
      byteSize: utf8.encode(content).length,
      conversationUk3: conversationUk3,
    );
  }
}

/// 生成导出临时文件名：`imboy-chat-export-<yyyyMMdd>-<6位hex>.<ext>`。
///
/// 隐私不变量（文件名安全）：**函数签名不接收任何用户/会话数据**，
/// 文件名只含固定前缀 + 日期 + 随机后缀，结构上不可能泄漏昵称、uid、
/// 手机号或会话名。
///
/// - [extension] 仅允许 `^[a-z0-9]{1,8}$`（txt/html），防注入。
/// - [now] 缺省取当前本地时间（测试注入固定值）。
/// - [random] 缺省 `Random.secure()`（测试注入固定种子）。
String generateChatExportFileName({
  String extension = 'txt',
  DateTime? now,
  Random? random,
}) {
  final allowedExtension = RegExp(r'^[a-z0-9]{1,8}$');
  if (!allowedExtension.hasMatch(extension)) {
    throw ArgumentError.value(
      extension,
      'extension',
      '导出文件名扩展名仅允许小写字母数字（txt/html）',
    );
  }
  final d = now ?? DateTime.now();
  final rnd = random ?? Random.secure();
  const hexChars = '0123456789abcdef';
  final suffix = String.fromCharCodes(
    List<int>.generate(6, (_) => hexChars.codeUnitAt(rnd.nextInt(16))),
  );
  final date =
      '${d.year}${d.month >= 10 ? d.month : '0${d.month}'}'
      '${d.day >= 10 ? d.day : '0${d.day}'}';
  return 'imboy-chat-export-$date-$suffix.$extension';
}

/// 临时文件清理策略（纯决策接口，真正删除由平台层执行）。
///
/// 事件语义（PLAN_SNAPSHOT §4.6 / W3-J 接线）：
/// - 分享完成（成功、用户取消、失败均视为完成）→ 清理本次全部产物；
/// - 会话结束（用户离开/切换会话）→ 清理该会话的全部产物。
abstract interface class ExportTempFilePolicy {
  /// 返回分享完成后应删除的产物集合。
  List<ChatExportArtifact> artifactsToPurgeAfterShare(
    List<ChatExportArtifact> artifacts,
  );

  /// 返回指定会话结束时应删除的产物集合（其他会话的不动）。
  List<ChatExportArtifact> artifactsToPurgeOnConversationClosed({
    required String conversationUk3,
    required List<ChatExportArtifact> artifacts,
  });
}

/// 默认清理策略：分享完成后全量清理；会话结束清理该会话全部产物。
class DefaultExportTempFilePolicy implements ExportTempFilePolicy {
  const DefaultExportTempFilePolicy();

  @override
  List<ChatExportArtifact> artifactsToPurgeAfterShare(
    List<ChatExportArtifact> artifacts,
  ) => List<ChatExportArtifact>.of(artifacts);

  @override
  List<ChatExportArtifact> artifactsToPurgeOnConversationClosed({
    required String conversationUk3,
    required List<ChatExportArtifact> artifacts,
  }) => artifacts
      .where((a) => a.conversationUk3 == conversationUk3)
      .toList(growable: false);
}
