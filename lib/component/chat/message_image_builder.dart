/// 单图消息构建器
///
/// 用于展示单张图片消息
/// 支持点击预览大图，并可左右滑动查看会话中的其他图片
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:octo_image/octo_image.dart';
import 'package:shimmer/shimmer.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoView, zoomInPhotoViewGalleryWithInitialPage;

/// 单图消息构建器
class MessageImageBuilder extends StatefulWidget {
  const MessageImageBuilder({
    super.key,
    required this.type,
    required this.message,
    required this.user,
    this.allMessages,
  });

  final String type;
  final CustomMessage message;
  final User user;
  final List<dynamic>? allMessages; // 传入当前会话的所有消息，用于获取图片列表

  @override
  State<MessageImageBuilder> createState() => _MessageImageBuilderState();
}

class _MessageImageBuilderState extends State<MessageImageBuilder> {
  late String _imageUrl;
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    _initImageInfo();
  }

  void _initImageInfo() {
    // 从 metadata 中获取图片信息
    final metadata = widget.message.metadata ?? {};
    _imageUrl = metadata['source'] ?? metadata['uri'] ?? '';

    // 确保 width 和 height 是 double 类型
    final width = metadata['width'];
    final height = metadata['height'];

    _width = width is double ? width : (width is int ? width.toDouble() : 0.0);
    _height = height is double ? height : (height is int ? height.toDouble() : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // 计算合适的显示尺寸
    final double displayWidth = _width > 0 ? _width : 200.0;
    final double displayHeight = _height > 0 ? _height : 200.0;

    // 限制最大宽度，避免图片过大
    final double maxWidth = MediaQuery.of(context).size.width * 0.65;
    final double maxHeight = MediaQuery.of(context).size.height * 0.5;

    double finalWidth = displayWidth;
    double finalHeight = displayHeight;

    // 如果宽度过大，按比例缩放
    if (finalWidth > maxWidth) {
      final scale = maxWidth / finalWidth;
      finalWidth = maxWidth;
      finalHeight = finalHeight * scale;
    }

    // 如果高度过大，按比例缩放
    if (finalHeight > maxHeight) {
      final scale = maxHeight / finalHeight;
      finalHeight = maxHeight;
      finalWidth = finalWidth * scale;
    }

    // 设置最小尺寸
    if (finalWidth < 120) finalWidth = 120;
    if (finalHeight < 120) finalHeight = 120;

    return GestureDetector(
      onTap: _previewImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: finalWidth,
          height: finalHeight,
          child: _buildImageWidget(),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_imageUrl.isEmpty) {
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, size: 48),
      );
    }

    // final thumbHash = metadata['thumbhash'];

    return OctoImage(
      image: cachedImageProvider(_imageUrl),
      fit: BoxFit.cover,
      placeholderBuilder: (context) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          color: Colors.white,
        ),
      ),
      errorBuilder: (context, error, stacktrace) => Container(
        color: Colors.grey[300],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 32),
            SizedBox(height: 8),
            Text('加载失败', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 预览图片，支持左右滑动查看会话中的其他图片
  void _previewImage() {
    if (_imageUrl.isEmpty) return;

    // 获取当前会话中的所有图片消息
    final List<String> allImageUrls = _getAllImageUrlsInConversation();

    if (allImageUrls.isEmpty) {
      // 没有找到图片，不处理
      return;
    }

    if (allImageUrls.length == 1) {
      // 如果只有一张图片，使用单图预览
      _showSingleImagePreview();
    } else {
      // 计算当前图片在所有图片中的索引
      final currentIndex = allImageUrls.indexOf(_imageUrl);

      // 使用多图预览功能，并跳转到当前图片
      if (currentIndex >= 0) {
        zoomInPhotoViewGalleryWithInitialPage(
          context,
          allImageUrls,
          currentIndex,
        );
      } else {
        // 如果找不到当前图片，从第一张开始
        zoomInPhotoViewGalleryWithInitialPage(
          context,
          allImageUrls,
          0,
        );
      }
    }
  }

  /// 获取当前会话中的所有图片 URL
  List<String> _getAllImageUrlsInConversation() {
    try {
      // 从所有消息中筛选出图片消息
      final List<String> imageUrls = [];

      // 如果传入了 allMessages，直接使用
      if (widget.allMessages != null) {
        for (final msg in widget.allMessages!) {
          if (msg is CustomMessage) {
            final metadata = msg.metadata ?? {};
            final effectiveMsgType = metadata['effective_msg_type'] ??
                metadata['msg_type'] ??
                '';

            // 单图消息
            if (effectiveMsgType == 'image') {
              final uri = metadata['source'] ?? metadata['uri'] ?? '';
              if (uri.isNotEmpty) {
                imageUrls.add(uri);
              }
            }
            // 多图消息
            else if (effectiveMsgType == 'imageMulti') {
              final images = metadata['images'] as List<dynamic>?;
              if (images != null) {
                for (final img in images) {
                  final uri = img['uri'] ?? '';
                  if (uri.isNotEmpty) {
                    imageUrls.add(uri);
                  }
                }
              }
            }
          }
        }
      }

      return imageUrls;
    } catch (e) {
      iPrint('获取会话图片列表失败: $e');
      return [];
    }
  }

  /// 显示单图预览（降级方案）
  void _showSingleImagePreview() {
    zoomInPhotoView(context, _imageUrl);
  }
}
