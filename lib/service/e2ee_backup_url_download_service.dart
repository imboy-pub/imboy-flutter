import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// E2EE 备份文件的 URL 下载服务（导入增强 A）。
///
/// 设计要点：
/// - 使用**独立** Dio 实例，不走 App 的 [HttpClient]（后者会向每个请求
///   挂 JWT 与设备签名头，[http_client.dart] _setDefaultConfig）。这些
///   凭据绝不能发到第三方主机——下载链接可能指向任意邮箱/网盘/自建主机。
/// - 仅允许 HTTPS；HTTP 一律拒绝。
/// - 超时、体积上限，避免恶意大文件耗尽存储。
/// - 下载结果写到 [getTemporaryDirectory]，由调用方在用完后删除。
class E2EEBackupUrlDownloadService {
  E2EEBackupUrlDownloadService._();

  /// 体积上限：10MB。.enc 备份通常 < 50KB，留足缓冲应对未来格式扩展。
  static const int maxSizeBytes = 10 * 1024 * 1024;

  /// 连接超时
  static const Duration connectTimeout = Duration(seconds: 10);

  /// 接收超时（两次数据间隔）
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// 下载 URL 指向的备份文件到临时目录，返回本地文件路径。
  ///
  /// 抛出 [E2EEBackupUrlDownloadException]，[code] 字段区分失败类型，
  /// 调用方据 [code] 映射到对应的 i18n 错误文案。
  static Future<String> downloadToTemp(String url) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || parsed.scheme != 'https') {
      throw const E2EEBackupUrlDownloadException(
        code: E2EEBackupUrlDownloadErrorCode.invalidUrl,
        message: '仅支持 HTTPS 链接',
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 5,
        // 不带任何 App 凭据头
        headers: const {'user-agent': 'IMBoy-E2EE-Backup-Import/1.0'},
      ),
    );

    // 流式下载：在 onReceiveProgress 中累计字节，超限即取消请求，
    // 避免大文件先全量读入内存再拒绝（OOM 风险）。
    final cancelToken = CancelToken();
    int receivedBytes = 0;
    bool overLimit = false;

    try {
      final response = await dio.get<ResponseBody>(
        url,
        onReceiveProgress: (received, _) {
          receivedBytes = received;
          if (received > maxSizeBytes) {
            overLimit = true;
            cancelToken.cancel('file too large');
          }
        },
        cancelToken: cancelToken,
      );

      // 流式响应：先检查状态码，再逐块写盘
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode < 200 || statusCode >= 300) {
        throw E2EEBackupUrlDownloadException(
          code: E2EEBackupUrlDownloadErrorCode.httpError,
          message: '服务器返回 $statusCode',
        );
      }

      final stream = response.data;
      if (stream == null) {
        throw const E2EEBackupUrlDownloadException(
          code: E2EEBackupUrlDownloadErrorCode.emptyResponse,
          message: '服务器返回空内容',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'imboy_e2ee_backup_url_$timestamp.enc';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      final sink = file.openWrite();
      try {
        await for (final chunk in stream.stream) {
          receivedBytes += chunk.length;
          if (receivedBytes > maxSizeBytes) {
            overLimit = true;
            break;
          }
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (overLimit) {
        await E2EEBackupUrlDownloadService.cleanupTempFile(filePath);
        throw const E2EEBackupUrlDownloadException(
          code: E2EEBackupUrlDownloadErrorCode.tooLarge,
          message: '文件超过 10MB 上限',
        );
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        await E2EEBackupUrlDownloadService.cleanupTempFile(filePath);
        throw const E2EEBackupUrlDownloadException(
          code: E2EEBackupUrlDownloadErrorCode.emptyResponse,
          message: '服务器返回空内容',
        );
      }

      return filePath;
    } on E2EEBackupUrlDownloadException {
      rethrow;
    } on DioException catch (e) {
      // 取消（超限）不是网络错误，已在上面处理
      if (e.type == DioExceptionType.cancel && overLimit) {
        throw const E2EEBackupUrlDownloadException(
          code: E2EEBackupUrlDownloadErrorCode.tooLarge,
          message: '文件超过 10MB 上限',
        );
      }
      throw E2EEBackupUrlDownloadException(
        code: _mapDioError(e),
        message: e.message ?? e.type.name,
      );
    } on FormatException catch (e) {
      throw E2EEBackupUrlDownloadException(
        code: E2EEBackupUrlDownloadErrorCode.invalidUrl,
        message: e.message,
      );
    } on IOException catch (e) {
      // 写盘失败
      throw E2EEBackupUrlDownloadException(
        code: E2EEBackupUrlDownloadErrorCode.ioError,
        message: e.toString(),
      );
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[E2EE URL Download] 未预期错误: $e');
      }
      throw E2EEBackupUrlDownloadException(
        code: E2EEBackupUrlDownloadErrorCode.unknown,
        message: e.toString(),
      );
    } finally {
      dio.close();
    }
  }

  static E2EEBackupUrlDownloadErrorCode _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return E2EEBackupUrlDownloadErrorCode.timeout;
      case DioExceptionType.badResponse:
        return E2EEBackupUrlDownloadErrorCode.httpError;
      case DioExceptionType.connectionError:
        return E2EEBackupUrlDownloadErrorCode.networkError;
      case DioExceptionType.badCertificate:
        return E2EEBackupUrlDownloadErrorCode.tlsError;
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
      default:
        return E2EEBackupUrlDownloadErrorCode.unknown;
    }
  }

  /// 删除 URL 下载产生的临时文件（导入页 dispose / 重新下载时调用）。
  /// 文件选择器产生的文件不归本服务管，不在此删除。
  static Future<void> cleanupTempFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // 清理失败不阻断流程
    }
  }
}

/// URL 下载失败的错误码，调用方据 [code] 映射 i18n 文案。
enum E2EEBackupUrlDownloadErrorCode {
  invalidUrl,
  networkError,
  timeout,
  tlsError,
  httpError,
  emptyResponse,
  tooLarge,
  ioError,
  unknown,
}

class E2EEBackupUrlDownloadException implements Exception {
  final E2EEBackupUrlDownloadErrorCode code;
  final String message;

  const E2EEBackupUrlDownloadException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'E2EEBackupUrlDownloadException($code): $message';
}
