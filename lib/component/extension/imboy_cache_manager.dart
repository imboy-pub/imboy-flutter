import 'dart:async';
import 'dart:io';

import 'package:cross_cache/cross_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:imboy/component/http/http_interceptor.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/account_media_cache_store.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/service/e2ee/attachment_open_registry.dart';
import 'package:imboy/service/e2ee/attachment_temp_hygiene.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/assets.dart';
import 'package:synchronized/synchronized.dart';

class MediaCacheCleanupException implements Exception {
  const MediaCacheCleanupException();
}

class IMBoyCacheManager {
  /// 控制 debug 日志输出（默认 true）
  ///
  /// 测试场景设为 false 可静默 '📦 getSingleFile' / '加载图片' / '📥 下载完成' 等
  /// debug 链日志，避免 widget test 输出污染。
  /// 不影响生产环境（kDebugMode 在 release build 自动 false，本 flag 仅在 debug 生效）。
  static bool debugLogEnabled = true;

  /// gate 后的 debugPrint：仅 [debugLogEnabled] 为 true 时输出
  static void _log(String message) {
    if (debugLogEnabled) debugPrint(message);
  }

  static final IMBoyCacheManager _instance = IMBoyCacheManager._();

  late final CrossCache _crossCache;
  final Dio _dio;
  final AccountMediaCacheStore _ownership = AccountMediaCacheStore();
  final Lock _fileLock = Lock();
  final Map<String, Set<Future<void>>> _pendingFiles = {};
  final Map<String, Future<void>> _cacheClears = {};
  final Map<String, int> _generations = {};
  final Map<String, List<WeakReference<Object>>> _imageKeys = {};
  final Set<String> _sweptStaleScopes = {};
  int get generation => generationFor(AccountLocalTaskOwner.capture());
  int generationFor(AccountLocalTaskOwner owner) =>
      _generations[AccountMediaCacheStore.scopeId(owner)] ?? 0;

  factory IMBoyCacheManager() {
    return _instance;
  }

  IMBoyCacheManager._()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      )..interceptors.add(IMBoyInterceptor()) {
    _crossCache = CrossCache(dio: _dio);
  }

  @visibleForTesting
  IMBoyCacheManager.forTest(Dio dio) : _dio = dio {
    _crossCache = CrossCache(dio: dio);
  }

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

    // HEIC/HEIF: ISO Base Media File Format — ftyp box at offset 4
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (brand.startsWith('hei') ||
          brand.startsWith('hev') ||
          brand == 'mif1' ||
          brand == 'msf1') {
        return true;
      }
    }

    return false;
  }

  /// BUG#137：判断 host 是否属于 Garage 公开资源基址（Env.publicBaseUrl）。
  static bool _isGarageHost(String host) {
    final base = Uri.tryParse(Env.publicBaseUrl);
    if (base == null || base.host.isEmpty) return false;
    final h = host.toLowerCase();
    final b = base.host.toLowerCase();
    return h == b || h.endsWith('.$b');
  }

  /// BUG#137：Garage 完整 URL（`https://s3.imboy.pub/<bucket>/<object_key>`）
  /// → object_key（剥掉第一段 bucket）。如 `/imboy/file_123_abc/a.mp4`
  /// → `file_123_abc/a.mp4`，与 [AssetsService.isObjectKey] 的
  /// `file_<ts>_<hex>/` 前缀规则匹配。
  static String _objectKeyFromUrl(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.skip(1).join('/');
  }

  Future<File> getSingleFile(
    String url, {
    Map<String, String>? headers,
    int maxRetries = 3,

    /// 是否验证图片数据（音频、视频等非图片文件应设为 false）
    bool validateImageData = true,

    /// 公开资源直读（scope=public，如头像）：[url] 已是完整公开 URL，
    /// 直接下载，**不**走 object_key 短时签发，**不**拼 go-fastdfs HMAC 授权
    /// （见 resource-access-control.md §9）。
    bool publicDirect = false,
    AccountLocalTaskOwner? owner,
  }) {
    try {
      final account = owner ?? AccountLocalTaskOwner.capture();
      final session = authSessionReader.current;
      final scope = AccountMediaCacheStore.scopeId(account);
      if (_cacheClears.containsKey(scope) ||
          (account.uid.isEmpty && !publicDirect)) {
        throw const MediaCacheCleanupException();
      }
      final generation = generationFor(account);
      final cancel = CancelToken();
      Future<File> load(AccountLocalTask? task) => _getSingleFile(
        url,
        headers: headers,
        maxRetries: maxRetries,
        validateImageData: validateImageData,
        publicDirect: publicDirect,
        owner: account,
        cancelToken: cancel,
        requireCurrent: () {
          task?.throwIfCancelled();
          if (generationFor(account) != generation ||
              (account.uid.isNotEmpty &&
                  (!authSessionReader.isCurrent(session) ||
                      session.uid != account.uid ||
                      account != AccountLocalTaskOwner.capture()))) {
            throw const MediaCacheCleanupException();
          }
        },
      );
      final result = account.uid.isEmpty
          ? load(null)
          : AccountLocalTaskRegistry.instance.run<File>(
              account,
              onCancel: () => cancel.cancel(),
              operation: load,
            );
      // Include authorization, downloading, decryption and all file writes.
      final pending = result.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      (_pendingFiles[scope] ??= {}).add(pending);
      unawaited(
        pending.then((_) {
          _pendingFiles[scope]?.remove(pending);
          if (_pendingFiles[scope]?.isEmpty ?? false) {
            _pendingFiles.remove(scope);
          }
        }),
      );
      return result;
    } on Object catch (error, stack) {
      return Future<File>.error(error, stack);
    }
  }

  Future<File> _getSingleFile(
    String url, {
    Map<String, String>? headers,
    required int maxRetries,
    required bool validateImageData,
    required bool publicDirect,
    required AccountLocalTaskOwner owner,
    required CancelToken cancelToken,
    required void Function() requireCurrent,
  }) async {
    requireCurrent();
    // 添加调试日志
    _log('📦 getSingleFile: url=$url, validateImageData=$validateImageData');

    if (url.isEmpty) {
      throw Exception('IMBoyCacheManager getSingleFile url is empty');
    }

    // SSRF/Cache Pollution 安全加固：拒绝非 http/https 协议 (C7-α)
    if (!url.startsWith('objkey://') && !AssetsService.isObjectKey(url)) {
      final parsed = Uri.tryParse(url);
      if (parsed == null ||
          (parsed.hasScheme &&
              parsed.scheme != 'http' &&
              parsed.scheme != 'https')) {
        throw Exception('Security Block: Invalid URI scheme in getSingleFile');
      }
      // 【审计修复 F-13】协议虽合法，再拒绝指向内网/云元数据/环回的 host，
      // 防止消息 payload.uri 被构造成 SSRF-to-storage（下载任意字节到本地缓存）。
      // 采用"拒绝内网"而非"域名白名单"：imboy 去中心化部署的资源节点不固定，
      // 强白名单会误伤用户自建存储；而内网/元数据地址在任何部署下都不应被下载。
      // 注：parsed 到此处不可能为 null（null 已在上方抛异常），hasScheme 已由
      // 上方 scheme 校验间接保证为 http/https。
      if (parsed.host.isNotEmpty) {
        final host = parsed.host.toLowerCase();
        final isInternal =
            host == 'localhost' ||
            host.startsWith('127.') ||
            host.startsWith('10.') ||
            host.startsWith('192.168.') ||
            // 172.16.0.0/12 私网段
            (_isPrivate172(host)) ||
            host == '0.0.0.0' ||
            host == '::1' ||
            host == 'metadata.google.internal' || // GCP 元数据
            host == '169.254.169.254'; // 云元数据链路本地地址
        if (isInternal) {
          throw Exception(
            'Security Block: getSingleFile refused internal host: $host',
          );
        }
      }
    }

    // 下载边界分流：
    // - object_key（新 Garage 链路）→ async 换取短时 presigned URL；cacheKey 用
    //   稳定 object_key，与 rotating 签发参数解耦，命中率更高。
    // - 完整 URL（旧 go-fastdfs / 历史消息）→ 同步 viewUrl 拼 HMAC 授权，行为不变。
    final bool isObjKey = AssetsService.isObjectKey(url);
    final String resourceKey;
    final String downloadUrl;
    final String extSource; // 推导文件扩展名的来源串
    if (publicDirect) {
      // 公开资源：url 即完整公开 URL，直读直下，cacheKey 用规范化 URL。
      final rawUri = Uri.parse(url);
      resourceKey =
          '${rawUri.scheme}://${rawUri.host}:${rawUri.port}${rawUri.path}';
      downloadUrl = url;
      extSource = rawUri.path;
    } else if (isObjKey) {
      resourceKey = 'objkey://$url';
      downloadUrl = await AssetUrlResolver.instance.resolve(url);
      extSource = url;
    } else {
      final rawUri = Uri.parse(url);
      resourceKey =
          '${rawUri.scheme}://${rawUri.host}:${rawUri.port}${rawUri.path}';
      // BUG#137：Garage 私桶完整 URL（群文件等，elib_oss:upload 落库的裸
      // URL 不带签名，attachment 表无记录）——viewUrl 拼的 go-fastdfs HMAC
      // （?s&a&v，s/a 为空）Garage 不认 → GET 404。host 属 publicBaseUrl
      // 时提取 object_key（剥掉 bucket 段）走后端 view_url 签发 presign GET。
      extSource = rawUri.path;
      if (AssetsService.isPresignedUrl(url)) {
        downloadUrl = url;
      } else if (_isGarageHost(rawUri.host)) {
        downloadUrl = await AssetUrlResolver.instance.resolve(
          _objectKeyFromUrl(rawUri),
        );
      } else {
        final viewUri = await AssetsService.viewUrlAsync(url);
        downloadUrl = viewUri.toString();
      }
    }
    requireCurrent();
    final cacheKey = await _ownership.reserve(owner, resourceKey);
    requireCurrent();
    // 验证真实下载域名：public 头像应为 s3.imboy.pub 直读；附件应为后端签发的
    // presigned host（X-Amz-Signature）。若这里出现 pro.imboy.pub，即下载走了 API 域名。
    _log(
      '🌐 实际下载 URL: host=${Uri.tryParse(downloadUrl)?.host} '
      'publicDirect=$publicDirect isObjKey=$isObjKey downloadUrl=$downloadUrl',
    );

    List<int> bytes = [];

    // 尝试从缓存获取
    for (int retry = 0; retry < maxRetries; retry++) {
      requireCurrent();
      try {
        bytes = await _crossCache.get(cacheKey);
        requireCurrent();
        // 检查缓存是否为空
        if (bytes.isEmpty) {
          _log('缓存为空，重新下载 (尝试 ${retry + 1}/$maxRetries): $url');
          throw Exception('Empty cache');
        }
        // 仅在需要时验证缓存数据是否有效
        if (validateImageData && !_isValidImageData(bytes)) {
          _log('缓存数据损坏，重新下载 (尝试 ${retry + 1}/$maxRetries): $url');
          await _crossCache.delete(cacheKey);
          throw Exception('Invalid cached image data');
        }
        // 缓存成功，跳出循环
        break;
      } catch (e) {
        requireCurrent();
        // 缓存失败，尝试下载
        try {
          // The same Dio retains authentication/interceptor behavior. Never use
          // downloadAndSave: it first persists an ownerless signed-URL entry.
          final response = await _dio.get<List<int>>(
            downloadUrl,
            options: Options(
              headers: headers,
              responseType: ResponseType.bytes,
            ),
            cancelToken: cancelToken,
          );
          requireCurrent();
          if (response.statusCode != 200) {
            throw DioException.badResponse(
              statusCode: response.statusCode ?? -1,
              requestOptions: response.requestOptions,
              response: response,
            );
          }
          final rawDownloaded = Uint8List.fromList(response.data ?? const []);

          // E2EE-061 Slice 6：开封必须排在**验证与落盘之前**——
          // 密文过不了图片魔数校验（会被当成"损坏"反复重下），
          // 缓存里也必须是明文（下次命中走的是不再开封的那条路）。
          // 没登记过 spec 的对象原样返回 = 今天的明文行为。
          final Uint8List downloaded = isObjKey
              ? AttachmentOpenRegistry.materialize(url, rawDownloaded)
              : rawDownloaded;

          // 调试：输出下载状态
          _log(
            '📥 下载完成，大小: ${downloaded.length} bytes, validateImageData=$validateImageData',
          );

          // 检查下载的文件是否为空
          if (downloaded.isEmpty) {
            _log('下载的文件为空 (尝试 ${retry + 1}/$maxRetries): $url');
            if (retry < maxRetries - 1) {
              try {
                await _crossCache.delete(cacheKey);
              } catch (e) {
                _log('[CacheManager] cache operation failed: $e');
              }
              continue;
            }
            throw Exception(
              'Downloaded file is empty after $maxRetries retries',
            );
          }

          // 仅在需要时验证下载的图片数据是否有效
          if (validateImageData && !_isValidImageData(downloaded)) {
            _log('⚠️ 图片数据验证失败，重新下载 (尝试 ${retry + 1}/$maxRetries): $url');
            if (retry < maxRetries - 1) {
              try {
                await _crossCache.delete(cacheKey);
              } catch (e) {
                _log('[CacheManager] cache operation failed: $e');
              }
              continue;
            }
            throw Exception(
              'Downloaded invalid image data after $maxRetries retries',
            );
          }

          await _crossCache.set(cacheKey, downloaded);
          requireCurrent();
          bytes = downloaded;
          _log('✅ 下载成功');
          // 下载成功，跳出循环
          break;
        } catch (downloadError) {
          requireCurrent();
          if (downloadError is DioException &&
              CancelToken.isCancel(downloadError)) {
            rethrow;
          }
          // E2EE-061：开封失败**绝不重试**——重下同一个对象不会变好，
          // 而重试会把 3 次下载 + 清缓存全走一遍。密文也不得留在缓存里。
          if (downloadError is AttachmentOpenException) {
            _log('❌ 附件开封失败，不重试: ${downloadError.message}');
            try {
              await _crossCache.delete(cacheKey);
            } on Object catch (_) {
              // best-effort：删不掉也不该盖住开封失败这个真因
            }
            rethrow;
          }
          // 404 错误不需要重试
          if (_isNotFoundError(downloadError)) {
            _log('❌ 资源不存在 (404): $url');
            rethrow;
          }
          _log('下载失败 (尝试 ${retry + 1}/$maxRetries): $downloadError');
          if (retry == maxRetries - 1) {
            rethrow;
          }
          // 等待一段时间后重试
          await Future<dynamic>.delayed(
            Duration(milliseconds: 500 * (retry + 1)),
          );
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
      requireCurrent();
      final directory = await _ownership.materializedDirectory(owner);
      requireCurrent();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      requireCurrent();
      // Preserve the existing stale-plaintext hygiene within this owner only.
      if (_sweptStaleScopes.add(AccountMediaCacheStore.scopeId(owner))) {
        await AttachmentTempHygiene.sweep(directory);
        requireCurrent();
      }
      final candidateExt = _getFileExtension(extSource) ?? 'cache';
      final ext = RegExp(r'^[A-Za-z0-9]{1,12}$').hasMatch(candidateExt)
          ? candidateExt
          : 'cache';
      final fileName = '${AccountMediaCacheStore.digest(cacheKey)}.$ext';
      final file = File('${directory.path}/$fileName');

      // 检查文件是否已存在且有效
      if (await file.exists()) {
        try {
          final existingBytes = await file.readAsBytes();
          requireCurrent();
          if (existingBytes.isNotEmpty &&
              (validateImageData ? _isValidImageData(existingBytes) : true)) {
            // debugPrint('使用现有缓存文件: ${file.path}');
            return file;
          }
        } catch (e) {
          requireCurrent();
          _log('[CacheManager] cache operation failed: $e');
          // 文件损坏，删除后重新写入
          await file.delete();
        }
      }

      // 使用临时文件确保原子性写入
      final tempFile = File('${directory.path}/$fileName.tmp');
      try {
        requireCurrent();
        // 写入临时文件
        await tempFile.writeAsBytes(bytes, flush: true);
        requireCurrent();

        // 验证临时文件是否写入成功
        if (!await tempFile.exists()) {
          throw Exception('Failed to write temp file: ${tempFile.path}');
        }

        // 原子性重命名
        await tempFile.rename(file.path);
        requireCurrent();

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
        } catch (e) {
          _log('[CacheManager] cache operation failed: $e');
        }
        rethrow;
      }
    });
  }

  /// 判断 IPv4 是否落在 172.16.0.0/12 私网段（172.16.x ~ 172.31.x）。
  /// 用于 F-13 SSRF 加固的内网地址拒绝。
  bool _isPrivate172(String host) {
    if (!host.startsWith('172.')) return false;
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  String? _getFileExtension(String path) {
    try {
      final uri = Uri.parse(path);
      final filePath = uri.path;
      final lastDotIndex = filePath.lastIndexOf('.');
      if (lastDotIndex != -1 && lastDotIndex < filePath.length - 1) {
        return filePath.substring(lastDotIndex + 1);
      }
    } catch (e) {
      _log('[CacheManager] cache operation failed: $e');
    }
    return null;
  }

  Future<void> emptyCache() => clearAccount(AccountLocalTaskOwner.capture());

  Future<void> clearAccount(AccountLocalTaskOwner owner) {
    final scope = AccountMediaCacheStore.scopeId(owner);
    final existing = _cacheClears[scope];
    if (existing != null) return existing;
    final clearing = _clearAccountAfterDownloads(owner).whenComplete(() {
      _cacheClears.remove(scope);
    });
    _cacheClears[scope] = clearing;
    return clearing;
  }

  Future<void> _clearAccountAfterDownloads(AccountLocalTaskOwner owner) async {
    final scope = AccountMediaCacheStore.scopeId(owner);
    await Future.wait(_pendingFiles[scope]?.toList() ?? <Future<void>>[]);
    await _ownership.assertRemovalCanBeAttributed();
    _generations[scope] = generationFor(owner) + 1;
    for (final reference
        in _imageKeys.remove(scope) ?? <WeakReference<Object>>[]) {
      final key = reference.target;
      if (key != null) PaintingBinding.instance.imageCache.evict(key);
    }
    await _ownership.removeAccount(
      owner,
      deleteKey: _crossCache.delete,
      containsKey: _crossCache.contains,
    );
    _sweptStaleScopes.remove(scope);
  }

  void trackImageKey(AccountLocalTaskOwner owner, Object key) {
    final entries = _imageKeys.putIfAbsent(
      AccountMediaCacheStore.scopeId(owner),
      () => [],
    );
    entries.removeWhere((reference) => reference.target == null);
    if (!entries.any((reference) => reference.target == key)) {
      entries.add(WeakReference(key));
    }
  }

  Future<void> removeResource(
    String url, {
    required AccountLocalTaskOwner owner,
    int? generation,
  }) async {
    final session = authSessionReader.current;
    final scope = AccountMediaCacheStore.scopeId(owner);
    if (_cacheClears.containsKey(scope)) {
      throw const MediaCacheCleanupException();
    }
    final uri = Uri.tryParse(url);
    final resource = AssetsService.isObjectKey(url)
        ? 'objkey://$url'
        : '${uri!.scheme}://${uri.host}:${uri.port}${uri.path}';
    final key = AccountMediaCacheStore.cacheKey(owner, resource);
    Future<void> remove(AccountLocalTask? task) async {
      if ((generation != null && generationFor(owner) != generation) ||
          (owner.uid.isNotEmpty &&
              (!authSessionReader.isCurrent(session) ||
                  session.uid != owner.uid ||
                  owner != AccountLocalTaskOwner.capture()))) {
        throw const MediaCacheCleanupException();
      }
      task?.throwIfCancelled();
      await _crossCache.delete(key);
      task?.throwIfCancelled();
      await _fileLock.synchronized(
        () => _ownership.removeResourceFiles(owner, key),
      );
    }

    if (owner.uid.isEmpty) {
      await remove(null);
    } else {
      await AccountLocalTaskRegistry.instance.run<void>(
        owner,
        operation: remove,
      );
    }
  }

  void dispose() {
    _crossCache.dispose();
  }

  /// 检测是否为 404 或资源不存在错误
  bool _isNotFoundError(Object error) {
    if (error is DioException) {
      return error.response?.statusCode == 404;
    }
    // 检查错误消息中是否包含 404 或 not found
    final msg = error.toString().toLowerCase();
    return msg.contains('404') || msg.contains('not found');
  }
}
