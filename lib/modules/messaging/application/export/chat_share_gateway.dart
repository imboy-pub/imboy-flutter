/// 系统分享网关抽象（W1-C / chat_export_share_v1）。
///
/// **本波只定义契约，不实现任何平台适配**——share_plus 适配器（打开系统
/// 分享面板、临时文件落盘与删除）由 W3-J 提供。UI/W2 层只依赖本抽象，
/// 测试以 fake 注入（W3-K 导出用例同样注入 adapter 断言）。
library;

import 'package:imboy/modules/messaging/application/export/chat_export_artifact.dart';

/// 分享结果状态。
enum ChatShareOutcomeStatus {
  /// 已交给系统分享面板（目标完成投递）。
  shared,

  /// 用户在系统面板取消。
  canceled,

  /// 失败（见 [ChatShareOutcome.errorCode] 稳定错误码）。
  error,
}

/// 单次分享结果（不可变）。
class ChatShareOutcome {
  const ChatShareOutcome({required this.status, this.errorCode});

  const ChatShareOutcome.shared() : this(status: ChatShareOutcomeStatus.shared);

  const ChatShareOutcome.canceled()
    : this(status: ChatShareOutcomeStatus.canceled);

  const ChatShareOutcome.error(String code)
    : this(status: ChatShareOutcomeStatus.error, errorCode: code);

  final ChatShareOutcomeStatus status;

  /// 稳定错误码（W3-J 填充；用于 UI 提示与测试断言）。
  final String? errorCode;
}

/// 分享文件请求：产物元数据 + 平台层已落盘的绝对路径（一一对应）。
class ChatShareFilesRequest {
  const ChatShareFilesRequest({
    required this.artifacts,
    required this.filePaths,
    this.text,
  }) : assert(
         artifacts.length == filePaths.length,
         'artifacts 与 filePaths 必须一一对应',
       );

  /// 导出产物元数据（文件名/MIME/字节数，供分享面板展示）。
  final List<ChatExportArtifact> artifacts;

  /// 平台层（W3-J）已写入临时目录的绝对路径。
  final List<String> filePaths;

  /// 附带分享的可选文本。
  final String? text;
}

/// 系统分享网关契约。
abstract interface class ChatShareGateway {
  /// 分享纯文本（如导出 txt 正文直接作为分享文本）。
  Future<ChatShareOutcome> shareText(String text, {String? subject});

  /// 分享导出临时文件（txt/html）。完成后调用方按
  /// [ExportTempFilePolicy] 执行清理。
  Future<ChatShareOutcome> shareFiles(ChatShareFilesRequest request);
}
