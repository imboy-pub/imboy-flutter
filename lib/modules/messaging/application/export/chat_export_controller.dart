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
  ChatExportResult({
    required this.status,
    this.errorCode,
    this.exportedCount = 0,
    Map<String, int> rejectionCounts = const <String, int>{},
  }) : rejectionCounts = Map<String, int>.unmodifiable(rejectionCounts);

  final ChatExportStatus status;

  /// 稳定错误码（仅 [ChatExportStatus.error]）：
  /// - `temp_file_write_failed`：落盘失败（已尽力清理半成品）；
  /// - `share_failed` / `share_invalid_params`：网关异常（原样透传
  ///   [SharePlusChatShareGateway] 错误码）。
  final String? errorCode;

  /// 实际进入导出正文的条数（通过准入）。
  final int exportedCount;

  /// 被拒条目按 reason code 聚合计数（直映 i18n 提示）。
  ///
  /// 构造时做 unmodifiable 快照（W5-G3 复审 INFO：文档自称不可变，
  /// 实现同步兜住——调用方后续改传入 map 不影响本结果，写操作抛
  /// UnsupportedError）。
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
    this._diagnosticLogger,
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

  /// 诊断日志缝（W5-G3 复审 LOW）：确认回调异常静默降级线上无从排查，
  /// 注入 iPrint 后与 flow 的错误码日志同惯例。保持本层纯 Dart
  /// （不 import Flutter），由 presentation 层（chat_export_flow）接线；
  /// 缺省 null = 无日志（纯 Dart 调用方/测试不受影响）。
  final void Function(String message)? _diagnosticLogger;
  final DateTime Function() _now;

  /// flag 判定缺省：fail-closed（rollout flag 默认关闭语义）。
  static bool _defaultFlagDisabled() => false;

  /// 执行导出并分享。任何取消路径都保证零副作用（不落盘、gateway 零调用）；
  /// 任何落盘路径都保证分享结束后清理临时文件（含网关抛异常路径）。
  ///
  /// 步骤拆分（W5-G3-3，行为零变化）：准入 `_admitEntries` → E2EE 确认
  /// `_confirmedLeaveEncryptedEnvironment` → 产物渲染 `_renderArtifacts`
  /// → 落盘 `_writeArtifacts` → 分享与清理 `_shareAndPurge`。
  Future<ChatExportResult> export(ChatExportRequest request) async {
    // 1. 灰度开关：关闭即拒绝（fail-closed），不进入任何后续步骤。
    if (!_isFlagEnabled()) {
      // 构造函数非 const（rejectionCounts 做 unmodifiable 快照）。
      return ChatExportResult(status: ChatExportStatus.flagDisabled);
    }

    // 2. 类型准入（W1-C 冻结矩阵），拒绝项不进入正文与分享。
    final admitted = _admitEntries(request.entries);
    if (admitted.exportable.isEmpty) {
      return ChatExportResult(
        status: ChatExportStatus.nothingToExport,
        rejectionCounts: admitted.rejectionCounts,
      );
    }

    // 3. E2EE 会话必须先过「内容将离开加密环境」确认（PLAN §4.6）。
    if (!await _confirmedLeaveEncryptedEnvironment()) {
      // 零副作用：到此为止未写过任何文件，gateway 零调用。
      return ChatExportResult(
        status: ChatExportStatus.e2eeDeclined,
        rejectionCounts: admitted.rejectionCounts,
      );
    }

    // 4. 渲染产物（txt + html；翻译缝在此时求值，locale 取导出当下）。
    final rendered = _renderArtifacts(request, admitted.exportable);

    // 5. 落盘。任一失败：_writeArtifacts 内已清理半成品，返回 error。
    final paths = await _writeArtifacts(rendered);
    if (paths == null) {
      return ChatExportResult(
        status: ChatExportStatus.error,
        errorCode: 'temp_file_write_failed',
        rejectionCounts: admitted.rejectionCounts,
      );
    }

    // 6. 分享 + finally 全量清理（成功/取消/异常路径都清，EXP-03）。
    return _shareAndPurge(
      rendered,
      paths,
      exportedCount: admitted.exportable.length,
      rejectionCounts: admitted.rejectionCounts,
    );
  }

  /// 准入结果（步骤 2 产物，见 [_AdmittedEntries]：
  /// 可导出条目 + 按 reason code 聚合计数）。
  static _AdmittedEntries _admitEntries(List<ChatExportEntry> entries) {
    final exportable = <ChatExportEntry>[];
    final rejectionCounts = <String, int>{};
    for (final entry in entries) {
      final admission = evaluateChatExportAdmission(entry);
      if (admission.allowed) {
        exportable.add(entry);
      } else {
        rejectionCounts[admission.reasonCode] =
            (rejectionCounts[admission.reasonCode] ?? 0) + 1;
      }
    }
    return _AdmittedEntries(exportable, rejectionCounts);
  }

  /// E2EE 确认门（步骤 3）。返回 false = 不得继续导出。
  ///
  /// - 非加密会话：直接放行；
  /// - 确认回调缺失 = 无法取得用户同意 = 拒绝（fail-closed）；
  /// - 确认回调抛异常（如 UI context 已卸载的路由查找失败）同样无法
  ///   取得用户同意：防御捕获映射拒绝（W5-G3-1），异常不再穿透
  ///   `unawaited` 的导出调用链；日志只记异常类型（ADR 15 §5 同款口径，
  ///   不含 payload/密钥/会话细节），经 [_diagnosticLogger] 缝输出。
  Future<bool> _confirmedLeaveEncryptedEnvironment() async {
    final isEncrypted = _isEncryptedConversation;
    final encrypted = isEncrypted != null && await isEncrypted();
    if (!encrypted) return true;
    final confirm = _confirmLeaveEncryptedEnvironment;
    if (confirm == null) return false;
    try {
      return await confirm();
    } on Object catch (e) {
      _diagnosticLogger?.call(
        '⚠️ [chat_export] E2EE 确认回调异常，按拒绝处理: ${e.runtimeType}',
      );
      return false;
    }
  }

  /// 渲染产物（步骤 4，见 [_RenderedArtifact]：产物元数据 + 对应正文，
  /// 一一对应）。
  List<_RenderedArtifact> _renderArtifacts(
    ChatExportRequest request,
    List<ChatExportEntry> exportable,
  ) {
    // 翻译快照（W5-G3-5）：按本次导出构造，无 provider = 纯 zh-CN 兜底，
    // 无跨导出残留。
    final placeholders = ChatExportPlaceholders.of(_translations?.call());
    final doc = ChatExportDocument(
      conversationTitle: request.conversationTitle,
      entries: exportable,
      exportedAt: _now(),
    );
    final txt = ChatExportFormatter.formatAsTxt(
      doc,
      placeholders: placeholders,
    );
    final html = ChatExportFormatter.formatAsHtml(
      doc,
      placeholders: placeholders,
    );
    return <_RenderedArtifact>[
      _RenderedArtifact(
        ChatExportArtifact.fromContent(
          content: txt,
          extension: 'txt',
          conversationUk3: request.conversationUk3,
          now: doc.exportedAt,
        ),
        txt,
      ),
      _RenderedArtifact(
        ChatExportArtifact.fromContent(
          content: html,
          extension: 'html',
          conversationUk3: request.conversationUk3,
          now: doc.exportedAt,
        ),
        html,
      ),
    ];
  }

  /// 落盘（步骤 5）。任一失败：清理已写半成品后返回 null（映射
  /// `temp_file_write_failed`）。
  Future<List<String>?> _writeArtifacts(
    List<_RenderedArtifact> rendered,
  ) async {
    final paths = <String>[];
    for (final item in rendered) {
      try {
        paths.add(
          await _tempFileWriter.write(
            fileName: item.artifact.fileName,
            content: item.body,
          ),
        );
      } on Object {
        await _purge(rendered.map((r) => r.artifact).toList(), paths);
        return null;
      }
    }
    return paths;
  }

  /// 分享 + finally 全量清理（步骤 6，成功/取消/异常路径都清，EXP-03）。
  Future<ChatExportResult> _shareAndPurge(
    List<_RenderedArtifact> rendered,
    List<String> paths, {
    required int exportedCount,
    required Map<String, int> rejectionCounts,
  }) async {
    final artifacts = rendered.map((r) => r.artifact).toList();
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
        exportedCount: exportedCount,
        rejectionCounts: rejectionCounts,
      );
    } on Object {
      return ChatExportResult(
        status: ChatExportStatus.error,
        errorCode: 'share_failed',
        exportedCount: exportedCount,
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

/// 准入结果（步骤 2 产物）：可导出条目 + 按 reason code 聚合计数。
class _AdmittedEntries {
  const _AdmittedEntries(this.exportable, this.rejectionCounts);

  final List<ChatExportEntry> exportable;
  final Map<String, int> rejectionCounts;
}

/// 渲染产物（步骤 4 产物）：产物元数据 + 对应正文（一一对应）。
class _RenderedArtifact {
  const _RenderedArtifact(this.artifact, this.body);

  final ChatExportArtifact artifact;
  final String body;
}
