import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/init.dart' show currentFontSize;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';
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
      await ref.read(themeProvider.notifier).updateFontSizeOption(option);
      currentFontSize.value = option.value;
      state = state.copyWith(
        currentOption: option,
        previewOption: option,
        sliderValue: index.toDouble(),
      );
    } on Exception {
      rethrow;
    }
  }

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

  bool get isPreviewAccessible {
    final themeNotifier = ref.read(themeProvider.notifier);
    return themeNotifier.isCurrentFontSizeAccessible;
  }
}

/// 字体大小设置页面 - 像素级对齐 iOS 设置风
class FontSizePage extends ConsumerWidget {
  const FontSizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final state = ref.watch(fontSizeProvider);
    final notifier = ref.read(fontSizeProvider.notifier);
    final cardColor = Theme.of(context).cardColor;
    final options = FontSizeOption.values;

    return IosPageTemplate(
      title: t.common.fontSizeSetting,
      useLargeTitle: false,
      bottomWidget: _buildBottomControl(context, ref, state, options, cs, t),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.main.previewEffect.toUpperCase(),
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
                fontWeight: FontWeight.w400,
                color: AppColors.iosGray,
                letterSpacing: -0.08,
              ),
            ),
            AppSpacing.verticalMedium,
            Container(
              padding: const EdgeInsets.all(AppSpacing.large),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: AppRadius.borderRadiusCell,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.main.thisIsTitleText,
                    style: notifier
                        .getPreviewTextStyle(context, FontSizeType.large)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  AppSpacing.verticalMedium,
                  Text(
                    t.common.fontPreviewText,
                    style: notifier.getPreviewTextStyle(
                      context,
                      FontSizeType.normal,
                    ),
                  ),
                  AppSpacing.verticalSmall,
                  Text(
                    t.main.thisIsAuxiliaryText,
                    style: notifier.getPreviewTextStyle(
                      context,
                      FontSizeType.small,
                    ),
                  ),
                  AppSpacing.verticalMedium,
                  _buildPreviewFooter(context, ref, state, cs, t),
                ],
              ),
            ),
            AppSpacing.verticalRegular,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  notifier.isPreviewAccessible
                      ? t.chat.goodReadability
                      : t.common.fontTooSmallMayAffect,
                  style: TextStyle(
                    fontSize: FontSizeType.small.size,
                    color: notifier.isPreviewAccessible
                        ? AppColors.iosBlue
                        : AppColors.iosRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControl(
    BuildContext context,
    WidgetRef ref,
    FontSizeState state,
    List<FontSizeOption> options,
    ColorScheme cs,
    Translations t,
  ) {
    final iosBlue = AppColors.getIosBlue(Theme.of(context).brightness);
    final cardColor = Theme.of(context).cardColor;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: AppColors.getIosSeparator(Theme.of(context).brightness),
            width: 0.33,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.common.dragSliderAdjustFontSize,
            style: TextStyle(
              fontSize: FontSizeType.footnote.size,
              color: AppColors.iosGray,
            ),
          ),
          AppSpacing.verticalRegular,
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: iosBlue,
              inactiveTrackColor: AppColors.iosGray5.withValues(alpha: 0.6),
              thumbColor: AppColors.onPrimary,
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 14.0,
                elevation: 3,
              ),
              tickMarkShape: const RoundSliderTickMarkShape(
                tickMarkRadius: 3.5,
              ),
              activeTickMarkColor: AppColors.onPrimary,
              inactiveTickMarkColor: AppColors.iosGray4,
            ),
            child: Slider(
              min: 0,
              max: (options.length - 1).toDouble(),
              divisions: options.length - 1,
              value: state.sliderValue,
              onChanged: (value) =>
                  ref.read(fontSizeProvider.notifier).updatePreview(value),
              onChangeEnd: (value) async {
                try {
                  await ref
                      .read(fontSizeProvider.notifier)
                      .applyFontSize(value);
                  EasyLoading.showSuccess(t.common.fontSizeSettingUpdated);
                } catch (e) {
                  EasyLoading.showError(t.common.settingFailedPleaseTryAgain);
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
                  t.common.smaller,
                  style: TextStyle(
                    fontSize: FontSizeType.footnote.size,
                    color: AppColors.iosGray,
                  ),
                ),
                Text(
                  t.main.larger,
                  style: TextStyle(
                    fontSize: FontSizeType.body.size,
                    color: AppColors.iosGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewFooter(
    BuildContext context,
    WidgetRef ref,
    FontSizeState state,
    ColorScheme cs,
    Translations t,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          t.common.currentFontScale(
            param1: state.previewOption.displayName,
            param2: ((state.previewOption.scale * 100).toInt()).toString(),
          ),
          style: TextStyle(
            fontSize: FontSizeType.small.size,
            color: AppColors.iosGray,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.getIosBlue(
              Theme.of(context).brightness,
            ).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            t.main.recommended,
            style: TextStyle(
              fontSize: FontSizeType.small.size,
              color: AppColors.getIosBlue(Theme.of(context).brightness),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
