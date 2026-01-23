import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:octo_image/octo_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoViewGallery;

/// 多图消息构建器
///
/// 用于展示一次发送的多张图片（最多9张）
/// 使用 3x3 网格布局，点击可预览大图
class ImageMultiMessageBuilder extends StatefulWidget {
  const ImageMultiMessageBuilder({
    super.key,
    required this.type,
    required this.message,
    required this.user,
  });

  final String type; // C2C C2G
  final CustomMessage message;
  final User user;

  @override
  State<ImageMultiMessageBuilder> createState() =>
      _ImageMultiMessageBuilderState();
}

class _ImageMultiMessageBuilderState extends State<ImageMultiMessageBuilder> {
  late List<Map<String, dynamic>> images;

  @override
  void initState() {
    super.initState();
    // 从 metadata 中获取图片数组
    images = List<Map<String, dynamic>>.from(
      widget.message.metadata?['images'] ?? [],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    // 根据图片数量决定网格列数
    int crossAxisCount = images.length == 1 ? 1 : (images.length == 2 ? 2 : 3);

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.618,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final img = images[index];
          final uri = img['uri'] ?? '';
          final width = (img['width'] ?? 0).toDouble();
          final height = (img['height'] ?? 0).toDouble();

          return GestureDetector(
            onTap: () => _previewImage(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageWidget(uri, width, height),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageWidget(String uri, double width, double height) {
    if (uri.isEmpty) {
      return Container(
        width: 100,
        height: 100,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image),
      );
    }

    // 计算合适的显示尺寸
    final displayWidth = width > 0 ? width : 100;
    final displayHeight = height > 0 ? height : 100;
    final aspectRatio = displayWidth / displayHeight;

    return OctoImage(
      image: cachedImageProvider(uri),
      width: 100,
      height: aspectRatio > 1 ? 100 / aspectRatio : 100 * aspectRatio,
      fit: BoxFit.cover,
      placeholderBuilder: (context) => Container(
        width: 100,
        height: 100,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorBuilder: (context, error, stacktrace) => Container(
        width: 100,
        height: 100,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image),
      ),
    );
  }

  void _previewImage(int index) {
    // 提取所有图片URL用于预览
    final List<String> imageUrls = images
        .map<String>((img) => img['uri'] ?? '')
        .where((uri) => uri.isNotEmpty)
        .toList();

    if (imageUrls.isEmpty || !mounted) return;

    // 使用 zoomInPhotoViewGallery 预览多图
    zoomInPhotoViewGallery(context, imageUrls);
  }
}
