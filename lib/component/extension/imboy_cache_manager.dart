import 'dart:io';

import 'package:cross_cache/cross_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/service/assets.dart';
import 'package:path_provider/path_provider.dart';

class IMBoyCacheManager {
  static final IMBoyCacheManager _instance = IMBoyCacheManager._();

  final CrossCache _crossCache;

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
            throw Exception('Downloaded file is empty after $maxRetries retries');
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
      throw Exception('Failed to download image after $maxRetries retries: bytes is empty');
    }

    final tempDir = await getTemporaryDirectory();
    final directory = Directory('${tempDir.path}/imboy_cache');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final ext = _getFileExtension(viewUri.path) ?? 'cache';
    final fileName = 'imboy_cache_${_hashCode(cacheKey)}.$ext';
    final file = File('${directory.path}/$fileName');

    // 确保文件写入成功
    await file.writeAsBytes(bytes, flush: true);
    
    // 验证文件是否成功写入
    if (!await file.exists()) {
      throw Exception('Failed to write file: ${file.path}');
    }
    
    return file;
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
