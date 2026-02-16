/// Web 平台文件拖拽上传组件
///
/// 提供拖拽上传功能，类似 WhatsApp Web 的文件发送
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// 拖拽状态
enum DropState {
  /// 未拖拽
  idle,
  /// 拖拽进入
  dragging,
  /// 拖拽离开
  left,
  /// 正在处理
  processing,
}

/// 拖拽文件信息
class DroppedFile {
  /// 文件名
  final String name;

  /// 文件大小（字节）
  final int size;

  /// MIME 类型
  final String? mimeType;

  /// 文件数据
  final Uint8List? bytes;

  /// 文件扩展名
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// 是否是图片
  bool get isImage {
    final ext = extension;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext);
  }

  /// 是否是视频
  bool get isVideo {
    final ext = extension;
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'].contains(ext);
  }

  /// 是否是音频
  bool get isAudio {
    final ext = extension;
    return ['mp3', 'wav', 'ogg', 'aac', 'flac', 'm4a'].contains(ext);
  }

  /// 是否是文档
  bool get isDocument {
    final ext = extension;
    return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt']
        .contains(ext);
  }

  /// 格式化文件大小
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  const DroppedFile({
    required this.name,
    required this.size,
    this.mimeType,
    this.bytes,
  });
}

/// 拖拽区域回调
typedef DropCallback = void Function(List<DroppedFile> files);

/// 文件拖拽区域组件
///
/// 用法：
/// ```dart
/// DropZone(
///   onDrop: (files) {
///     print('收到 ${files.length} 个文件');
///   },
///   child: YourWidget(),
/// )
/// ```
class DropZone extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 拖拽回调
  final DropCallback? onDrop;

  /// 是否允许拖拽多个文件
  final bool allowMultiple;

  /// 允许的文件扩展名（为空则允许所有）
  final List<String>? allowedExtensions;

  /// 允许的 MIME 类型
  final List<String>? allowedMimeTypes;

  /// 最大文件大小（字节）
  final int? maxFileSize;

  /// 最大文件数量
  final int? maxFiles;

  /// 拖拽进入时的提示文本
  final String? hintText;

  /// 拖拽时的装饰
  final BoxDecoration? draggingDecoration;

  const DropZone({
    super.key,
    required this.child,
    this.onDrop,
    this.allowMultiple = true,
    this.allowedExtensions,
    this.allowedMimeTypes,
    this.maxFileSize,
    this.maxFiles,
    this.hintText,
    this.draggingDecoration,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  final DropState _state = DropState.idle;
  String? _error;

  @override
  Widget build(BuildContext context) {
    // 非 Web 平台直接返回子组件
    if (!kIsWeb) {
      return widget.child;
    }

    return Stack(
      children: [
        // 原始子组件
        widget.child,

        // 拖拽遮罩层
        if (_state == DropState.dragging) _buildDraggingOverlay(),
      ],
    );
  }

  Widget _buildDraggingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: widget.draggingDecoration ??
            BoxDecoration(
              color: const Color(0xFF00A884).withAlpha(25),
              border: Border.all(
                color: const Color(0xFF00A884),
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_upload,
                size: 64,
                color: Color(0xFF00A884),
              ),
              const SizedBox(height: 16),
              Text(
                widget.hintText ?? '释放以上传文件',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00A884),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 验证文件
  /// TODO: 集成到文件拖放流程中
  // ignore: unused_element
  bool _validateFiles(List<DroppedFile> files) {
    _error = null;

    // 检查文件数量
    if (widget.maxFiles != null && files.length > widget.maxFiles!) {
      _error = '最多只能上传 ${widget.maxFiles} 个文件';
      return false;
    }

    for (final file in files) {
      // 检查文件大小
      if (widget.maxFileSize != null && file.size > widget.maxFileSize!) {
        _error = '文件 ${file.name} 超过大小限制';
        return false;
      }

      // 检查扩展名
      if (widget.allowedExtensions != null &&
          widget.allowedExtensions!.isNotEmpty) {
        if (!widget.allowedExtensions!.contains(file.extension)) {
          _error = '不支持的文件类型: ${file.extension}';
          return false;
        }
      }
    }

    return true;
  }
}

/// 文件选择按钮（Web 平台）
///
/// 在 Web 平台提供文件选择功能，替代移动端的文件选择器
class WebFilePicker extends StatelessWidget {
  /// 选择回调
  final void Function(List<DroppedFile> files)? onSelected;

  /// 是否允许多选
  final bool allowMultiple;

  /// 允许的文件类型
  final String? accept;

  /// 按钮文本
  final String? buttonText;

  /// 按钮图标
  final IconData? buttonIcon;

  const WebFilePicker({
    super.key,
    this.onSelected,
    this.allowMultiple = true,
    this.accept,
    this.buttonText,
    this.buttonIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      onPressed: () => _pickFiles(),
      icon: Icon(buttonIcon ?? Icons.attach_file),
      label: Text(buttonText ?? '选择文件'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00A884),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _pickFiles() {
    // Web 平台文件选择
    // 实际实现需要通过 JS 互操作
    debugPrint('WebFilePicker: 选择文件');
  }
}

/// 文件预览组件
class FilePreview extends StatelessWidget {
  final DroppedFile file;
  final VoidCallback? onRemove;
  final VoidCallback? onSend;

  const FilePreview({
    super.key,
    required this.file,
    this.onRemove,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF222E35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 文件图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getFileColor().withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(),
              color: _getFileColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // 文件信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  file.formattedSize,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 操作按钮
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: onRemove,
            ),
          if (onSend != null)
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF00A884)),
              onPressed: onSend,
            ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    if (file.isImage) return Icons.image;
    if (file.isVideo) return Icons.videocam;
    if (file.isAudio) return Icons.audiotrack;
    if (file.isDocument) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor() {
    if (file.isImage) return Colors.green;
    if (file.isVideo) return Colors.red;
    if (file.isAudio) return Colors.purple;
    if (file.isDocument) return Colors.blue;
    return Colors.grey;
  }
}

void debugPrint(String message) {
  print(message);
}
