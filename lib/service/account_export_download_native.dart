/// 账号导出保存 - 原生实现（应用沙盒/临时目录真实文件，FL-13）。
library;

import 'dart:io';

/// 保存结果：原生 `location` 为文件绝对路径，`viaBrowserDownload` 恒为 false。
class AccountExportDownloadResult {
  const AccountExportDownloadResult({
    required this.location,
    required this.viaBrowserDownload,
  });

  final String location;
  final bool viaBrowserDownload;
}

/// 清洗导出文件名：仅保留最后一段（剔除 `../`、绝对路径、反斜杠），
/// 去除控制字符；清洗后为空/仅点号时回退默认名。
String sanitizeAccountExportFileName(String fileName) {
  final lastSegment = fileName.split(RegExp(r'[/\\]')).last;
  final cleaned = lastSegment.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return 'imboy_data_export.json';
  }
  return cleaned;
}

/// 将导出 JSON 写为真实文件（逐字节原样，不追加任何字段）。
///
/// [intoDirectoryPath] 为空时写入系统临时目录；页面调用方应传
/// AccountLocalFiles 的账号隔离目录（storageDigest 分桶）以保持
/// 跨账号隔离与注销后清理。
Future<AccountExportDownloadResult> saveAccountExportJson({
  required String fileName,
  required String jsonContent,
  String? intoDirectoryPath,
}) async {
  if (jsonContent.isEmpty) {
    throw ArgumentError.value(
      jsonContent,
      'jsonContent',
      'account export payload must not be empty',
    );
  }
  final safeName = sanitizeAccountExportFileName(fileName);
  final Directory base;
  if (intoDirectoryPath == null || intoDirectoryPath.isEmpty) {
    base = Directory.systemTemp;
  } else {
    base = Directory(intoDirectoryPath);
  }
  if (!await base.exists()) {
    await base.create(recursive: true);
  }
  // safeName 已不含路径分隔符，落点不可能逃出 base。
  final file = File('${base.path}${Platform.pathSeparator}$safeName');
  await file.writeAsString(jsonContent, flush: true);
  return AccountExportDownloadResult(
    location: file.path,
    viaBrowserDownload: false,
  );
}
