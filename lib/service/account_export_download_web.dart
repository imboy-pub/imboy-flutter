/// 账号导出保存 - Web 实现（浏览器下载，不留应用可读副本，FL-13）。
///
/// 与 account_export_download_native.dart 保持同一 API 形状；
/// [saveAccountExportJson.intoDirectoryPath] 在 Web 上被忽略（落点由
/// 浏览器下载决定），文件内容不进入 IndexedDB/localStorage。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:imboy/service/web_writer_gate.dart';
import 'package:web/web.dart' as web;

/// 保存结果：Web `location` 为下载文件名（非路径），`viaBrowserDownload` 恒为 true。
class AccountExportDownloadResult {
  const AccountExportDownloadResult({
    required this.location,
    required this.viaBrowserDownload,
  });

  final String location;
  final bool viaBrowserDownload;
}

/// 与原生实现逐字对齐的文件名清洗（路径穿越/控制字符/空名回退）。
String sanitizeAccountExportFileName(String fileName) {
  final lastSegment = fileName.split(RegExp(r'[/\\]')).last;
  final cleaned = lastSegment.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return 'imboy_data_export.json';
  }
  return cleaned;
}

/// 触发浏览器下载导出 JSON。写入前须持有 Web 单 writer
/// （与 FL-08 startup busy / bootstrap 合同一致）。
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
  requireWebWriter();
  final bytes = Uint8List.fromList(utf8.encode(jsonContent));
  final blob = web.Blob(
    <web.BlobPart>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = safeName;
  var clicked = false;
  try {
    requireWebWriter();
    anchor.style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    clicked = true;
  } finally {
    anchor.remove();
    // 让浏览器消费本次下载后再释放对象 URL。
    if (clicked) {
      Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
    } else {
      web.URL.revokeObjectURL(url);
    }
  }
  return AccountExportDownloadResult(
    location: safeName,
    viaBrowserDownload: true,
  );
}
