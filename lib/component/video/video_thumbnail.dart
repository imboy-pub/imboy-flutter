import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:imboy/component/helper/func.dart';

/// 视频缩略图缓存管理器
class VideoThumbnailCache {
  static final VideoThumbnailCache _instance = VideoThumbnailCache._internal();
  factory VideoThumbnailCache() => _instance;
  VideoThumbnailCache._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, Future<Uint8List?>> _loadingCache = {};

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/video_thumbnails');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 生成缓存键
  String _generateCacheKey(String videoPath, Duration position) {
    final input = '$videoPath-${position.inSeconds}';
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 获取缓存文件路径
  Future<String> _getCacheFilePath(String cacheKey) async {
    final cacheDir = await _getCacheDirectory();
    return '${cacheDir.path}/$cacheKey.jpg';
  }

  /// 从内存缓存获取缩略图
  Uint8List? getFromMemory(String cacheKey) {
    return _memoryCache[cacheKey];
  }

  /// 从磁盘缓存获取缩略图
  Future<Uint8List?> getFromDisk(String cacheKey) async {
    try {
      final filePath = await _getCacheFilePath(cacheKey);
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // 同时缓存到内存
        _memoryCache[cacheKey] = bytes;
        return bytes;
      }
    } catch (e) {
      iPrint('从磁盘缓存获取缩略图失败: $e');
    }
    return null;
  }

  /// 保存缩略图到缓存
  Future<void> saveToCache(String cacheKey, Uint8List bytes) async {
    try {
      // 保存到内存缓存
      _memoryCache[cacheKey] = bytes;

      // 保存到磁盘缓存
      final filePath = await _getCacheFilePath(cacheKey);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      iPrint('保存缩略图到缓存失败: $e');
    }
  }

  /// 生成缩略图
  Future<Uint8List?> generateThumbnail(
    String videoPath, {
    Duration position = const Duration(seconds: 1),
    int maxWidth = 300,
    int maxHeight = 200,
  }) async {
    final cacheKey = _generateCacheKey(videoPath, position);

    // 检查是否正在生成中
    if (_loadingCache.containsKey(cacheKey)) {
      return await _loadingCache[cacheKey];
    }

    // 检查内存缓存
    final memoryResult = getFromMemory(cacheKey);
    if (memoryResult != null) {
      return memoryResult;
    }

    // 检查磁盘缓存
    final diskResult = await getFromDisk(cacheKey);
    if (diskResult != null) {
      return diskResult;
    }

    // 生成缩略图
    final future = _doGenerateThumbnail(
      videoPath,
      position,
      maxWidth,
      maxHeight,
      cacheKey,
    );
    _loadingCache[cacheKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _loadingCache.remove(cacheKey);
    }
  }

  /// 实际生成缩略图的方法
  Future<Uint8List?> _doGenerateThumbnail(
    String videoPath,
    Duration position,
    int maxWidth,
    int maxHeight,
    String cacheKey,
  ) async {
    VideoPlayerController? controller;

    try {
      // 初始化视频控制器
      controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      // 跳转到指定位置
      await controller.seekTo(position);

      // 等待帧加载
      await Future.delayed(const Duration(milliseconds: 100));

      // 这里需要使用第三方库来获取视频帧
      // 由于Flutter原生不支持视频帧提取，这里返回null
      // 在实际项目中，可以使用video_thumbnail或ffmpeg_kit_flutter

      return null;
    } catch (e) {
      iPrint('生成视频缩略图失败: $e');
      return null;
    } finally {
      controller?.dispose();
    }
  }

  /// 清理缓存
  Future<void> clearCache() async {
    try {
      // 清理内存缓存
      _memoryCache.clear();

      // 清理磁盘缓存
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      iPrint('清理缓存失败: $e');
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      return totalSize;
    } catch (e) {
      iPrint('获取缓存大小失败: $e');
      return 0;
    }
  }
}

/// 视频缩略图显示组件
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final Duration position;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final bool showPlayIcon;
  final Duration? videoDuration;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.position = const Duration(seconds: 1),
    this.width = 200,
    this.height = 150,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.showPlayIcon = true,
    this.videoDuration,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  final VideoThumbnailCache _cache = VideoThumbnailCache();
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath ||
        oldWidget.position != widget.position) {
      _loadThumbnail();
    }
  }

  /// 加载缩略图
  Future<void> _loadThumbnail() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final thumbnailData = await _cache.generateThumbnail(
        widget.videoPath,
        position: widget.position,
        maxWidth: widget.width.toInt(),
        maxHeight: widget.height.toInt(),
      );

      if (mounted) {
        setState(() {
          _thumbnailData = thumbnailData;
          _isLoading = false;
          _hasError = thumbnailData == null;
        });
      }
    } catch (e) {
      iPrint('加载缩略图失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 缩略图或占位符
              _buildThumbnailContent(),

              // 播放图标覆盖层
              if (widget.showPlayIcon) _buildPlayIconOverlay(),

              // 时长显示
              if (widget.videoDuration != null) _buildDurationLabel(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建缩略图内容
  Widget _buildThumbnailContent() {
    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_hasError || _thumbnailData == null) {
      return widget.errorWidget ?? _buildDefaultError();
    }

    return Image.memory(
      _thumbnailData!,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ?? _buildDefaultError();
      },
    );
  }

  /// 构建默认占位符
  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  /// 构建默认错误显示
  Widget _buildDefaultError() {
    return Container(
      color: Colors.grey[400],
      child: const Center(
        child: Icon(Icons.videocam_off, size: 48, color: Colors.white70),
      ),
    );
  }

  /// 构建播放图标覆盖层
  Widget _buildPlayIconOverlay() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
      ),
    );
  }

  /// 构建时长标签
  Widget _buildDurationLabel() {
    return Positioned(
      bottom: 4,
      right: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatDuration(widget.videoDuration!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}
