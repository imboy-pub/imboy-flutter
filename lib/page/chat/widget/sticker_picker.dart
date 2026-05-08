import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 贴图/表情包项
class StickerItem {
  final String url;
  final String text;

  const StickerItem({required this.url, required this.text});
}

/// 简单的贴图选择面板
class StickerPicker extends StatelessWidget {
  const StickerPicker({super.key, required this.onStickerSelected});

  final void Function(StickerItem sticker) onStickerSelected;

  // 模拟一组内置贴图（实际应用中通常从服务器拉取或有更完善的管理）
  static const List<StickerItem> _defaultStickers = [
    StickerItem(
      url: 'http://a.imboy.pub/sticker/default/smile.png',
      text: '[微笑]',
    ),
    StickerItem(
      url: 'http://a.imboy.pub/sticker/default/laugh.png',
      text: '[大笑]',
    ),
    StickerItem(
      url: 'http://a.imboy.pub/sticker/default/cry.png',
      text: '[哭泣]',
    ),
    StickerItem(
      url: 'http://a.imboy.pub/sticker/default/angry.png',
      text: '[生气]',
    ),
    StickerItem(
      url: 'http://a.imboy.pub/sticker/default/heart.png',
      text: '[爱心]',
    ),
    StickerItem(
      url: 'http://a.imboy.pub/sticker/default/thumb.png',
      text: '[点赞]',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部指示器
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: AppRadius.borderRadiusTiny,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: _defaultStickers.length,
              itemBuilder: (context, index) {
                final sticker = _defaultStickers[index];
                return GestureDetector(
                  onTap: () => onStickerSelected(sticker),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceGrouped
                          : AppColors.lightSurfaceGrouped,
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.insert_emoticon,
                            size: 32,
                          ), // 占位符，实际应使用 Image
                          const SizedBox(height: 4),
                          Text(
                            sticker.text,
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
