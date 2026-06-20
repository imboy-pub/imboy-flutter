import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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

  static List<StickerItem> _buildStickers() {
    return [
      const StickerItem(url: '', text: '😊'),
      const StickerItem(url: '', text: '😆'),
      const StickerItem(url: '', text: '😭'),
      const StickerItem(url: '', text: '😡'),
      const StickerItem(url: '', text: '❤️'),
      const StickerItem(url: '', text: '👍'),
      const StickerItem(url: '', text: '🎉'),
      const StickerItem(url: '', text: '🔥'),
      const StickerItem(url: '', text: '🤔'),
      const StickerItem(url: '', text: '👏'),
      const StickerItem(url: '', text: '😂'),
      const StickerItem(url: '', text: '😎'),
      const StickerItem(url: '', text: '👀'),
      const StickerItem(url: '', text: '✨'),
      const StickerItem(url: '', text: '🙏'),
      const StickerItem(url: '', text: '😱'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stickers = _buildStickers();

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
            margin: const EdgeInsets.only(
              top: AppSpacing.medium,
              bottom: AppSpacing.small,
            ),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: AppRadius.borderRadiusTiny,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.regular),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: stickers.length,
              itemBuilder: (context, index) {
                final sticker = stickers[index];
                return GestureDetector(
                  onTap: () => onStickerSelected(sticker),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.tiny),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceGrouped
                          : AppColors.lightSurfaceGrouped,
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                    child: Center(
                      child: Text(
                        sticker.text,
                        style: const TextStyle(
                          fontSize: AppSizes.iconSizeLarge,
                        ),
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
