import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 共享富输入组件 / Shared rich composer field.
///
/// 频道发布栏、频道评论、朋友圈撰写区共用。相较裸 [TextField] 补齐：
/// - 表情面板开关 + [EmojiPicker]（选中在光标处插入，光标无效时追加到末尾）
/// - 字数计数 + [maxLength]，超过 [warnThreshold] 计数变警示色
///
/// 刻意不含语音/群工具/`+`面板/键盘丝滑动画/禁言态 —— 这些是聊天专属职责，
/// 由 `chat_input.dart` 承担，本组件保持边界干净。
class ComposerField extends StatefulWidget {
  const ComposerField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.maxLength = 1000,
    this.warnThreshold,
    this.enabled = true,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines,
    this.showCounter = true,
    this.showEmojiButton = true,
    this.textInputAction = TextInputAction.newline,
    this.onChanged,
    this.onSubmitted,
  });

  /// 外部文本控制器；为空时内部自建并负责释放。
  final TextEditingController? controller;

  /// 外部焦点节点；为空时内部自建并负责释放。
  final FocusNode? focusNode;

  final String? hintText;

  /// 硬上限（按 grapheme 计数，与 [TextField.maxLength] 一致）。
  final int maxLength;

  /// 计数变警示色的阈值；为空时取 [maxLength] 的 90%。
  /// 频道发布栏传入折叠阈值（280），提示作者"超过将被折叠"。
  final int? warnThreshold;

  final bool enabled;
  final bool autofocus;
  final int minLines;
  final int? maxLines;
  final bool showCounter;
  final bool showEmojiButton;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;

  /// 键盘动作键（发送/换行）触发。
  final VoidCallback? onSubmitted;

  @override
  State<ComposerField> createState() => ComposerFieldState();
}

class ComposerFieldState extends State<ComposerField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _emojiOpen = false;

  int get _warnThreshold =>
      widget.warnThreshold ?? (widget.maxLength * 0.9).floor();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  /// 计数依赖 controller，字符变化即刷新计数颜色。
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// 在光标处插入表情。光标 selection 可能为 -1（从未聚焦），此时追加到末尾，
  /// 避免 replaceRange(-1, ...) 抛 RangeError。
  void _insertEmoji(String emoji) {
    final value = _controller.value;
    final text = value.text;
    var start = value.selection.start;
    var end = value.selection.end;
    if (start < 0 || end < 0 || start > text.length || end > text.length) {
      start = end = text.length;
    }
    final newText = text.replaceRange(start, end, emoji);
    // 超上限则丢弃这次插入（按 grapheme 计数，与 maxLength 语义一致）。
    if (newText.characters.length > widget.maxLength) return;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    widget.onChanged?.call(newText);
  }

  /// 仅供测试：验证光标无效(-1)时插入不崩溃。
  @visibleForTesting
  void debugInsertEmoji(String emoji) => _insertEmoji(emoji);

  void _toggleEmoji() {
    setState(() => _emojiOpen = !_emojiOpen);
    if (_emojiOpen) {
      _focusNode.unfocus(); // 收起系统键盘，让位表情面板
    } else if (widget.enabled) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = AppColors.getIosSeparator(
      Theme.of(context).brightness,
    ).withValues(alpha: 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: AppRadius.borderRadiusRegular,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('composer_text_field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  textInputAction: widget.textInputAction,
                  onTap: () {
                    if (_emojiOpen) setState(() => _emojiOpen = false);
                  },
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: context.textStyle(
                      FontSizeType.body,
                      color: AppColors.iosGray,
                    ),
                    border: InputBorder.none,
                    counterText: '', // 计数由下方自绘，隐藏内置
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: context
                      .textStyle(
                        FontSizeType.body,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                        ),
                      )
                      .copyWith(height: 1.4),
                ),
              ),
              if (widget.showEmojiButton)
                IconButton(
                  key: const Key('composer_emoji_button'),
                  // ≥44pt 触达
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  onPressed: widget.enabled ? _toggleEmoji : null,
                  icon: Icon(
                    _emojiOpen
                        ? Icons.keyboard_outlined
                        : Icons.emoji_emotions_outlined,
                    size: 24,
                    color: AppColors.iosGray,
                  ),
                ),
            ],
          ),
        ),
        if (widget.showCounter) _buildCounter(context),
        if (_emojiOpen) _buildEmojiPanel(fillColor),
      ],
    );
  }

  Widget _buildCounter(BuildContext context) {
    final len = _controller.text.characters.length;
    final warn = len > _warnThreshold;
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$len/${widget.maxLength}',
          key: const Key('composer_counter'),
          style: context.textStyle(
            FontSizeType.caption2,
            color: warn ? AppColors.iosOrange : AppColors.iosGray3,
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiPanel(Color backgroundColor) {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (Category? category, Emoji emoji) {
          _insertEmoji(emoji.emoji);
        },
        onBackspacePressed: () {
          if (_controller.text.isNotEmpty) {
            _controller
              ..text = _controller.text.characters.skipLast(1).toString()
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
          }
        },
        config: Config(
          emojiViewConfig: EmojiViewConfig(backgroundColor: backgroundColor),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: backgroundColor,
            iconColorSelected: AppColors.primary,
            indicatorColor: AppColors.primary,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: backgroundColor,
            buttonColor: AppColors.primary,
            buttonIconColor: AppColors.onPrimary,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: backgroundColor,
            buttonIconColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
