import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart' show currentFontSize;
import 'package:imboy/theme/default/font_types.dart';

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
      // ThemeManager 会自动保存设置，无需重复持久化
      await ThemeManager.instance.updateFontSizeOption(option);

      // 更新全局变量（兼容旧代码）
      currentFontSize.value = option.value;

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

  /// 构建预览文本样式
  TextStyle _getPreviewTextStyle(BuildContext context, FontSizeType type) {
    return ThemeManager.instance.getTextStyle(
      type,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// 构建预览页脚（模拟微信风格）
  Widget _buildPreviewFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '当前：${_previewOption.displayName} ${(_previewOption.scale * 100).toInt()}%',
          style: _getPreviewTextStyle(context, FontSizeType.small).copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '推荐',
            style: _getPreviewTextStyle(context, FontSizeType.small).copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 预览区域是否可读
    final isAccessible = ThemeManager.instance.previewFontSize(
      _previewOption,
      context: context,
    )['isAccessible'] as bool;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: '字体大小设置',
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
                    '预览效果',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '这是标题文本',
                          style: _getPreviewTextStyle(
                            context,
                            FontSizeType.large,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        _buildPreviewFooter(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 可读性提示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isAccessible ? '可读性良好' : '字体偏小，可能影响阅读',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAccessible ? colorScheme.primary : colorScheme.error,
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
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
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
                const SizedBox(height: 20),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: colorScheme.primary,
                    inactiveTrackColor: colorScheme.outline.withValues(alpha: 0.2),
                    thumbColor: colorScheme.primary,
                    overlayColor: colorScheme.primary.withValues(alpha: 0.2),
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
                    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4.0),
                    activeTickMarkColor: Colors.white,
                    inactiveTickMarkColor: colorScheme.outline.withValues(alpha: 0.4),
                  ),
                  child: Slider(
                    min: 0,
                    max: (fontSizeOptions.length - 1).toDouble(),
                    divisions: fontSizeOptions.length - 1,
                    value: _sliderValue,
                    label: '${_previewOption.displayName} ${(_previewOption.scale * 100).toInt()}%',
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '更小',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                      Text(
                        '更大',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
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
}
