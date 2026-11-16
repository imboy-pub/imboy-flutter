import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/init.dart' show currentFontSize;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/account_local_task_registry.dart';
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

    final repo = UserRepoLocal.to;
    final session = authSessionReader.current;
    final owner = AccountLocalTaskOwner.capture(uid: session.uid);
    bool current() =>
        ref.mounted &&
        authSessionReader.isCurrent(session) &&
        AccountLocalTaskOwner.capture(uid: session.uid) == owner;
    try {
      if (!current()) throw StateError('Font preference owner changed');
      await ref
          .read(themeProvider.notifier)
          .updateFontSizeOption(
            option,
            isCurrent: current,
            saveAccountFont: () {
              if (!current()) return Future<bool>.value(false);
              // Preserve settings committed while the device write was pending.
              final setting = UserSettingModel.fromJson(repo.setting.toMap())
                ..fontSize = option.value;
              return repo.changeSettingForSession(
                setting,
                uid: session.uid,
                generation: session.generation,
              );
            },
          );
      if (!current()) throw StateError('Font preference owner changed');
      currentFontSize.value = option.value;
      state = state.copyWith(
        currentOption: option,
        previewOption: option,
        sliderValue: index.toDouble(),
      );
    } on Object {
      if (ref.mounted) {
        final actual = ref.read(themeProvider).fontSizeOption;
        state = state.copyWith(
          currentOption: actual,
          previewOption: actual,
          sliderValue: options.indexOf(actual).toDouble(),
        );
      }
      rethrow;
    }
  }

  TextStyle getPreviewTextStyle(
    BuildContext context,
    FontSizeType type, {
    Color? color,
  }) {
    final themeNotifier = ref.read(themeProvider.notifier);
    return themeNotifier
        .getTextStyle(
          type,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        )
        .copyWith(
          fontSize: FontScaleCalculator.calculateFinalSize(
            type,
            state.previewOption,
          ),
        );
  }

  bool get isPreviewAccessible {
    return FontScaleCalculator.isAccessibleSize(
      FontScaleCalculator.calculateFinalSize(
        FontSizeType.normal,
        state.previewOption,
      ),
    );
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
              style: context
                  .textStyle(
                    FontSizeType.footnote,
                    fontWeight: FontWeight.w400,
                    color: AppColors.iosGray,
                  )
                  .copyWith(letterSpacing: -0.08),
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
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                notifier.isPreviewAccessible
                    ? t.chat.goodReadability
                    : t.common.fontTooSmallMayAffect,
                textAlign: TextAlign.end,
                style: context.textStyle(
                  FontSizeType.small,
                  color: notifier.isPreviewAccessible
                      ? AppColors.iosBlue
                      : AppColors.iosRed,
                ),
              ),
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
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
          AppSpacing.verticalRegular,
          Semantics(
            // DEF-A11YNEW-03：字号滑块此前在 web 语义树中完全不可见、键盘
            // 不可达（引擎把 role=slider 渲染在内层 <input type=range> 上，
            // 外层语义节点无 role/无 label/无 tabindex；Tab 走查仅「返回」
            // 可达，六档 0.9-1.4 全部键盘不可达）。
            // 这里在滑块外显式声明完整语义：container 节点带当前档位
            // label/value 与 increase/decrease 动作，引擎据此渲染语义滑块
            // （<input type=range role=slider> + tabindex=0），Tab 可达、
            // 读屏播报当前档位（aria-label=当前档位描述）、上下键逐步调档，
            // 与拖动滑块走同一条 updatePreview→applyFontSize 数据链路。
            // ExcludeSemantics 隐藏内层 Slider 的原生语义避免双节点；
            // Semantics/ExcludeSemantics 不参与绘制，视觉零变化。
            container: true,
            label: t.common.currentFontScale(
              param1: state.previewOption.localizedName,
              param2: ((state.previewOption.scale * 100).toInt()).toString(),
            ),
            value: state.previewOption.localizedName,
            increasedValue:
                options[(state.sliderValue.round() + 1).clamp(
                      0,
                      options.length - 1,
                    )]
                    .localizedName,
            decreasedValue:
                options[(state.sliderValue.round() - 1).clamp(
                      0,
                      options.length - 1,
                    )]
                    .localizedName,
            onIncrease: () => _applySliderStep(ref, t, 1),
            onDecrease: () => _applySliderStep(ref, t, -1),
            child: ExcludeSemantics(
              child: SliderTheme(
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
                  semanticFormatterCallback: (value) =>
                      options[value.round().clamp(0, options.length - 1)]
                          .localizedName,
                  onChanged: (value) =>
                      ref.read(fontSizeProvider.notifier).updatePreview(value),
                  onChangeEnd: (value) async {
                    try {
                      await ref
                          .read(fontSizeProvider.notifier)
                          .applyFontSize(value);
                      AppLoading.showSuccess(t.common.fontSizeSettingUpdated);
                    } catch (e) {
                      iPrint('[FontSize] 应用字号失败: $e');
                      AppLoading.showError(
                        t.common.settingFailedPleaseTryAgain,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.common.smaller,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.iosGray,
                  ),
                ),
                Text(
                  t.main.larger,
                  style: context.textStyle(
                    FontSizeType.body,
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

  /// 语义 increase/decrease 动作的档位步进（DEF-A11YNEW-03）。
  ///
  /// 每次读取最新 state（快速连按不会基于过期快照计算），先 updatePreview
  /// 即时刷新预览，再 applyFontSize 持久化——与拖动滑块（onChanged→
  /// onChangeEnd）走同一条数据链路，含 themeProvider/UserRepoLocal 双数据源
  /// 同步与失败回滚。结果提示与鼠标路径一致（成功/失败 toast）。
  void _applySliderStep(WidgetRef ref, Translations t, int delta) {
    final notifier = ref.read(fontSizeProvider.notifier);
    final current = ref.read(fontSizeProvider);
    final index = (current.sliderValue.round() + delta).clamp(
      0,
      FontSizeOption.values.length - 1,
    );
    final value = index.toDouble();
    notifier.updatePreview(value);
    () async {
      try {
        await notifier.applyFontSize(value);
        AppLoading.showSuccess(t.common.fontSizeSettingUpdated);
      } catch (e) {
        iPrint('[FontSize] 语义步进应用字号失败: $e');
        AppLoading.showError(t.common.settingFailedPleaseTryAgain);
      }
    }();
  }

  Widget _buildPreviewFooter(
    BuildContext context,
    WidgetRef ref,
    FontSizeState state,
    ColorScheme cs,
    Translations t,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: [
        Text(
          t.common.currentFontScale(
            param1: state.previewOption.localizedName,
            param2: ((state.previewOption.scale * 100).toInt()).toString(),
          ),
          style: context.textStyle(
            FontSizeType.small,
            color: AppColors.iosGray,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.getIosBlue(Theme.of(context).brightness)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            t.main.recommended,
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.getIosBlue(Theme.of(context).brightness),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
