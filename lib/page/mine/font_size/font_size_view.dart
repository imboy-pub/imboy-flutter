import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart' show currentFontSize;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';

class FontSizePage extends StatefulWidget {
  const FontSizePage({super.key});

  @override
  State<FontSizePage> createState() => _FontSizePageState();
}

class _FontSizePageState extends State<FontSizePage> {
  final List<FontSizeOption> fontSizeOptions = FontSizeOption.values;

  late FontSizeOption _currentOption;
  late FontSizeOption _previewOption;
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _currentOption = ThemeManager.instance.fontSizeOption;
    _previewOption = _currentOption;
    _sliderValue = fontSizeOptions.indexOf(_currentOption).toDouble();
  }

  Future<void> _changeFontSize(FontSizeOption option) async {
    try {
      await ThemeManager.instance.updateFontSizeOption(option);

      final setting = UserRepoLocal.to.setting;
      setting.fontSize = option.name;
      await UserRepoLocal.to.changeSetting(setting);

      currentFontSize.value = option.name;

      _currentOption = option;
      _previewOption = option;
      _sliderValue = fontSizeOptions.indexOf(option).toDouble();

      setState(() {});
      EasyLoading.showSuccess('字体大小设置已更新');
    } catch (e, s) {
      EasyLoading.showError('设置失败，请重试');
      iPrint("_changeFontSize $e, $s");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('字体大小设置')),
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预览效果',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '这是标题文本',
                      style: _getPreviewTextStyle(
                        context,
                        FontSizeType.title,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '这是正文内容，您可以在这里看到不同字体大小的显示效果。',
                      style: _getPreviewTextStyle(
                        context,
                        FontSizeType.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '这是辅助说明文字',
                      style: _getPreviewTextStyle(
                        context,
                        FontSizeType.small,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPreviewFooter(context),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拖动滑块调整字体大小',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontFamily: 'PingFang SC',
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  min: 0,
                  max: (fontSizeOptions.length - 1).toDouble(),
                  divisions: fontSizeOptions.length - 1,
                  value: _sliderValue,
                  label:
                      '${_previewOption.displayName} ${(_previewOption.scale * 100).toInt()}%',
                  onChanged: (value) {
                    setState(() {
                      _sliderValue = value;
                      _previewOption = fontSizeOptions[value.round()];
                    });
                  },
                  onChangeEnd: (value) {
                    final option = fontSizeOptions[value.round()];
                    _changeFontSize(option);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '更小',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.6),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                    Text(
                      '更大',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.6),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: fontSizeOptions.length,
              itemBuilder: (context, index) {
                final option = fontSizeOptions[index];
                return Obx(() {
                  final isSelected =
                      ThemeManager.instance.fontSizeOption == option;
                  final recommended =
                      ThemeManager.instance.getRecommendedFontSize(context);
                  final previewInfo = ThemeManager.instance.previewFontSize(
                    option,
                    context: context,
                  );
                  final scaledSize = previewInfo['scaledSize'] as double;
                  final isAccessible = previewInfo['isAccessible'] as bool;
                  final percent = (option.scale * 100).toInt();
                  final subtitleColor = isAccessible
                      ? colorScheme.onSurface.withValues(alpha: 0.6)
                      : colorScheme.error;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        option.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                      subtitle: Text(
                        '正文约 ${scaledSize.toStringAsFixed(1)}sp · $percent%',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (option == recommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '推荐',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.primary,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.check,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => _changeFontSize(option),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : colorScheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _getPreviewTextStyle(BuildContext context, FontSizeType type) {
    final colorScheme = Theme.of(context).colorScheme;

    final scaledFontSize = FontScaleCalculator.calculateFinalSize(
      type,
      _previewOption,
      context: context,
    );

    return TextStyle(
      fontSize: scaledFontSize,
      color: colorScheme.onSurface,
      height: 1.4,
      fontFamily: 'PingFang SC',
    );
  }

  Widget _buildPreviewFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recommended = ThemeManager.instance.getRecommendedFontSize(context);
    final isRecommended = recommended == _previewOption;
    final scaledNormal = FontScaleCalculator.calculateFinalSize(
      FontSizeType.normal,
      _previewOption,
      context: context,
    );
    final isAccessible = FontScaleCalculator.isAccessibleSize(scaledNormal);
    final percent = (_previewOption.scale * 100).toInt();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              '当前：${_previewOption.displayName} $percent%',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontFamily: 'PingFang SC',
              ),
            ),
            const SizedBox(width: 8),
            if (isRecommended)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '推荐',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.primary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
          ],
        ),
        Text(
          isAccessible ? '可读性良好' : '字体偏小，可能影响阅读',
          style: TextStyle(
            fontSize: 12,
            color: isAccessible ? colorScheme.primary : colorScheme.error,
            fontFamily: 'PingFang SC',
          ),
        ),
      ],
    );
  }
}
