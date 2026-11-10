import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';

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
  factory IMBoyCachedImageProvider(
    String url,
    Map<String, String> headers, {
    bool publicDirect = false,
  }) {
    final owner = AccountLocalTaskOwner.capture();
    return IMBoyCachedImageProvider._owned(
      url,
      headers,
      publicDirect,
      owner,
      IMBoyCacheManager().generationFor(owner),
      owner.uid.isEmpty ? null : authSessionReader.current,
    );
  }

  const IMBoyCachedImageProvider._owned(
    this.url,
    this.headers,
    this.publicDirect,
    this._owner,
    this._generation,
    this._session,
  );

  final String url;
  final Map<String, String> headers;
  final AccountLocalTaskOwner _owner;
  final int _generation;
  final AuthSessionScope? _session;

  /// 公开资源直读（scope=public，如头像）：[url] 为完整公开 URL，直读直下，
  /// 不走 object_key 短时签发 / go-fastdfs HMAC（见 resource-access-control.md §9）。
  final bool publicDirect;

  @override
  Future<IMBoyCachedImageProvider> obtainKey(ImageConfiguration configuration) {
    final cache = IMBoyCacheManager();
    cache.trackImageKey(_owner, this);
    return SynchronousFuture(this);
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
    final cache = IMBoyCacheManager();
    final owner = key._owner;
    final generation = key._generation;
    void requireCurrentLoad() {
      if (cache.generationFor(owner) != generation ||
          (key._session != null &&
              !authSessionReader.isCurrent(key._session)) ||
          (owner.uid.isNotEmpty && owner != AccountLocalTaskOwner.capture())) {
        throw const MediaCacheCleanupException();
      }
    }

    // 重试机制：最多尝试3次
    const maxAttempts = 3;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      requireCurrentLoad();
      try {
        if (kDebugMode) {
          _log('加载图片 (尝试 ${attempt + 1}/$maxAttempts)');
        }

        final file = await cache.getSingleFile(
          key.url,
          headers: key.headers,
          publicDirect: key.publicDirect,
          owner: owner,
        );
        requireCurrentLoad();

        // 验证文件存在且可读
        if (!await file.exists()) {
          _log('⚠️ 文件不存在');
          if (attempt < maxAttempts - 1) {
            await _clearCacheAndRetry(key.url, owner, generation);
            continue;
          }
          throw StateError('文件不存在 (已尝试 $maxAttempts 次)');
        }

        // 读取文件字节
        final bytes = await file.readAsBytes();
        requireCurrentLoad();

        if (bytes.isEmpty) {
          _log('⚠️ 文件为空');
          if (attempt < maxAttempts - 1) {
            await _clearCacheAndRetry(key.url, owner, generation);
            continue;
          }
          throw StateError('文件为空 (已尝试 $maxAttempts 次)');
        }

        // 尝试解码图片
        try {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final codec = await decode(buffer);
          if (cache.generationFor(owner) != generation ||
              (key._session != null &&
                  !authSessionReader.isCurrent(key._session)) ||
              (owner.uid.isNotEmpty &&
                  owner != AccountLocalTaskOwner.capture())) {
            codec.dispose();
            throw const MediaCacheCleanupException();
          }
          // debugPrint('✅ 图片加载成功: $url');
          return codec;
        } on Exception catch (decodeError) {
          if (decodeError is MediaCacheCleanupException ||
              decodeError is AccountLocalTaskCancelledException) {
            rethrow;
          }
          _log('⚠️ 图片解码失败: ${decodeError.runtimeType}');
          if (attempt < maxAttempts - 1) {
            await _clearCacheAndRetry(key.url, owner, generation);
            continue;
          }
          rethrow;
        }
      } on Exception catch (e) {
        if (e is MediaCacheCleanupException ||
            e is AccountLocalTaskCancelledException) {
          rethrow;
        }
        requireCurrentLoad();
        // 404/401/403 无法通过重试解决，直接降级占位（不重试、不暴露异常）
        if (_isNotFoundError(e)) {
          _log('❌ 图片资源不可显示 (404/401/403)');
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

  /// 清除缓存并准备重试
  Future<void> _clearCacheAndRetry(
    String url,
    AccountLocalTaskOwner owner,
    int generation,
  ) async {
    try {
      await IMBoyCacheManager().removeResource(
        url,
        owner: owner,
        generation: generation,
      );
      _log('🔄 已清除缓存，准备重试');
    } on Exception catch (e) {
      if (e is MediaCacheCleanupException ||
          e is AccountLocalTaskCancelledException) {
        rethrow;
      }
      _log('⚠️ 清除缓存失败: ${e.runtimeType}');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is IMBoyCachedImageProvider &&
        other.url == url &&
        other.publicDirect == publicDirect &&
        other._owner == _owner &&
        other._generation == _generation &&
        other._session == _session;
  }

  @override
  int get hashCode =>
      Object.hash(url, publicDirect, _owner, _generation, _session);

  @override
  String toString() => 'IMBoyCachedImageProvider(${url.hashCode})';

  /// 检测是否为资源不可显示错误（404 不存在 / 401 未授权 / 403 禁止）。
  /// 这些都无法通过重试解决，应直接降级为占位图，而非 rethrow 把
  /// DioException 文本暴露到 UI（收藏图快照 URL 未走 presign 时会返回 401）。
  bool _isNotFoundError(Exception e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      return code == 404 || code == 401 || code == 403;
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('404') ||
        msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('not found');
  }
}
