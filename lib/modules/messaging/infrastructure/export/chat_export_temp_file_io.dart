/// 导出临时文件 IO 适配器（W3-J / chat_export_share_v1）。
///
/// 实现 application/export 的 [ChatExportTempFileWriter] 端口：
/// - 写入：`getTemporaryDirectory()`（path_provider），取不到时回落
///   `Directory.systemTemp`（纯 Dart VM 语境/测试环境）；
/// - 删除：best-effort（不存在/失败静默，临时目录由 OS 兜底回收）。
///
/// 文件名一律来自 W1-C `generateChatExportFileName`（结构上无用户数据）；
/// 写入内容为 UTF-8 编码的 formatter 输出。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:imboy/modules/messaging/application/export/chat_export_temp_file_writer.dart';

/// 真实落盘实现（系统临时目录）。
class IoChatExportTempFileWriter implements ChatExportTempFileWriter {
  IoChatExportTempFileWriter({Future<Directory> Function()? directoryResolver})
    : _directoryResolver = directoryResolver ?? _resolveSystemTempDirectory;

  /// 可注入目录解析（测试隔离用）；null = path_provider 临时目录优先。
  final Future<Directory> Function() _directoryResolver;

  /// 临时目录解析：path_provider 失败（非 IO 平台/未初始化）时回落
  /// systemTemp，保证导出不因目录服务缺席而中断。
  static Future<Directory> _resolveSystemTempDirectory() async {
    try {
      return await getTemporaryDirectory();
    } on Object {
      return Directory.systemTemp;
    }
  }

  @override
  Future<String> write({
    required String fileName,
    required String content,
  }) async {
    final dir = await _directoryResolver();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content, encoding: utf8, flush: true);
    return file.path;
  }

  @override
  Future<void> deleteAll(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } on Object {
        // best-effort：单个删除失败不阻断其余清理，也不上抛
        //（临时目录由 OS 兜底回收）。
      }
    }
  }
}
