import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart' show currentFontSize;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_size_page.g.dart';

/// FontSize 模块的状态
class FontSizeState {
  final FontSizeOption currentOption;
  final FontSizeOption previewOption;
  final double sliderValue;

  const FontSizeState({
    required this.currentOption,
    required this.previewOption,
    required this.sliderValue,
  });

  FontSizeState copyWith({
    FontSizeOption? currentOption,
    FontSizeOption? previewOption,
    double? sliderValue,
  }) {
    return FontSizeState(
      currentOption: currentOption ?? this.currentOption,
      previewOption: previewOption ?? this.previewOption,
      sliderValue: sliderValue ?? this.sliderValue,
    );
  }
}

@riverpod
class FontSizeNotifier extends _$FontSizeNotifier {
  @override
  FontSizeState build() {
    final themeState = ref.watch(themeProvider);
    final options = FontSizeOption.values;

    return FontSizeState(
      currentOption: themeState.fontSizeOption,
      previewOption: themeState.fontSizeOption,
      sliderValue: options.indexOf(themeState.fontSizeOption).toDouble(),
    );
  }

  /// 更新预览选项（拖动滑块时）
  void updatePreview(double value) {
    final options = FontSizeOption.values;
    final index = value.round().clamp(0, options.length - 1);
    final previewOption = options[index];

    state = state.copyWith(sliderValue: value, previewOption: previewOption);
  }

  /// 应用字体大小更改
  Future<void> applyFontSize(double value) async {
    final options = FontSizeOption.values;
    final index = value.round().clamp(0, options.length - 1);
    final option = options[index];

    try {
      // 使用 themeProvider 更新字体大小
      await ref.read(themeProvider.notifier).updateFontSizeOption(option);

      // 更新全局变量（兼容旧代码）
      currentFontSize.value = option.value;

      // 更新状态
      state = state.copyWith(
        currentOption: option,
        previewOption: option,
        sliderValue: index.toDouble(),
      );

      return;
    } on Exception {
      rethrow;
    }
  }

  /// 获取预览文本样式
  TextStyle getPreviewTextStyle(
    BuildContext context,
    FontSizeType type, {
    Color? color,
  }) {
    final themeNotifier = ref.read(themeProvider.notifier);
    return themeNotifier.getTextStyle(
      type,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// 检查预览字体是否可访问
  bool get isPreviewAccessible {
    final themeNotifier = ref.read(themeProvider.notifier);
    return themeNotifier.isCurrentFontSizeAccessible;
  }
}

class FontSizePage extends ConsumerWidget {
  const FontSizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final state = ref.watch(fontSizeProvider);
    final notifier = ref.read(fontSizeProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final cardColor = Theme.of(context).cardColor;
    final iosBlue = AppColors.getIosBlue(brightness);
    final options = FontSizeOption.values;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: GlassAppBar(
        title: t.fontSizeSetting,
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          // 预览区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.previewEffect,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.thisIsTitleText,
                          style: notifier
                              .getPreviewTextStyle(context, FontSizeType.large)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.fontPreviewText,
                          style: notifier.getPreviewTextStyle(
                            context,
                            FontSizeType.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.thisIsAuxiliaryText,
                          style: notifier.getPreviewTextStyle(
                            context,
                            FontSizeType.small,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewFooter(context, ref),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 可读性提示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        notifier.isPreviewAccessible
                            ? t.goodReadability
                            : t.fontTooSmallMayAffect,
                        style: TextStyle(
                          fontSize: 12,
                          color: notifier.isPreviewAccessible
                              ? cs.primary
                              : cs.error,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 底部控制区
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.iosSeparator.withValues(alpha: 0.6),
                  width: 0.33,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.dragSliderAdjustFontSize,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontFamily: 'PingFang SC',
                  ),
                ),
                const SizedBox(height: 20),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: iosBlue,
                    inactiveTrackColor:
                        AppColors.iosGray4.withValues(alpha: 0.6),
                    thumbColor: Colors.white,
                    overlayColor: iosBlue.withValues(alpha: 0.2),
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24.0,
                    ),
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 4.0,
                    ),
                    activeTickMarkColor: Colors.white,
                    inactiveTickMarkColor: cs.outline.withValues(alpha: 0.4),
                  ),
                  child: Slider(
                    min: 0,
                    max: (options.length - 1).toDouble(),
                    divisions: options.length - 1,
                    value: state.sliderValue,
                    label:
                        '${state.previewOption.displayName} ${(state.previewOption.scale * 100).toInt()}%',
                    onChanged: (value) {
                      // 更新预览
                      ref.read(fontSizeProvider.notifier).updatePreview(value);
                    },
                    onChangeEnd: (value) async {
                      // 应用更改
                      try {
                        await ref
                            .read(fontSizeProvider.notifier)
                            .applyFontSize(value);
                        if (context.mounted) {
                          EasyLoading.showSuccess(t.fontSizeSettingUpdated);
                        }
                      } on Exception {
                        if (context.mounted) {
                          EasyLoading.showError(t.settingFailedPleaseTryAgain);
                        }
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.smaller,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                      Text(
                        t.larger,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建预览页脚（模拟微信风格）
  Widget _buildPreviewFooter(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final state = ref.watch(fontSizeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          t.currentFontScale(
            param1: state.previewOption.displayName,
            param2: ((state.previewOption.scale * 100).toInt()).toString(),
          ),
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.6),
            fontFamily: 'PingFang SC',
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            t.recommended,
            style: TextStyle(
              fontSize: 12,
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      ],
    );
  }
}
