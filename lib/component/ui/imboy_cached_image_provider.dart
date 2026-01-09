import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';

class IMBoyCachedImageProvider
    extends ImageProvider<IMBoyCachedImageProvider> {
  const IMBoyCachedImageProvider(this.url, this.headers);

  final String url;
  final Map<String, String> headers;

  @override
  Future<IMBoyCachedImageProvider> obtainKey(
      ImageConfiguration configuration) {
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

    try {
      final file =
          await IMBoyCacheManager().getSingleFile(url, headers: headers);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        debugPrint('文件不存在，重新下载: ${file.path}');
        throw StateError('File does not exist: ${file.path}');
      }
      
      final bytes = await file.readAsBytes();
      
      if (bytes.isEmpty) {
        // 删除损坏的缓存文件
        try {
          await file.delete();
          debugPrint('已删除损坏的缓存文件: ${file.path}');
        } catch (deleteError) {
          debugPrint('删除缓存文件失败: $deleteError');
        }
        
        // 重新下载
        debugPrint('重新下载图片: $url');
        final newFile =
            await IMBoyCacheManager().getSingleFile(url, headers: headers);
        
        // 检查新文件是否存在
        if (!await newFile.exists()) {
          throw StateError('下载的文件不存在: ${newFile.path}');
        }
        
        final newBytes = await newFile.readAsBytes();
        
        if (newBytes.isEmpty) {
          throw StateError('下载的文件为空: ${newFile.path}');
        }
        
        final buffer = await ui.ImmutableBuffer.fromUint8List(newBytes);
        return decode(buffer);
      }
      
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      debugPrint('IMBoyCachedImageProvider 加载图片失败: $url');
      debugPrint('错误详情: $e');
      // 重新抛出异常，让 Flutter 的错误处理机制接管
      rethrow;
    }
  }
}

