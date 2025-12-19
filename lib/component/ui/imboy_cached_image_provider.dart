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
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Empty file: ${file.path}');
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

