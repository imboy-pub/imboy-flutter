import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';

/// gate 后的 debug 日志：仅 [IMBoyCacheManager.debugLogEnabled] 为 true 时输出
/// 复用 IMBoyCacheManager 的全局 flag 让测试可统一关闭两边的日志
void _log(String message) {
  if (IMBoyCacheManager.debugLogEnabled) debugPrint(message);
}

/// 图片资源不存在异常（404）
class ImageNotFoundException implements Exception {
  final String message;
  ImageNotFoundException([String? message])
    : message = message ?? 'Image not found (404)';

  @override
  String toString() => 'ImageNotFoundException: $message';
}

class IMBoyCachedImageProvider extends ImageProvider<IMBoyCachedImageProvider> {
  const IMBoyCachedImageProvider(this.url, this.headers);

  final String url;
  final Map<String, String> headers;

  @override
  Future<IMBoyCachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future<IMBoyCachedImageProvider>.value(this);
  }

  @override
  ImageStreamCompleter loadImage(
    IMBoyCachedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(
    IMBoyCachedImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);

    // 重试机制：最多尝试3次
    const maxAttempts = 3;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (kDebugMode) {
          _log('加载图片 (尝试 ${attempt + 1}/$maxAttempts)');
        }

        final file = await IMBoyCacheManager().getSingleFile(
          url,
          headers: headers,
        );

        // 验证文件存在且可读
        if (!await file.exists()) {
          _log('⚠️ 文件不存在');
          if (attempt < maxAttempts - 1) {
            await _clearCacheAndRetry(url);
            continue;
          }
          throw StateError('文件不存在 (已尝试 $maxAttempts 次)');
        }

        // 读取文件字节
        final bytes = await file.readAsBytes();

        if (bytes.isEmpty) {
          _log('⚠️ 文件为空');
          if (attempt < maxAttempts - 1) {
            await _deleteFileIfExists(file);
            await _clearCacheAndRetry(url);
            continue;
          }
          throw StateError('文件为空 (已尝试 $maxAttempts 次)');
        }

        // 尝试解码图片
        try {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final codec = await decode(buffer);
          // debugPrint('✅ 图片加载成功: $url');
          return codec;
        } on Exception catch (decodeError) {
          _log('⚠️ 图片解码失败: ${decodeError.runtimeType}');
          if (attempt < maxAttempts - 1) {
            await _deleteFileIfExists(file);
            await _clearCacheAndRetry(url);
            continue;
          }
          rethrow;
        }
      } on Exception catch (e) {
        // 404 错误不需要重试
        if (_isNotFoundError(e)) {
          _log('❌ 图片资源不存在 (404)');
          throw ImageNotFoundException();
        }

        if (kDebugMode) {
          _log(
            '❌ IMBoyCachedImageProvider 加载失败 (尝试 ${attempt + 1}/$maxAttempts): ${e.runtimeType}',
          );
        }

        if (attempt == maxAttempts - 1) {
          // 最后一次尝试失败，重新抛出异常
          rethrow;
        }

        // 等待一段时间后重试
        await Future<dynamic>.delayed(
          Duration(milliseconds: 200 * (attempt + 1)),
        );
      }
    }

    // 理论上不会到达这里，但为了类型安全
    throw StateError('图片加载失败');
  }

  /// 删除文件（如果存在）
  Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        _log('🗑️ 已删除缓存文件');
      }
    } on Exception catch (e) {
      _log('⚠️ 删除文件失败: ${e.runtimeType}');
    }
  }

  /// 清除缓存并准备重试
  Future<void> _clearCacheAndRetry(String url) async {
    try {
      // 清除缓存管理器中的缓存
      await IMBoyCacheManager().emptyCache();
      _log('🔄 已清除缓存，准备重试');
    } on Exception catch (e) {
      _log('⚠️ 清除缓存失败: ${e.runtimeType}');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is IMBoyCachedImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'IMBoyCachedImageProvider(${url.hashCode})';

  /// 检测是否为 404 或资源不存在错误
  bool _isNotFoundError(Exception e) {
    if (e is DioException) {
      return e.response?.statusCode == 404;
    }
    // 检查异常消息中是否包含 404 或 not found
    final msg = e.toString().toLowerCase();
    return msg.contains('404') || msg.contains('not found');
  }
}
