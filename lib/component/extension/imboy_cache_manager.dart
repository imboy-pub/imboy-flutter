import 'dart:io';

import 'package:cross_cache/cross_cache.dart';
import 'package:dio/dio.dart';
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
  }) async {
    final rawUri = Uri.parse(url);
    final cacheKey =
        '${rawUri.scheme}://${rawUri.host}:${rawUri.port}${rawUri.path}';
    final viewUri = AssetsService.viewUrl(url);
    List<int> bytes;
    try {
      bytes = await _crossCache.get(cacheKey);
    } catch (_) {
      final downloaded = await _crossCache.downloadAndSave(
        viewUri.toString(),
        headers: headers,
      );
      await _crossCache.set(cacheKey, downloaded);
      await _crossCache.delete(viewUri.toString());
      bytes = downloaded;
    }

    final tempDir = await getTemporaryDirectory();
    final directory = Directory('${tempDir.path}/imboy_cache');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final ext = _getFileExtension(viewUri.path) ?? 'cache';
    final fileName = 'imboy_cache_${_hashCode(cacheKey)}.$ext';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(bytes);
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
