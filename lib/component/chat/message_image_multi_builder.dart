import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:octo_image/octo_image.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoViewGalleryWithInitialPage;
import 'package:imboy/component/ui/shimmer_box.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 一条多图消息最多显示的格子数，超出部分折叠成 "+N"
const int _kMaxVisibleTiles = 9;

/// 多图消息构建器
///
/// 微信/QQ 式九宫格：1 张独占，2/4 张走 2 列，其余 3 列。
/// 每个格子是正方形裁切（`BoxFit.cover`），尺寸由网格算，不由图片原始宽高算——
/// 旧实现给每张图写死 100px 再塞进约 75px 的格子，横竖图还各自算出更小的高度，
/// 于是格子里图片忽大忽小、边缘被裁掉。
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
      (widget.message.metadata?['images'] ?? <Map<String, dynamic>>[])
          as Iterable,
    );
  }

  /// 列数：1 张独占一列，2/4 张两列（4 张走 2×2 而非 3+1），其余三列
  int get _crossAxisCount {
    if (images.length == 1) return 1;
    if (images.length == 2 || images.length == 4) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = images.length > _kMaxVisibleTiles
        ? images.sublist(0, _kMaxVisibleTiles)
        : images;
    final hiddenCount = images.length - visible.length;
    final crossAxisCount = _crossAxisCount;

    // 单图不走网格：按原始宽高比展示，避免正方形裁切丢信息
    if (images.length == 1) {
      return _SingleTile(
        uri: parseModelString(images.first['uri']),
        width: (images.first['width'] as num? ?? 0).toDouble(),
        height: (images.first['height'] as num? ?? 0).toDouble(),
        onTap: () => _previewImage(0),
      );
    }

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
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final uri = parseModelString(visible[index]['uri']);
          final isLastVisible = index == visible.length - 1;
          return GestureDetector(
            onTap: () => _previewImage(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                MessageSpacing.imageBorderRadius,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _GridTile(uri: uri),
                  // 折叠角标：第 9 格盖一层 "+N"，点进去仍是全量预览
                  if (hiddenCount > 0 && isLastVisible)
                    Container(
                      color: AppColors.mediaScrimBlack.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Text(
                        '+$hiddenCount',
                        style: context.textStyle(
                          FontSizeType.large,
                          color: AppColors.mediaScrimWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _previewImage(int index) {
    // 提取所有图片URL用于预览（含被 "+N" 折叠的部分）
    final List<String> imageUrls = images
        .map<String>((img) => (img['uri'] ?? '') as String)
        .where((uri) => uri.isNotEmpty)
        .toList();

    if (imageUrls.isEmpty || !mounted) return;

    final initial = index.clamp(0, imageUrls.length - 1);
    zoomInPhotoViewGalleryWithInitialPage(context, imageUrls, initial);
  }
}

/// 网格格子：尺寸完全由父级 GridView 决定，内部只负责填满
class _GridTile extends StatelessWidget {
  const _GridTile({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    if (uri.isEmpty) return const _TilePlaceholder(icon: Icons.broken_image);

    return OctoImage(
      image: cachedImageProvider(uri),
      fit: BoxFit.cover,
      placeholderBuilder: (context) => ShimmerBox(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(color: AppColors.shimmerBase),
      ),
      errorBuilder: (context, error, stacktrace) =>
          const _TilePlaceholder(icon: Icons.broken_image),
    );
  }
}

/// 单图：按原始宽高比展示，上限与单图消息一致
class _SingleTile extends StatelessWidget {
  const _SingleTile({
    required this.uri,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String uri;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.618;
    final ratio = (width > 0 && height > 0) ? width / height : 1.0;
    final displayWidth = maxWidth;
    final displayHeight = (displayWidth / ratio).clamp(80.0, maxWidth * 1.6);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MessageSpacing.imageBorderRadius),
        child: SizedBox(
          width: displayWidth,
          height: displayHeight,
          child: _GridTile(uri: uri),
        ),
      ),
    );
  }
}

class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark
          ? AppColors.placeholderSurfaceDark
          : AppColors.placeholderSurfaceLight,
      child: Icon(
        icon,
        color: isDark
            ? AppColors.mediaScrimWhite.withValues(alpha: 0.3)
            : AppColors.mediaScrimBlack.withValues(alpha: 0.26),
      ),
    );
  }
}
