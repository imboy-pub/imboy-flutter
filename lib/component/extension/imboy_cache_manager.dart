import 'dart:io';

import 'package:cross_cache/cross_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/service/assets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

class IMBoyCacheManager {
  static final IMBoyCacheManager _instance = IMBoyCacheManager._();

  final CrossCache _crossCache;
  final Lock _fileLock = Lock();

  factory IMBoyCacheManager() {
    return _instance;
  }

  IMBoyCacheManager._()
    : _crossCache = CrossCache(
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
        ),
      );

  /// 验证图片数据是否有效
  bool _isValidImageData(List<int> bytes) {
    if (bytes.isEmpty || bytes.length < 8) {
      return false;
    }

    // 检查常见图片格式的魔数（文件头）
    final header = bytes.sublist(0, 8);

    // JPEG: FF D8 FF
    if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47 &&
        header[4] == 0x0D &&
        header[5] == 0x0A &&
        header[6] == 0x1A &&
        header[7] == 0x0A) {
      return true;
    }

    // GIF: 47 49 46 38 (GIF8)
    if (header[0] == 0x47 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x38) {
      return true;
    }

    // WebP: 52 49 46 46 ... 57 45 42 50
    if (header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        bytes.length > 11 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    // BMP: 42 4D
    if (header[0] == 0x42 && header[1] == 0x4D) {
      return true;
    }

    return false;
  }

  Future<File> getSingleFile(
    String url, {
    Map<String, String>? headers,
    int maxRetries = 3,
  }) async {
    if (url.isEmpty) {
      throw Exception('IMBoyCacheManager getSingleFile url is empty');
    }
    final rawUri = Uri.parse(url);
    final cacheKey =
        '${rawUri.scheme}://${rawUri.host}:${rawUri.port}${rawUri.path}';
    final viewUri = AssetsService.viewUrl(url);
    List<int> bytes = [];

    // 尝试从缓存获取
    for (int retry = 0; retry < maxRetries; retry++) {
      try {
        bytes = await _crossCache.get(cacheKey);
        // 检查缓存是否为空
        if (bytes.isEmpty) {
          debugPrint('缓存为空，重新下载 (尝试 ${retry + 1}/$maxRetries): $url');
          throw Exception('Empty cache');
        }
        // 验证缓存数据是否有效
        if (!_isValidImageData(bytes)) {
          debugPrint('缓存数据损坏，重新下载 (尝试 ${retry + 1}/$maxRetries): $url');
          await _crossCache.delete(cacheKey);
          throw Exception('Invalid cached image data');
        }
        // 缓存成功，跳出循环
        break;
      } catch (e) {
        // 缓存失败，尝试下载
        try {
          final downloaded = await _crossCache.downloadAndSave(
            viewUri.toString(),
            headers: headers,
          );
          // 检查下载的文件是否为空
          if (downloaded.isEmpty) {
            debugPrint('下载的文件为空 (尝试 ${retry + 1}/$maxRetries): $url');
            if (retry < maxRetries - 1) {
              // 删除损坏的缓存，准备重试
              try {
                await _crossCache.delete(cacheKey);
              } catch (_) {}
              continue;
            }
            throw Exception(
              'Downloaded file is empty after $maxRetries retries',
            );
          }

          // 验证下载的图片数据是否有效
          if (!_isValidImageData(downloaded)) {
            // debugPrint('下载的图片数据无效 (尝试 ${retry + 1}/$maxRetries): $url');
            if (retry < maxRetries - 1) {
              try {
                await _crossCache.delete(cacheKey);
              } catch (_) {}
              continue;
            }
            throw Exception(
              'Downloaded invalid image data after $maxRetries retries',
            );
          }

          await _crossCache.set(cacheKey, downloaded);
          await _crossCache.delete(viewUri.toString());
          bytes = downloaded;
          // 下载成功，跳出循环
          break;
        } catch (downloadError) {
          debugPrint('下载失败 (尝试 ${retry + 1}/$maxRetries): $downloadError');
          if (retry == maxRetries - 1) {
            rethrow;
          }
          // 等待一段时间后重试
          await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
        }
      }
    }

    // 最终检查 bytes 是否为空
    if (bytes.isEmpty) {
      throw Exception(
        'Failed to download image after $maxRetries retries: bytes is empty',
      );
    }

    // 使用文件锁防止并发写入冲突
    return await _fileLock.synchronized(() async {
      final tempDir = await getTemporaryDirectory();
      final directory = Directory('${tempDir.path}/imboy_cache');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final ext = _getFileExtension(viewUri.path) ?? 'cache';
      final fileName = 'imboy_cache_${_hashCode(cacheKey)}.$ext';
      final file = File('${directory.path}/$fileName');

      // 检查文件是否已存在且有效
      if (await file.exists()) {
        try {
          final existingBytes = await file.readAsBytes();
          if (existingBytes.isNotEmpty && _isValidImageData(existingBytes)) {
            // debugPrint('使用现有缓存文件: ${file.path}');
            return file;
          }
        } catch (_) {
          // 文件损坏，删除后重新写入
          await file.delete();
        }
      }

      // 使用临时文件确保原子性写入
      final tempFile = File('${directory.path}/$fileName.tmp');
      try {
        // 写入临时文件
        await tempFile.writeAsBytes(bytes, flush: true);

        // 验证临时文件是否写入成功
        if (!await tempFile.exists()) {
          throw Exception('Failed to write temp file: ${tempFile.path}');
        }

        // 原子性重命名
        await tempFile.rename(file.path);

        // 最终验证文件是否成功创建
        if (!await file.exists()) {
          throw Exception('Failed to create file after rename: ${file.path}');
        }

        return file;
      } catch (e) {
        // 清理临时文件
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
        rethrow;
      }
    });
  }

  String _hashCode(String input) {
    return input.hashCode.toString();
  }

  String? _getFileExtension(String path) {
    try {
      final uri = Uri.parse(path);
      final filePath = uri.path;
      final lastDotIndex = filePath.lastIndexOf('.');
      if (lastDotIndex != -1 && lastDotIndex < filePath.length - 1) {
        return filePath.substring(lastDotIndex + 1);
      }
    } catch (_) {}
    return null;
  }

  Future<void> emptyCache() async {
    final cacheDir = await getApplicationCacheDirectory();
    final crossCacheDir = Directory('${cacheDir.path}/cross_cache');
    if (await crossCacheDir.exists()) {
      await crossCacheDir.delete(recursive: true);
    }

    final tempDir = await getTemporaryDirectory();
    final imboyCacheDir = Directory('${tempDir.path}/imboy_cache');
    if (await imboyCacheDir.exists()) {
      await imboyCacheDir.delete(recursive: true);
    }
  }

  void dispose() {
    _crossCache.dispose();
  }
}
