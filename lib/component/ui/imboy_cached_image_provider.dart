import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';

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
        debugPrint('加载图片 (尝试 ${attempt + 1}/$maxAttempts): $url');

        final file = await IMBoyCacheManager().getSingleFile(
          url,
          headers: headers,
        );

        // 验证文件存在且可读
        if (!await file.exists()) {
          debugPrint('⚠️ 文件不存在: ${file.path}');
          if (attempt < maxAttempts - 1) {
            await _clearCacheAndRetry(url);
            continue;
          }
          throw StateError('文件不存在 (已尝试 $maxAttempts 次): ${file.path}');
        }

        // 读取文件字节
        final bytes = await file.readAsBytes();

        if (bytes.isEmpty) {
          debugPrint('⚠️ 文件为空: ${file.path}');
          if (attempt < maxAttempts - 1) {
            await _deleteFileIfExists(file);
            await _clearCacheAndRetry(url);
            continue;
          }
          throw StateError('文件为空 (已尝试 $maxAttempts 次): ${file.path}');
        }

        // 尝试解码图片
        try {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final codec = await decode(buffer);
          // debugPrint('✅ 图片加载成功: $url');
          return codec;
        } on Exception catch (decodeError) {
          debugPrint('⚠️ 图片解码失败: $decodeError');
          if (attempt < maxAttempts - 1) {
            await _deleteFileIfExists(file);
            await _clearCacheAndRetry(url);
            continue;
          }
          rethrow;
        }
      } on Exception catch (e) {
        debugPrint('❌ IMBoyCachedImageProvider 加载失败 (尝试 ${attempt + 1}/$maxAttempts): $url');
        debugPrint('   错误: $e');

        if (attempt == maxAttempts - 1) {
          // 最后一次尝试失败，重新抛出异常
          rethrow;
        }

        // 等待一段时间后重试
        await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      }
    }

    // 理论上不会到达这里，但为了类型安全
    throw StateError('图片加载失败: $url');
  }

  /// 删除文件（如果存在）
  Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ 已删除文件: ${file.path}');
      }
    } catch (e) {
      debugPrint('⚠️ 删除文件失败: $e');
    }
  }

  /// 清除缓存并准备重试
  Future<void> _clearCacheAndRetry(String url) async {
    try {
      // 清除缓存管理器中的缓存
      await IMBoyCacheManager().emptyCache();
      debugPrint('🔄 已清除缓存，准备重试');
    } catch (e) {
      debugPrint('⚠️ 清除缓存失败: $e');
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
  String toString() => 'IMBoyCachedImageProvider("$url")';
}
