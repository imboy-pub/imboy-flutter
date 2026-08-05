import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/chat/composer_emoji_panel.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
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
    this.emojiOpen,
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

  /// 表情面板开关的外部托管。
  ///
  /// 传入时本组件**只渲染表情按钮**，面板由父级用 [ComposerEmojiPanel] 自行
  /// 挂在整条输入栏下方 —— 输入框被 `Expanded` 夹在图标列之间时，内联面板只能
  /// 拿到输入框那一列的宽度（iPhone 390pt 实测仅 256pt）。
  /// 不传则退回内联（朋友圈/文章页这类本身就占满宽的场景够用）。
  final ValueNotifier<bool>? emojiOpen;
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

  /// 面板未被父级托管时的本地开关。
  bool _localEmojiOpen = false;

  bool get _emojiOpen => widget.emojiOpen?.value ?? _localEmojiOpen;

  set _emojiOpen(bool open) {
    final host = widget.emojiOpen;
    if (host != null) {
      host.value = open; // 父级监听后重建面板
    } else {
      setState(() => _localEmojiOpen = open);
    }
  }

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
    // 聚焦态高亮边框：监听内建/外部 focusNode 均兼容（只用引用不问归属）。
    _focusNode.addListener(_onFocusChanged);
    // 面板由父级托管时，开关变化也要让按钮图标（笑脸↔键盘）跟着切。
    widget.emojiOpen?.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    widget.emojiOpen?.removeListener(_onFocusChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  /// 计数依赖 controller，字符变化即刷新计数颜色。
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// 焦点变化即刷新边框高亮态。
  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// 仅供测试：验证光标无效(-1)时插入不崩溃。
  @visibleForTesting
  void debugInsertEmoji(String emoji) => insertEmojiAtCursor(
    _controller,
    emoji,
    maxLength: widget.maxLength,
    onChanged: widget.onChanged,
  );

  void _toggleEmoji() {
    _emojiOpen = !_emojiOpen;
    if (_emojiOpen) {
      _focusNode.unfocus(); // 收起系统键盘，让位表情面板
    } else if (widget.enabled) {
      _focusNode.requestFocus();
    }
  }

  /// 单行输入条：表情按钮并排在右侧（聊天场景，高度只有一行，不浪费）。
  /// 多行创作区：并排会让按钮独占整条 44pt 右列（朋友圈发布页实测：填充区
  /// 被切掉右侧约 22%，视觉上像两个错位的框），改为浮在输入框右下角。
  Widget _wrapWithEmoji({required Widget field}) {
    if (!widget.showEmojiButton) return field;

    final button = IconButton(
      key: const Key('composer_emoji_button'),
      // ≥44pt 触达
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      onPressed: widget.enabled ? _toggleEmoji : null,
      icon: Icon(
        _emojiOpen ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
        size: 24,
        color: AppColors.iosGray,
      ),
    );

    if (widget.maxLines == 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: field),
          button,
        ],
      );
    }

    return Stack(
      // passthrough：把父级的 tight 宽度原样传给 TextField，
      // 否则非 positioned child 只拿到 loose 约束，输入框不会撑满整宽。
      fit: StackFit.passthrough,
      children: [
        field,
        Positioned(right: 0, bottom: 0, child: button),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFocused = _focusNode.hasFocus;
    // 聚焦微交互：失焦用略凹陷的分组灰底，聚焦提亮到 surface（清爽、有"激活"感）。
    final restFill = isDark
        ? AppColors.darkBackground
        : AppColors.lightSurfaceGrouped;
    final focusFill = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final fillColor = isFocused ? focusFill : restFill;
    // 聚焦态：品牌蓝高亮描边(1.5)；失焦态：近乎无边框（凹陷底色已界定边界）。
    final borderColor = isFocused
        ? AppColors.primary
        : AppColors.getIosSeparator(
            Theme.of(context).brightness,
          ).withValues(alpha: 0.15);
    final borderWidth = isFocused ? 1.5 : 0.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 发送态：enabled=false(发布/上传中)时柔和变暗，与可编辑态区分。
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.enabled ? 1.0 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: AppRadius.borderRadiusRegular,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            // 单行（聊天输入条）表情按钮并排在右；多行（朋友圈/频道创作区）
            // 并排会让按钮独占整条 44pt 右列、把填充区切掉一块，改为浮在右下角。
            child: _wrapWithEmoji(
              field: TextField(
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
                  if (_emojiOpen) _emojiOpen = false;
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
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.medium,
                  ),
                ),
                style: context
                    .textStyle(
                      FontSizeType.body,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                      ),
                    )
                    .copyWith(height: 1.45),
              ),
            ),
          ),
        ),
        // 字数提示仅在接近阈值时出现，消除常驻 "0/2000" 噪音；
        // 频道 warnThreshold=280(折叠区)一到即显并提示"超过将折叠"。
        if (widget.showCounter &&
            _controller.text.characters.length >= _warnThreshold)
          _buildCounter(context),
        // 面板被父级托管时不内联渲染（否则会被输入框那一列的宽度夹住）。
        if (_emojiOpen && widget.emojiOpen == null)
          ComposerEmojiPanel(
            controller: _controller,
            backgroundColor: fillColor,
            maxLength: widget.maxLength,
            onChanged: widget.onChanged,
          ),
      ],
    );
  }

  Widget _buildCounter(BuildContext context) {
    final len = _controller.text.characters.length;
    final warn = len > _warnThreshold;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.tiny,
        right: AppSpacing.tiny,
      ),
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
}
