/// 聊天导出流程编排器（W3-J / chat_export_share_v1）。
///
/// 纯 Dart、全依赖注入（gateway/临时文件端口/判定谓词均可 fake），
/// 复用 W1-C 冻结核心：
/// - 准入：`evaluateChatExportAdmission`（类型矩阵 + 稳定 reason code）；
/// - 格式化：`ChatExportFormatter.formatAsTxt/formatAsHtml`（纯函数）；
/// - 产物：`ChatExportArtifact.fromContent`（安全文件名 + MIME + 字节数）；
/// - 清理决策：`ExportTempFilePolicy`（纯选择函数），本类执行删除。
///
/// 流程顺序（取消 = 零副作用是硬契约，EXP-02）：
///
///     flag 关闭? → nothingToExport? → E2EE 会话? →(确认弹窗，取消即止)
///     → 格式化 → 生成产物 → 落盘(txt+html) → gateway.shareFiles
///     → finally: 全量清理临时文件（成功/取消/抛异常路径都清，EXP-03）
///
/// 平台默认依赖（share_plus 网关、path_provider 临时目录、E2EEService
/// 判定、feature flag 判定）由 `infrastructure/export` 与
/// `presentation/export/chat_export_flow.dart` 的工厂组装；
/// 本文件不 import 任何 Flutter/平台插件。
library;

import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_artifact.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_document.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_formatter.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_placeholders.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_temp_file_writer.dart';
import 'package:imboy/modules/messaging/application/export/chat_share_gateway.dart';

/// 导出流程终态。
enum ChatExportStatus {
  /// feature flag `chat_export_share_v1` 关闭（入口直接拒绝，零副作用）。
  flagDisabled,

  /// 选中的消息全部被类型准入拒绝，无产物（不弹确认、不落盘、不分享）。
  nothingToExport,

  /// E2EE 会话下用户在「内容将离开加密环境」确认中取消（零副作用：
  /// 未落盘、gateway 零调用）。
  e2eeDeclined,

  /// 已交给系统分享面板（用户选中目标 / 平台不可反馈同款口径）。
  shared,

  /// 用户在系统分享面板取消。
  canceled,

  /// 失败（见 [ChatExportResult.errorCode] 稳定错误码）。
  error,
}

/// 一次导出的结果（不可变）。
class ChatExportResult {
  const ChatExportResult({
    required this.status,
    this.errorCode,
    this.exportedCount = 0,
    this.rejectionCounts = const <String, int>{},
  });

  final ChatExportStatus status;

  /// 稳定错误码（仅 [ChatExportStatus.error]）：
  /// - `temp_file_write_failed`：落盘失败（已尽力清理半成品）；
  /// - `share_failed` / `share_invalid_params`：网关异常（原样透传
  ///   [SharePlusChatShareGateway] 错误码）。
  final String? errorCode;

  /// 实际进入导出正文的条数（通过准入）。
  final int exportedCount;

  /// 被拒条目按 reason code 聚合计数（直映 i18n 提示）。
  final Map<String, int> rejectionCounts;
}

/// 导出请求（不可变）。
class ChatExportRequest {
  const ChatExportRequest({
    required this.conversationUk3,
    required this.conversationTitle,
    required this.entries,
  });

  /// 仅用于临时文件清理范围圈定（[ChatExportArtifact.conversationUk3]），
  /// 禁止进入导出正文/文件名。
  final String conversationUk3;

  /// 会话显示名（文档头展示）。
  final String conversationTitle;

  /// 待导出条目（顺序任意；格式化时按 createdAt 稳定排序 + 准入过滤）。
  final List<ChatExportEntry> entries;
}

/// 导出流程控制器。
///
/// 一次性实例（每次导出新建，见 `runChatExportFlow`）；无内部状态残留。
class ChatExportController {
  ChatExportController({
    required this._gateway,
    required this._tempFileWriter,
    ExportTempFilePolicy? tempFilePolicy,
    bool Function()? isFlagEnabled,
    this._isEncryptedConversation,
    this._confirmLeaveEncryptedEnvironment,
    this._translations,
    DateTime Function()? now,
  }) : _tempFilePolicy = tempFilePolicy ?? const DefaultExportTempFilePolicy(),
       _isFlagEnabled = isFlagEnabled ?? _defaultFlagDisabled,
       _now = now ?? DateTime.now;

  final ChatShareGateway _gateway;
  final ChatExportTempFileWriter _tempFileWriter;
  final ExportTempFilePolicy _tempFilePolicy;
  final bool Function() _isFlagEnabled;
  final Future<bool> Function()? _isEncryptedConversation;
  final Future<bool> Function()? _confirmLeaveEncryptedEnvironment;
  final Map<String, String> Function()? _translations;
  final DateTime Function() _now;

  /// flag 判定缺省：fail-closed（rollout flag 默认关闭语义）。
  static bool _defaultFlagDisabled() => false;

  /// 执行导出并分享。任何取消路径都保证零副作用（不落盘、gateway 零调用）；
  /// 任何落盘路径都保证分享结束后清理临时文件（含网关抛异常路径）。
  Future<ChatExportResult> export(ChatExportRequest request) async {
    // 1. 灰度开关：关闭即拒绝（fail-closed），不进入任何后续步骤。
    if (!_isFlagEnabled()) {
      return const ChatExportResult(status: ChatExportStatus.flagDisabled);
    }

    // 2. 类型准入（W1-C 冻结矩阵），拒绝项不进入正文与分享。
    final exportable = <ChatExportEntry>[];
    final rejectionCounts = <String, int>{};
    for (final entry in request.entries) {
      final admission = evaluateChatExportAdmission(entry);
      if (admission.allowed) {
        exportable.add(entry);
      } else {
        rejectionCounts[admission.reasonCode] =
            (rejectionCounts[admission.reasonCode] ?? 0) + 1;
      }
    }
    if (exportable.isEmpty) {
      return ChatExportResult(
        status: ChatExportStatus.nothingToExport,
        rejectionCounts: rejectionCounts,
      );
    }

    // 3. E2EE 会话必须先过「内容将离开加密环境」确认（PLAN §4.6）。
    //    确认回调缺失 = 无法取得用户同意 = 拒绝（fail-closed）。
    final isEncrypted = _isEncryptedConversation;
    final encrypted = isEncrypted != null && await isEncrypted();
    if (encrypted) {
      final confirm = _confirmLeaveEncryptedEnvironment;
      final confirmed = confirm != null && await confirm();
      if (!confirmed) {
        // 零副作用：到此为止未写过任何文件，gateway 零调用。
        return ChatExportResult(
          status: ChatExportStatus.e2eeDeclined,
          rejectionCounts: rejectionCounts,
        );
      }
    }

    // 4. 翻译缝：按本次导出的 locale 映射重置全局占位文案（无 provider
    //    = 显式回落 zh-CN 兜底，避免上次导出残留的 locale 串状态）。
    ChatExportPlaceholders.applyTranslations(_translations?.call());

    final doc = ChatExportDocument(
      conversationTitle: request.conversationTitle,
      entries: exportable,
      exportedAt: _now(),
    );
    final txt = ChatExportFormatter.formatAsTxt(doc);
    final html = ChatExportFormatter.formatAsHtml(doc);
    final exportedAt = doc.exportedAt;
    final artifacts = <ChatExportArtifact>[
      ChatExportArtifact.fromContent(
        content: txt,
        extension: 'txt',
        conversationUk3: request.conversationUk3,
        now: exportedAt,
      ),
      ChatExportArtifact.fromContent(
        content: html,
        extension: 'html',
        conversationUk3: request.conversationUk3,
        now: exportedAt,
      ),
    ];

    // 5. 落盘（txt + html，与 artifacts 一一对应）。任一失败：清理已写
    //    文件后返回 error。
    final bodies = <String>[txt, html];
    final paths = <String>[];
    var writeFailed = false;
    for (var i = 0; i < artifacts.length; i++) {
      try {
        paths.add(
          await _tempFileWriter.write(
            fileName: artifacts[i].fileName,
            content: bodies[i],
          ),
        );
      } on Object {
        writeFailed = true;
        break;
      }
    }
    if (writeFailed) {
      await _purge(artifacts, paths);
      return ChatExportResult(
        status: ChatExportStatus.error,
        errorCode: 'temp_file_write_failed',
        rejectionCounts: rejectionCounts,
      );
    }

    // 6. 分享 + finally 全量清理（成功/取消/异常路径都清，EXP-03）。
    try {
      final outcome = await _gateway.shareFiles(
        ChatShareFilesRequest(artifacts: artifacts, filePaths: paths),
      );
      return ChatExportResult(
        status: switch (outcome.status) {
          ChatShareOutcomeStatus.shared => ChatExportStatus.shared,
          ChatShareOutcomeStatus.canceled => ChatExportStatus.canceled,
          ChatShareOutcomeStatus.error => ChatExportStatus.error,
        },
        errorCode: outcome.errorCode,
        exportedCount: exportable.length,
        rejectionCounts: rejectionCounts,
      );
    } on Object {
      return ChatExportResult(
        status: ChatExportStatus.error,
        errorCode: 'share_failed',
        exportedCount: exportable.length,
        rejectionCounts: rejectionCounts,
      );
    } finally {
      await _purge(artifacts, paths);
    }
  }

  /// 按清理策略决策执行删除（best-effort）。
  Future<void> _purge(
    List<ChatExportArtifact> artifacts,
    List<String> paths,
  ) async {
    if (paths.isEmpty) return;
    final toPurge = _tempFilePolicy.artifactsToPurgeAfterShare(artifacts);
    final doomed = <String>[];
    for (var i = 0; i < artifacts.length && i < paths.length; i++) {
      if (toPurge.contains(artifacts[i])) {
        doomed.add(paths[i]);
      }
    }
    await _tempFileWriter.deleteAll(doomed);
  }
}
