import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';

/// 视频压缩质量枚举
enum VideoCompressQuality {
  low,     // 低质量 - 适合快速上传
  medium,  // 中等质量 - 平衡文件大小和质量
  high,    // 高质量 - 保持较好的视觉效果
  custom,  // 自定义质量
}

/// 视频压缩配置
class VideoCompressConfig {
  final VideoCompressQuality quality;
  final int? targetBitrate;      // 目标比特率 (kbps)
  final int? targetFrameRate;    // 目标帧率 (fps)
  final int? targetWidth;        // 目标宽度
  final int? targetHeight;       // 目标高度
  final Duration? maxDuration;   // 最大时长限制
  final int? maxFileSize;        // 最大文件大小 (bytes)
  final bool enableAudio;        // 是否包含音频
  final String? outputFormat;    // 输出格式 (mp4, mov等)

  const VideoCompressConfig({
    this.quality = VideoCompressQuality.medium,
    this.targetBitrate,
    this.targetFrameRate,
    this.targetWidth,
    this.targetHeight,
    this.maxDuration,
    this.maxFileSize,
    this.enableAudio = true,
    this.outputFormat = 'mp4',
  });

  /// 预设配置 - 低质量
  static const VideoCompressConfig lowQuality = VideoCompressConfig(
    quality: VideoCompressQuality.low,
    targetBitrate: 500,    // 500kbps
    targetFrameRate: 24,   // 24fps
    targetWidth: 640,      // 640p
    targetHeight: 480,
    maxFileSize: 10 * 1024 * 1024, // 10MB
  );

  /// 预设配置 - 中等质量
  static const VideoCompressConfig mediumQuality = VideoCompressConfig(
    quality: VideoCompressQuality.medium,
    targetBitrate: 1000,   // 1Mbps
    targetFrameRate: 30,   // 30fps
    targetWidth: 1280,     // 720p
    targetHeight: 720,
    maxFileSize: 50 * 1024 * 1024, // 50MB
  );

  /// 预设配置 - 高质量
  static const VideoCompressConfig highQuality = VideoCompressConfig(
    quality: VideoCompressQuality.high,
    targetBitrate: 2000,   // 2Mbps
    targetFrameRate: 30,   // 30fps
    targetWidth: 1920,     // 1080p
    targetHeight: 1080,
    maxFileSize: 100 * 1024 * 1024, // 100MB
  );
}

/// 视频压缩结果
class VideoCompressResult {
  final bool success;
  final String? outputPath;
  final int? originalSize;
  final int? compressedSize;
  final Duration? originalDuration;
  final Duration? compressedDuration;
  final double? compressionRatio;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  VideoCompressResult({
    required this.success,
    this.outputPath,
    this.originalSize,
    this.compressedSize,
    this.originalDuration,
    this.compressedDuration,
    this.compressionRatio,
    this.errorMessage,
    this.metadata,
  });

  /// 获取压缩率百分比
  double get compressionRatePercent {
    if (compressionRatio != null) {
      return (1 - compressionRatio!) * 100;
    }
    return 0.0;
  }

  /// 获取文件大小减少量
  int get sizeDifference {
    if (originalSize != null && compressedSize != null) {
      return originalSize! - compressedSize!;
    }
    return 0;
  }
}

/// 视频压缩进度回调
typedef VideoCompressProgressCallback = void Function(double progress);

/// 视频压缩和优化工具类
class VideoCompressManager {
  static final VideoCompressManager _instance = VideoCompressManager._internal();
  factory VideoCompressManager() => _instance;
  VideoCompressManager._internal();

  /// 当前压缩任务是否正在进行
  bool _isCompressing = false;

  /// 压缩视频
  Future<VideoCompressResult> compressVideo(
    String inputPath, {
    VideoCompressConfig config = VideoCompressConfig.mediumQuality,
    VideoCompressProgressCallback? onProgress,
    bool deleteOriginal = false,
  }) async {
    if (_isCompressing) {
      return VideoCompressResult(
        success: false,
        errorMessage: '已有压缩任务在进行中',
      );
    }

    _isCompressing = true;

    try {
      // 检查输入文件
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return VideoCompressResult(
          success: false,
          errorMessage: '输入文件不存在',
        );
      }

      // 获取原始文件信息
      final originalSize = await inputFile.length();
      final videoInfo = await VideoCompress.getMediaInfo(inputPath);
      
      iPrint('开始压缩视频: $inputPath');
      iPrint('原始文件大小: ${_formatFileSize(originalSize)}');
      iPrint('原始视频信息: ${videoInfo.toJson()}');

      // 检查是否需要压缩
      if (await _shouldSkipCompression(inputPath, config)) {
        return VideoCompressResult(
          success: true,
          outputPath: inputPath,
          originalSize: originalSize,
          compressedSize: originalSize,
          compressionRatio: 1.0,
        );
      }

      // 设置压缩参数
      final compressQuality = _mapQualityToVideoQuality(config.quality);
      
      // 设置压缩进度监听
      if (onProgress != null) {
        // 注意：VideoCompress的进度监听需要在压缩开始前设置
      }

      // 开始压缩
      final result = await VideoCompress.compressVideo(
        inputPath,
        quality: compressQuality,
        deleteOrigin: deleteOriginal,
        includeAudio: config.enableAudio,
        frameRate: config.targetFrameRate ?? 30,
      );

      if (result == null) {
        return VideoCompressResult(
          success: false,
          errorMessage: '压缩失败，返回结果为空',
        );
      }

      // 获取压缩后的文件信息
      final compressedFile = File(result.path!);
      final compressedSize = await compressedFile.length();
      final compressionRatio = compressedSize / originalSize;

      // 检查压缩后是否符合要求
      if (config.maxFileSize != null && compressedSize > config.maxFileSize!) {
        iPrint('压缩后文件仍然过大，尝试进一步压缩');
        // 可以尝试更低质量的压缩
        return await _furtherCompress(
          result.path!,
          config,
          originalSize,
          onProgress,
        );
      }

      iPrint('压缩完成: ${result.path}');
      iPrint('压缩后文件大小: ${_formatFileSize(compressedSize)}');
      iPrint('压缩率: ${(compressionRatio * 100).toStringAsFixed(1)}%');

      return VideoCompressResult(
        success: true,
        outputPath: result.path,
        originalSize: originalSize,
        compressedSize: compressedSize,
        originalDuration: Duration(milliseconds: videoInfo.duration?.toInt() ?? 0),
        compressedDuration: Duration(milliseconds: result.duration?.toInt() ?? 0),
        compressionRatio: compressionRatio,
        metadata: {
          'originalWidth': videoInfo.width,
          'originalHeight': videoInfo.height,
          'compressedWidth': result.width,
          'compressedHeight': result.height,
          // 'originalBitrate': videoInfo.bitrate, // bitrate属性可能不存在
        },
      );

    } catch (e) {
      iPrint('视频压缩失败: $e');
      return VideoCompressResult(
        success: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isCompressing = false;
    }
  }

  /// 取消压缩
  Future<void> cancelCompression() async {
    if (_isCompressing) {
      await VideoCompress.cancelCompression();
      _isCompressing = false;
    }
  }

  /// 获取视频信息
  Future<MediaInfo?> getVideoInfo(String videoPath) async {
    try {
      return await VideoCompress.getMediaInfo(videoPath);
    } catch (e) {
      iPrint('获取视频信息失败: $e');
      return null;
    }
  }

  /// 检查是否应该跳过压缩
  Future<bool> _shouldSkipCompression(
    String inputPath,
    VideoCompressConfig config,
  ) async {
    try {
      final file = File(inputPath);
      final fileSize = await file.length();
      
      // 如果文件已经很小，跳过压缩
      if (config.maxFileSize != null && fileSize <= config.maxFileSize!) {
        final videoInfo = await VideoCompress.getMediaInfo(inputPath);
        
        // 检查分辨率
        if (config.targetWidth != null && config.targetHeight != null) {
          if (videoInfo.width != null && videoInfo.height != null) {
            if (videoInfo.width! <= config.targetWidth! && 
                videoInfo.height! <= config.targetHeight!) {
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 进一步压缩（当第一次压缩后文件仍然过大时）
  Future<VideoCompressResult> _furtherCompress(
    String inputPath,
    VideoCompressConfig config,
    int originalSize,
    VideoCompressProgressCallback? onProgress,
  ) async {
    try {
      // 使用更激进的压缩参数
      final furtherConfig = VideoCompressConfig(
        quality: VideoCompressQuality.low,
        targetBitrate: max(200, (config.targetBitrate ?? 1000) ~/ 2),
        targetFrameRate: max(15, (config.targetFrameRate ?? 30) ~/ 2),
        targetWidth: config.targetWidth != null ? config.targetWidth! ~/ 2 : 480,
        targetHeight: config.targetHeight != null ? config.targetHeight! ~/ 2 : 360,
        maxFileSize: config.maxFileSize,
        enableAudio: config.enableAudio,
        outputFormat: config.outputFormat,
      );

      return await compressVideo(
        inputPath,
        config: furtherConfig,
        onProgress: onProgress,
        deleteOriginal: true, // 删除中间文件
      );
    } catch (e) {
      return VideoCompressResult(
        success: false,
        errorMessage: '进一步压缩失败: $e',
      );
    }
  }

  /// 生成输出文件路径
  Future<String> _generateOutputPath(
    String inputPath,
    VideoCompressConfig config,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final inputFile = File(inputPath);
    final fileName = inputFile.uri.pathSegments.last;
    final nameWithoutExtension = fileName.split('.').first;
    final extension = config.outputFormat ?? 'mp4';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    return '${tempDir.path}/${nameWithoutExtension}_compressed_$timestamp.$extension';
  }

  /// 映射质量枚举到VideoCompress的质量枚举
  VideoQuality _mapQualityToVideoQuality(VideoCompressQuality quality) {
    switch (quality) {
      case VideoCompressQuality.low:
        return VideoQuality.LowQuality;
      case VideoCompressQuality.medium:
        return VideoQuality.MediumQuality;
      case VideoCompressQuality.high:
        return VideoQuality.HighestQuality;
      case VideoCompressQuality.custom:
        return VideoQuality.MediumQuality;
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 清理临时文件
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (final file in files) {
        if (file is File && file.path.contains('compressed')) {
          // 只删除1小时前的临时压缩文件
          final stat = await file.stat();
          final now = DateTime.now();
          final fileTime = stat.modified;
          
          if (now.difference(fileTime).inHours > 1) {
            await file.delete();
            iPrint('删除临时文件: ${file.path}');
          }
        }
      }
    } catch (e) {
      iPrint('清理临时文件失败: $e');
    }
  }

  /// 优化红米A5等特定设备的视频兼容性
  Future<VideoCompressResult> optimizeForDevice(
    String inputPath, {
    String deviceModel = '',
    VideoCompressProgressCallback? onProgress,
  }) async {
    VideoCompressConfig config;

    // 针对红米A5的特殊优化
    if (deviceModel.toLowerCase().contains('redmi') && 
        deviceModel.toLowerCase().contains('a5')) {
      config = const VideoCompressConfig(
        quality: VideoCompressQuality.low,
        targetBitrate: 300,     // 更低的比特率
        targetFrameRate: 20,    // 更低的帧率
        targetWidth: 480,       // 更小的分辨率
        targetHeight: 360,
        maxFileSize: 5 * 1024 * 1024, // 5MB限制
        enableAudio: true,
        outputFormat: 'mp4',
      );
    } else {
      // 通用优化配置
      config = VideoCompressConfig.mediumQuality;
    }

    return await compressVideo(
      inputPath,
      config: config,
      onProgress: onProgress,
    );
  }
}

/// 视频压缩进度指示器组件
class VideoCompressProgressWidget extends StatefulWidget {
  final String inputPath;
  final VideoCompressConfig config;
  final Function(VideoCompressResult) onComplete;
  final VoidCallback? onCancel;

  const VideoCompressProgressWidget({
    super.key,
    required this.inputPath,
    required this.config,
    required this.onComplete,
    this.onCancel,
  });

  @override
  State<VideoCompressProgressWidget> createState() => _VideoCompressProgressWidgetState();
}

class _VideoCompressProgressWidgetState extends State<VideoCompressProgressWidget> {
  double _progress = 0.0;
  bool _isCompressing = true;
  final VideoCompressManager _compressManager = VideoCompressManager();

  @override
  void initState() {
    super.initState();
    _startCompression();
  }

  /// 开始压缩
  Future<void> _startCompression() async {
    final result = await _compressManager.compressVideo(
      widget.inputPath,
      config: widget.config,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isCompressing = false;
      });
      widget.onComplete(result);
    }
  }

  /// 取消压缩
  Future<void> _cancelCompression() async {
    await _compressManager.cancelCompression();
    if (mounted) {
      setState(() {
        _isCompressing = false;
      });
      widget.onCancel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_settings,
              size: 48,
              color: Colors.blue,
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              '正在压缩视频...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '${(_progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCompressing ? _cancelCompression : null,
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}