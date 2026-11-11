/// 导出临时文件写入/删除端口 —— 平台 IO 抽象（W3-J / chat_export_share_v1）。
///
/// application/export 层保持纯 Dart（不 import path_provider/share_plus），
/// 落盘与删除由 infrastructure 适配器实现
/// （`infrastructure/export/chat_export_temp_file_io.dart`），测试注入
/// 内存/目录 fake。
library;

/// 临时文件端口：写入 formatter 输出 + 分享后清理删除。
abstract interface class ChatExportTempFileWriter {
  /// 把 [content] 以 UTF-8 写入临时目录下名为 [fileName] 的文件，
  /// 返回写入后的绝对路径。文件名必须来自
  /// `generateChatExportFileName`（结构上无用户数据）。
  ///
  /// 抛出的异常原样上抛，由 [ChatExportController] 统一兜底清理后映射
  /// 为 error 结果。
  Future<String> write({required String fileName, required String content});

  /// 尽力删除一批绝对路径（best-effort：不存在/删除失败不抛出，
  /// 只在无法删除时静默跳过——临时目录由 OS 兜底回收）。
  Future<void> deleteAll(Iterable<String> paths);
}
