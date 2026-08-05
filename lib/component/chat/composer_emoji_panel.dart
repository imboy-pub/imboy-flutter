import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 表情面板高度：约 5 行 8 列 + 分类条 + 底部动作条。
const double kComposerEmojiPanelHeight = 250;

/// 在光标处插入表情。
///
/// 光标 selection 可能为 -1（从未聚焦），此时追加到末尾，避免
/// `replaceRange(-1, ...)` 抛 RangeError。超过 [maxLength]（按 grapheme
/// 计数，与 `TextField.maxLength` 语义一致）则丢弃本次插入。
void insertEmojiAtCursor(
  TextEditingController controller,
  String emoji, {
  required int maxLength,
  ValueChanged<String>? onChanged,
}) {
  final value = controller.value;
  final text = value.text;
  var start = value.selection.start;
  var end = value.selection.end;
  if (start < 0 || end < 0 || start > text.length || end > text.length) {
    start = end = text.length;
  }
  final newText = text.replaceRange(start, end, emoji);
  if (newText.characters.length > maxLength) return;
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
  onChanged?.call(newText);
}

/// 退一个字素簇（emoji 由多个 code unit 组成，按 rune 退会退出半个表情）。
void deleteLastGrapheme(TextEditingController controller) {
  if (controller.text.isEmpty) return;
  final next = controller.text.characters.skipLast(1).toString();
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: next.length),
  );
}

/// 表情面板本体。
///
/// 独立于 [ComposerField] 存在，是因为发布栏把输入框塞在 `Expanded` 里、
/// 左右还并排着图标列 —— 面板若画在输入框内部，只能拿到那一列的宽度
/// （iPhone 390pt 实测只剩 256pt，34% 屏宽被吃掉，表情挤成一团）。
/// 父级把本组件放在整条输入栏**下方**即可拿满屏宽。
class ComposerEmojiPanel extends StatelessWidget {
  const ComposerEmojiPanel({
    super.key,
    required this.controller,
    required this.backgroundColor,
    this.maxLength = 1000,
    this.onChanged,
  });

  final TextEditingController controller;
  final Color backgroundColor;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kComposerEmojiPanelHeight,
      // 列数按实际拿到的宽度算，不假设屏宽 —— 面板可能被分栏/弹窗收窄。
      child: LayoutBuilder(
        builder: (context, constraints) => EmojiPicker(
          onEmojiSelected: (Category? category, Emoji emoji) =>
              insertEmojiAtCursor(
                controller,
                emoji.emoji,
                maxLength: maxLength,
                onChanged: onChanged,
              ),
          onBackspacePressed: () => deleteLastGrapheme(controller),
          config: buildComposerEmojiConfig(
            context,
            backgroundColor,
            columns: emojiColumnsFor(constraints.maxWidth),
          ),
        ),
      ),
    );
  }
}

/// 构造 imboy 品牌化的 [EmojiPicker] 配置。
///
/// 相较包默认值改掉三处「不属于本产品」的观感：
/// 1. 默认分类条/表情区底色是写死的 `#EBEFF2`，暗色模式下白得刺眼 → 跟随输入框底色。
/// 2. 默认底部动作条是整条 `Colors.blue` 实色条 + 蓝色圆形按钮 → 压平成同底色 + 灰图标。
/// 3. 默认搜索视图是「结果横条 + 裸 arrow_back + 无边框 TextField」→ 换 [_BrandSearchView]。
/// 单个表情格的目标边长：Apple HIG / Material 的最小命中区。
/// 列数由可用宽度除以它推出来，而不是写死 —— 写死列数等于把格子尺寸
/// 交给屏宽决定（SE 320pt 每格 40pt，iPad 810pt 每格 101pt）。
const double _kEmojiCellTarget = 44;

/// 按可用宽度推列数，保证每格 ≥ [_kEmojiCellTarget]。
///
/// 命中区优先于列数：窄面板（分栏/小窗）宁可少几列也不把格子压到 44pt 以下。
/// 下限 4 列只防退化成一条竖列；上限 20 列防超宽屏无限细分。
/// 格子变大不会让表情变成巨图 —— `EmojiViewConfig.getEmojiSize` 用
/// `min(boxSize, emojiSizeMax=28)` 封顶，多出来的只是留白。
int emojiColumnsFor(double width) =>
    (width / _kEmojiCellTarget).floor().clamp(4, 20);

Config buildComposerEmojiConfig(
  BuildContext context,
  Color backgroundColor, {
  required int columns,
}) {
  final brightness = Theme.of(context).brightness;
  final iconColor = AppColors.getTextColor(brightness, isSecondary: true);
  return Config(
    height: kComposerEmojiPanelHeight,
    emojiViewConfig: EmojiViewConfig(
      columns: columns,
      emojiSizeMax: 28,
      backgroundColor: backgroundColor,
      gridPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      buttonMode: ButtonMode.CUPERTINO,
      noRecents: Text(
        t.common.noData,
        style: context.textStyle(FontSizeType.body, color: AppColors.iosGray3),
        textAlign: TextAlign.center,
      ),
    ),
    categoryViewConfig: CategoryViewConfig(
      tabBarHeight: 40,
      backgroundColor: backgroundColor,
      // 首屏落在「最近使用」时若无历史只有一句空文案，改落笑脸分类，开箱即有内容。
      initCategory: Category.SMILEYS,
      iconColor: iconColor,
      iconColorSelected: AppColors.primary,
      indicatorColor: AppColors.primary,
      backspaceColor: AppColors.primary,
      dividerColor: Colors.transparent,
    ),
    bottomActionBarConfig: BottomActionBarConfig(
      backgroundColor: backgroundColor,
      // 透明按钮底 = 去掉那圈突兀的蓝色 CircleAvatar，只留扁平图标。
      buttonColor: Colors.transparent,
      buttonIconColor: iconColor,
    ),
    searchViewConfig: SearchViewConfig(
      backgroundColor: backgroundColor,
      buttonIconColor: iconColor,
      hintText: t.common.search,
      customSearchView: (config, state, showEmojiView) =>
          _BrandSearchView(config, state, showEmojiView),
    ),
  );
}

/// 品牌化表情搜索视图：顶部圆角搜索条，下方网格铺满剩余空间。
///
/// 包内 `DefaultSearchView` 把结果压成一行横向滚动条、搜索框裸奔无边框，
/// 250pt 面板里近 200pt 是空白。这里改成「搜索条在上、网格在下」。
class _BrandSearchView extends SearchView {
  const _BrandSearchView(super.config, super.state, super.showEmojiView);

  @override
  State<_BrandSearchView> createState() => _BrandSearchViewState();
}

class _BrandSearchViewState extends SearchViewState<_BrandSearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    onTextInputChanged(text);
    setState(() {}); // 仅用于清除按钮的显隐
  }

  @override
  Widget build(BuildContext context) {
    final searchConfig = widget.config.searchViewConfig;
    final emojiConfig = widget.config.emojiViewConfig;
    final brightness = Theme.of(context).brightness;

    return Container(
      color: searchConfig.backgroundColor,
      child: Column(
        children: [
          _buildSearchBar(searchConfig, brightness),
          Expanded(child: _buildResults(emojiConfig)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(SearchViewConfig config, Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.small,
      ),
      child: Row(
        children: [
          IconButton(
            // ≥44pt 触达
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: widget.showEmojiView,
            color: config.buttonIconColor,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
              ),
              decoration: BoxDecoration(
                color: AppColors.getIosSeparator(
                  brightness,
                ).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: AppColors.iosGray),
                  AppSpacing.horizontalTiny,
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: focusNode,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      style:
                          config.inputTextStyle ??
                          context.textStyle(
                            FontSizeType.body,
                            color: AppColors.getTextColor(brightness),
                          ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: config.hintText,
                        hintStyle:
                            config.hintTextStyle ??
                            context.textStyle(
                              FontSizeType.body,
                              color: AppColors.iosGray,
                            ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _onChanged('');
                      },
                      child: Icon(
                        Icons.cancel,
                        size: 18,
                        color: AppColors.iosGray3,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(EmojiViewConfig config) {
    if (results.isEmpty) {
      return Center(child: config.noRecents);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - AppSpacing.small * 2;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: config.columns,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) => buildEmoji(
            results[index],
            config.getEmojiSize(width),
            config.getEmojiBoxSize(width),
          ),
        );
      },
    );
  }
}
