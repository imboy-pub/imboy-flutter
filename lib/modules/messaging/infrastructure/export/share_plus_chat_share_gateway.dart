/// share_plus 系统分享网关适配器（W3-J / chat_export_share_v1）。
///
/// 实现 W1-C 冻结的 [ChatShareGateway] 契约：打开系统分享面板
/// （`SharePlus.instance.share(ShareParams(...))`，W0A §9 用法），
/// 并把 [ShareResult] 归一为稳定三态 + 错误码。
///
/// 错误码契约（只增不改语义）：
/// - `share_failed`：share_plus 抛出的任意异常（平台通道失败等）；
/// - `share_invalid_params`：ShareParams 校验失败（ArgumentError）。
library;

import 'package:share_plus/share_plus.dart';

import 'package:imboy/modules/messaging/application/export/chat_export_artifact.dart';
import 'package:imboy/modules/messaging/application/export/chat_share_gateway.dart';

/// 基于 share_plus 的系统分享网关。
class SharePlusChatShareGateway implements ChatShareGateway {
  const SharePlusChatShareGateway({this._sharePlus});

  /// 可注入实例（测试用）；null = [SharePlus.instance]。
  final SharePlus? _sharePlus;

  @override
  Future<ChatShareOutcome> shareText(String text, {String? subject}) async {
    try {
      final result = await (_sharePlus ?? SharePlus.instance).share(
        ShareParams(text: text, title: subject),
      );
      return _mapResult(result);
    } on ArgumentError {
      return const ChatShareOutcome.error('share_invalid_params');
    } on Object {
      return const ChatShareOutcome.error('share_failed');
    }
  }

  @override
  Future<ChatShareOutcome> shareFiles(ChatShareFilesRequest request) async {
    assert(
      request.artifacts.length == request.filePaths.length,
      'artifacts 与 filePaths 必须一一对应（W1-C 契约）',
    );
    try {
      final result = await (_sharePlus ?? SharePlus.instance).share(
        ShareParams(
          // 面板标题用首个产物的安全文件名基（不含会话/用户数据）。
          title: _baseNameOf(request.artifacts),
          files: [for (final path in request.filePaths) XFile(path)],
          subject: request.text,
        ),
      );
      return _mapResult(result);
    } on ArgumentError {
      return const ChatShareOutcome.error('share_invalid_params');
    } on Object {
      return const ChatShareOutcome.error('share_failed');
    }
  }

  /// share_plus 三态 → 契约三态。
  ///
  /// - success → shared（用户选中分享目标）；
  /// - dismissed → canceled（用户在系统面板取消）；
  /// - unavailable → shared：面板已打开但平台无法反馈结果
  ///   （桌面/部分平台），按已交给系统处理；清理路径不受影响。
  static ChatShareOutcome _mapResult(ShareResult result) {
    switch (result.status) {
      case ShareResultStatus.success:
      case ShareResultStatus.unavailable:
        return const ChatShareOutcome.shared();
      case ShareResultStatus.dismissed:
        return const ChatShareOutcome.canceled();
    }
  }

  /// 面板标题：首个产物文件名去扩展名（安全文件名，无隐私字段）。
  static String _baseNameOf(List<ChatExportArtifact> artifacts) {
    if (artifacts.isEmpty) return 'imboy-chat-export';
    final name = artifacts.first.fileName;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
