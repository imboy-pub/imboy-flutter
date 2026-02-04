import 'package:imboy/i18n/strings.g.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/image_button.dart' show ImageButton;
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 键盘高度观察者
class _KeyboardObserver with WidgetsBindingObserver {
  final VoidCallback onKeyboardChanged;

  _KeyboardObserver(this.onKeyboardChanged);

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    onKeyboardChanged();
  }
}

/// 部分代码来自该项目，感谢作者 CaiJingLong https://github.com/CaiJingLong/flutter_like_wechat_input
/// 输入类型枚举
enum InputType {
  text, // 文本输入
  voice, // 语音输入
  emoji, // 表情输入
  extra, // 附加功能
}

/// 发送按钮显示模式
enum SendButtonVisibilityMode {
  editing, // 编辑时显示
  always, // 始终显示
}

/// 聊天输入框组件
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.type,
    required this.peerId,
    required this.onSendPressed,
    required this.composerHeight,
    this.isAttachmentUploading,
    this.onAttachmentPressed,
    this.onTextChanged,
    this.onTextFieldTap,
    this.extraWidget,
    this.voiceWidget,
    this.quoteTipsWidget,
    this.sendButtonVisibilityMode = SendButtonVisibilityMode.editing,
    this.handleSafeArea = true,
    this.backgroundColor,
    this.hintText = 'Type a message',
    this.keyboardAppearance,
    this.autocorrect = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction = TextInputAction.newline,
    this.maxLines = 6,
    this.minLines = 1,
    this.maxLength = 1000,
    this.contentInsertionConfiguration,
  });

  final String type; // 聊天类型
  final String peerId; // 对方ID
  final bool? isAttachmentUploading; // 附件是否正在上传
  final VoidCallback? onAttachmentPressed; // 附件按钮点击事件
  final Future<bool> Function(String) onSendPressed; // 发送按钮回调
  final void Function(String)? onTextChanged; // 文本变更回调
  final void Function()? onTextFieldTap; // 输入框点击回调
  final SendButtonVisibilityMode sendButtonVisibilityMode; // 发送按钮模式
  final Widget? extraWidget; // 扩展面板
  final Widget? voiceWidget; // 语音输入组件
  final Widget? quoteTipsWidget; // 引用消息条
  final bool? handleSafeArea; // 是否处理安全区
  final Color? backgroundColor; // 背景色
  final String? hintText; // 输入框提示语
  final Brightness? keyboardAppearance; // 键盘主题
  final bool? autocorrect; // 是否自动校正
  final bool autofocus; // 是否自动获取焦点
  final TextCapitalization textCapitalization; // 首字母大写策略
  final TextInputType? keyboardType; // 键盘类型
  final TextInputAction? textInputAction; // 键盘回车行为
  final int? maxLines; // 最大行数
  final int? minLines; // 最小行数
  final int? maxLength; // 最大输入长度
  final ValueNotifier<double> composerHeight; // 外部传递的输入区高度notifier（用于丝滑动画）
  final ContentInsertionConfiguration? contentInsertionConfiguration; // 内容插入配置

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final _inputFocusNode = FocusNode(); // 输入框焦点
  final _keyboardListenerFocusNode = FocusNode(); // 键盘监听器焦点
  final _textController = TextEditingController(); // 文本输入控制器

  // 公开内部方法供外部调用
  FocusNode get inputFocusNode => _inputFocusNode;
  TextEditingController get textController => _textController;
  late AnimationController _bottomHeightController; // 兼容旧动画逻辑
  late String draftKey; // 草稿key
  Timer? _debounceTimer;

  final _emojiShowing = ValueNotifier<bool>(false); // 是否显示表情面板
  final _inputType = ValueNotifier<InputType>(InputType.text); // 当前输入类型
  final _sendButtonVisible = ValueNotifier<bool>(false); // 发送按钮可见性
  final _characterCount = ValueNotifier<int>(0); // 字符计数
  final _isFocused = ValueNotifier<bool>(false); // 输入框聚焦状态
  final _showMentionList = ValueNotifier<bool>(false); // 是否显示@提及列表
  final _mentionCandidates = ValueNotifier<List<String>>([]); // @提及候选列表
  final _showQuickReplies = ValueNotifier<bool>(false); // 是否显示快捷回复
  final _quickReplies = ValueNotifier<List<String>>([
    t.quickReplyOk,
    t.quickReplyReceived,
    t.quickReplyThanks,
    t.understood,
    t.quickReplyWait,
    t.noProblem,
    t.onMyWay,
    t.quickReplyOkThanks,
  ]); // 快捷回复列表

  final double iconSize = 40; // 图标大小
  final double _softKeyHeight = 270; // 软键盘默认高度
  final double fontSize = 22 * (Platform.isIOS ? 1.2 : 1.0); // 字体大小
  double _keyboardHeight = 0; // 当前键盘高度
  bool _isTransitioningToTextFromPanel = false; // 是否正在从面板切换回文本（用于丝滑动画）

  @override
  void initState() {
    super.initState();
    draftKey = "draft${widget.type}_${widget.peerId}";

    _initTextController();
    _initAnimationController();
    _initEventListeners();
    _initFocusListener();
    _initMentionListener();

    _setupKeyboardListener();
  }

  /// 初始化文本控制器（监听输入变化、控制发送按钮显隐）
  void _initTextController() {
    if (widget.sendButtonVisibilityMode == SendButtonVisibilityMode.editing) {
      _sendButtonVisible.value = _textController.text.trim().isNotEmpty;
      _textController.addListener(_handleTextControllerChange);
    } else {
      _sendButtonVisible.value = true;
    }
  }

  /// 初始化动画控制器（用于底部面板展开/收起动画，实际已被丝滑高度控制替代）
  void _initAnimationController() {
    _bottomHeightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _bottomHeightController.animateBack(0);
  }

  /// 初始化焦点监听器
  void _initFocusListener() {
    _inputFocusNode.addListener(() {
      _isFocused.value = _inputFocusNode.hasFocus;
      if (_inputFocusNode.hasFocus) {
        updateState(InputType.text);
      }
    });
  }

  /// 初始化事件监听器（输入框获取焦点自动切回文本模式）
  void _initEventListeners() {
    /// 加载本地草稿（避免信息丢失提升用户体验）
    final draft = StorageService.to.getString(draftKey);
    if (draft.isNotEmpty) {
      _setText(draft);
    }

    // 监听输入框焦点变化，自动切换到文本输入模式
    // 已移至 _initFocusListener()
  }

  /// 设置键盘监听器（获取键盘高度，兼容多机型，动态设置输入区高度实现丝滑）
  void _setupKeyboardListener() {
    // 立即检查一次键盘状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mediaQuery = MediaQuery.of(context);
      final newKeyboardHeight = mediaQuery.viewInsets.bottom;

      if (newKeyboardHeight != _keyboardHeight) {
        _keyboardHeight = newKeyboardHeight;
        _updateComposerHeightByKeyboard();
      }
    });

    // 监听后续的键盘变化
    WidgetsBinding.instance.addObserver(
      _KeyboardObserver(_updateComposerHeightByKeyboard),
    );
  }

  /// 处理键盘快捷键
  void _handleKeyboardShortcuts(KeyEvent event) {
    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;

      // Command/Ctrl + Enter 发送消息
      if (HardwareKeyboard.instance.isControlPressed &&
          logicalKey == LogicalKeyboardKey.enter) {
        _handleSendPressed();
      }

      // Escape 键收起键盘和面板
      if (logicalKey == LogicalKeyboardKey.escape) {
        hideAllPanel();
      }

      // Command/Ctrl + K 切换输入模式
      if (HardwareKeyboard.instance.isControlPressed &&
          logicalKey == LogicalKeyboardKey.keyK) {
        updateState(
          _inputType.value == InputType.text ? InputType.voice : InputType.text,
        );
      }
    }
  }

  /// 根据系统键盘/自定义面板动态设置输入区高度
  /// 优化版本：快速响应，减少延迟
  void _updateComposerHeightByKeyboard() {
    if (!mounted) return;

    // 触发重绘，以便 build 方法中重新计算 panelHeight
    setState(() {});
  }

  /// 初始化@提及监听器
  void _initMentionListener() {
    _textController.addListener(_handleMentionDetection);
  }

  /// 处理@提及检测
  void _handleMentionDetection() {
    final text = _textController.text;
    final selection = _textController.selection;

    // 检测@符号
    if (text.isNotEmpty && selection.extentOffset > 0) {
      final charBeforeCursor = text.substring(
        selection.extentOffset - 1,
        selection.extentOffset,
      );
      if (charBeforeCursor == '@') {
        _showMentionList.value = true;
        // 模拟群组成员列表
        _mentionCandidates.value = [
          t.testUser1,
          t.testUser2,
          t.testUser3,
          t.testUser4,
          t.testUser5,
        ];
      } else {
        _showMentionList.value = false;
      }
    } else {
      _showMentionList.value = false;
    }
  }

  /// 插入@提及
  void _insertMention(String username) {
    final currentText = _textController.text;
    final selection = _textController.selection;

    // 找到@符号的位置
    final atIndex = currentText.lastIndexOf('@', selection.extentOffset - 1);
    if (atIndex != -1) {
      final newText =
          '${currentText.substring(0, atIndex)}@$username ${currentText.substring(selection.extentOffset)}';
      final newCursorPosition = atIndex + username.length + 2;

      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    }

    _showMentionList.value = false;
  }

  /// 构建快捷回复面板
  Widget _buildQuickRepliesPanel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showQuickReplies,
      builder: (context, showQuickReplies, _) {
        if (!showQuickReplies) return const SizedBox.shrink();

        return ValueListenableBuilder<List<String>>(
          valueListenable: _quickReplies,
          builder: (context, replies, _) {
            return Container(
              height: 60,
              decoration: BoxDecoration(
                color: ThemeManager.instance.getThemeColor('surface'),
                border: Border(
                  top: BorderSide(
                    color: ThemeManager.instance
                        .getThemeColor('outline')
                        .withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: replies.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => _insertQuickReply(replies[index]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeManager.instance
                            .getThemeColor('primary')
                            .withValues(alpha: 0.1),
                        foregroundColor: ThemeManager.instance.getThemeColor(
                          'primary',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderRadiusRegular,
                        ),
                        elevation: 0,
                      ),
                      child: Text(replies[index]),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// 插入快捷回复
  void _insertQuickReply(String reply) {
    _textController.text = reply;
    _sendButtonVisible.value = true;
    _showQuickReplies.value = false;
  }

  /// 构建@提及列表
  Widget _buildMentionList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showMentionList,
      builder: (context, showMentionList, _) {
        if (!showMentionList) return const SizedBox.shrink();

        return ValueListenableBuilder<List<String>>(
          valueListenable: _mentionCandidates,
          builder: (context, candidates, _) {
            return Container(
              height: 180,
              decoration: BoxDecoration(
                color: ThemeManager.instance.getThemeColor('surface'),
                borderRadius: AppRadius.borderRadiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(candidates[index]),
                    onTap: () => _insertMention(candidates[index]),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// 处理文本控制器变化（带节流，存储草稿，发送文本变更回调）
  void _handleTextControllerChange() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final text = _textController.text.trim();
      _sendButtonVisible.value = text.isNotEmpty;
      _characterCount.value = text.characters.length;

      // 超长自动裁剪并存储草稿
      if (text.length <= (widget.maxLength ?? 1000)) {
        StorageService.to.setString(draftKey, _textController.text);
      }

      widget.onTextChanged?.call(_textController.text);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    _textController.dispose();
    _bottomHeightController.dispose();
    _emojiShowing.dispose();
    _inputType.dispose();
    _sendButtonVisible.dispose();
    _characterCount.dispose();
    _isFocused.dispose();
    _showMentionList.dispose();
    _mentionCandidates.dispose();
    _showQuickReplies.dispose();
    _quickReplies.dispose();
    super.dispose();
  }

  /// 设置文本内容（支持emoji安全插入/裁剪，保持光标位置）
  void _setText(String insertText) {
    final maxLength = widget.maxLength ?? 1000;
    final oldValue = _textController.value;

    int start = oldValue.selection.start;
    int end = oldValue.selection.end;

    // 边界校验，防止崩溃
    if (start < 0 ||
        end < 0 ||
        start > oldValue.text.length ||
        end > oldValue.text.length) {
      start = end = oldValue.text.length;
    }

    String newText = oldValue.text.replaceRange(start, end, insertText);

    // emoji安全长度判断
    if (newText.characters.length > maxLength) {
      final allowInsertLength =
          maxLength - (oldValue.text.characters.length - (end - start));
      if (allowInsertLength <= 0) return;
      insertText = insertText.characters.take(allowInsertLength).toString();
      newText = oldValue.text.replaceRange(start, end, insertText);
    }
    if (newText.length > maxLength) {
      final allowInsertLength =
          maxLength - (oldValue.text.length - (end - start));
      if (allowInsertLength <= 0) return;
      insertText = insertText.substring(0, allowInsertLength);
      newText = oldValue.text.replaceRange(start, end, insertText);
    }
    final offset = start + insertText.length;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  /// 公开的设置文本方法，供外部调用
  void setText(String text) {
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 处理发送按钮点击（异步发送，草稿清理，安全判断 mounted）
  Future<void> _handleSendPressed() async {
    final trimmedText = _textController.text.trim();
    if (trimmedText.isNotEmpty) {
      final res = await widget.onSendPressed(trimmedText);
      if (!mounted) return; // 异步gap后安全检查
      if (res) {
        _textController.clear();
        StorageService.to.remove(draftKey);
        // 发送后自动收起键盘
        FocusScope.of(context).unfocus();
      }
    }
  }

  /// 统一对外收起所有面板（键盘、emoji、extra），并让输入区高度归零
  void hideAllPanel() {
    FocusScope.of(context).unfocus();
    _inputType.value = InputType.text;
    _emojiShowing.value = false;
  }

  /// 对外提供unfocus方法，用于收起输入框和面板
  void unfocus() {
    hideAllPanel();
  }

  /// 切换输入类型（文本/语音/表情/扩展面板），优化版本：更平滑的高度过渡
  Future<void> updateState(InputType type) async {
    if (type == _inputType.value) return;

    final oldType = _inputType.value;
    _inputType.value = type;
    _emojiShowing.value = type == InputType.emoji;

    if (type == InputType.text) {
      // 切换到文本输入，先收起面板，再唤起键盘
      if (oldType == InputType.emoji || oldType == InputType.extra) {
        _isTransitioningToTextFromPanel = true;
      }

      _updateComposerHeightByKeyboard(); // 先更新高度
      // 立即请求焦点，不使用 await 延迟，减少空白闪烁
      if (mounted) {
        FocusScope.of(context).requestFocus(_inputFocusNode);
      }
    } else if (type == InputType.voice) {
      // 切换到语音模式，收起所有面板
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 100)); // 等待键盘收起
      _updateComposerHeightByKeyboard();
    } else {
      // 切换到emoji/extra，先收起键盘，再展示面板
      FocusScope.of(context).unfocus();

      // 根据之前的状态调整延迟时间
      final delay = oldType == InputType.text
          ? const Duration(milliseconds: 150) // 从文本切换需要等键盘收起
          : const Duration(milliseconds: 50); // 从其他状态切换延迟较短

      await Future.delayed(delay);
      if (!mounted) return;

      // 触发重新构建，让 ChatInputHeightListener 检测到高度变化并执行动画
      setState(() {});
    }
  }

  /// 构建底部容器（emoji/扩展面板，带动画）—— 丝滑高度逻辑
  Widget _buildBottomContainer({
    required Widget child,
    required double height,
  }) {
    // 如果高度为0，且不显示，则隐藏（避免点击穿透等问题）
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 面板区域消费手势，避免向上冒泡触发返回/侧滑
        onTap: () {},
        child: child,
      ),
    );
  }

  /// 构建底部项目（emoji/扩展面板内容）
  Widget _buildBottomItems() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        if (inputType == InputType.extra) {
          // 扩展功能面板
          return widget.extraWidget ?? const Center(child: Text("Extra Items"));
        } else if (inputType == InputType.emoji) {
          final columns = MediaQuery.of(context).size.width ~/ (fontSize + 10);
          return ValueListenableBuilder<bool>(
            valueListenable: _emojiShowing,
            builder: (context, emojiShowing, _) {
              return Offstage(
                offstage: !emojiShowing,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // 面板命中不穿透，避免触发外层返回/侧滑
                  child: EmojiPicker(
                    onEmojiSelected: (Category? category, Emoji emoji) {
                      _setText(emoji.emoji);
                    },
                    onBackspacePressed: () {
                      if (_textController.text.isNotEmpty) {
                        _textController
                          ..text = _textController.text.characters
                              .skipLast(1)
                              .toString()
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                      }
                    },
                    config: Config(
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        columns: columns,
                        emojiSizeMax: fontSize,
                        verticalSpacing: 0,
                        horizontalSpacing: 4,
                        recentsLimit: columns * 3 - 2,
                        buttonMode: ButtonMode.MATERIAL,
                        backgroundColor: ThemeManager.instance.getThemeColor(
                          'surface',
                        ),
                      ),
                      skinToneConfig: SkinToneConfig(
                        indicatorColor: ThemeManager.instance.getThemeColor(
                          'surface',
                        ),
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        tabBarHeight: 48,
                        backgroundColor: ThemeManager.instance.getThemeColor(
                          'surface',
                        ),
                        iconColor: ThemeManager.instance.getThemeColor(
                          'textSecondary',
                        ),
                        iconColorSelected: ThemeManager.instance.getThemeColor(
                          'primary',
                        ),
                        indicatorColor: ThemeManager.instance.getThemeColor(
                          'primary',
                        ),
                        categoryIcons: const CategoryIcons(
                          recentIcon: Icons.access_time_outlined,
                          smileyIcon: Icons.emoji_emotions_outlined,
                          animalIcon: Icons.cruelty_free_outlined,
                          foodIcon: Icons.coffee_outlined,
                          activityIcon: Icons.sports_soccer_outlined,
                          travelIcon: Icons.directions_car_filled_outlined,
                          objectIcon: Icons.lightbulb_outline,
                          symbolIcon: Icons.emoji_symbols_outlined,
                          flagIcon: Icons.flag_outlined,
                        ),
                      ),
                      bottomActionBarConfig: BottomActionBarConfig(
                        enabled: true,
                        backgroundColor: ThemeManager.instance.getThemeColor(
                          'surface',
                        ),
                        buttonColor: ThemeManager.instance.getThemeColor(
                          'primary',
                        ),
                        buttonIconColor: Colors.white,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: ThemeManager.instance.getThemeColor(
                          'surface',
                        ),
                        buttonIconColor: ThemeManager.instance.getThemeColor(
                          'primary',
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  /// 构建输入框（支持多行、emoji、安全选择等，支持键盘快捷键）
  Widget _buildInputField() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isFocused,
      builder: (context, isFocused, _) {
        return KeyboardListener(
          focusNode: _keyboardListenerFocusNode,
          onKeyEvent: _handleKeyboardShortcuts,
          child: TextField(
            controller: _textController,
            focusNode: _inputFocusNode,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            enableInteractiveSelection: true,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            contentInsertionConfiguration: widget.contentInsertionConfiguration,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: ThemeManager.instance.getThemeColor('textSecondary'),
                fontSize: ThemeManager.instance.getFontSize(
                  FontSizeType.medium,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
              filled: isFocused,
              fillColor: isFocused
                  ? ThemeManager.instance
                        .getThemeColor('primary')
                        .withValues(alpha: 0.05)
                  : Colors.transparent,
            ),
            style: TextStyle(
              color: ThemeManager.instance.getThemeColor('textPrimary'),
              fontSize: ThemeManager.instance.getFontSize(FontSizeType.medium),
            ),
            onChanged: (val) {
              _handleTextControllerChange();
            },
            onTap: () {
              updateState(InputType.text);
              widget.onTextFieldTap?.call();
            },
            onSubmitted: (_) => _handleSendPressed(),
          ),
        );
      },
    );
  }

  /// 构建语音输入组件（使用增强版语音录制器或自定义组件）
  Widget _buildVoiceInput() {
    if (widget.voiceWidget != null) {
      return widget.voiceWidget!;
    }
    return SizedBox.shrink();
  }

  /// 构建输入按钮（文本/语音切换，AnimatedSwitcher 平滑过渡）
  Widget _buildInputButton() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) {
            return FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: inputType == InputType.voice
              ? KeyedSubtree(
                  key: const ValueKey('voice'),
                  child: _buildVoiceInput(),
                )
              : KeyedSubtree(
                  key: const ValueKey('text'),
                  child: _buildInputField(),
                ),
        );
      },
    );
  }

  /// 构建左侧按钮（语音/键盘切换）
  Widget _buildLeftButton() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        return ImageButton(
          width: 48,
          height: 48,
          onPressed: () {
            if (inputType == InputType.voice) {
              updateState(InputType.text);
            } else {
              updateState(InputType.voice);
            }
          },
          image: inputType != InputType.voice
              ? Icon(Icons.keyboard_voice_outlined, size: iconSize)
              : Icon(Icons.keyboard_alt_outlined, size: iconSize),
        );
      },
    );
  }

  /// 构建表情按钮
  Widget _buildEmojiButton() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        return ImageButton(
          image: inputType != InputType.emoji
              ? Icon(Icons.emoji_emotions_outlined, size: iconSize)
              : Icon(Icons.keyboard_alt_outlined, size: iconSize),
          onPressed: () {
            updateState(
              inputType != InputType.emoji ? InputType.emoji : InputType.text,
            );
          },
        );
      },
    );
  }

  /// 构建附加功能按钮
  Widget _buildExtraButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _sendButtonVisible,
      builder: (context, sendButtonVisible, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: sendButtonVisible
              ? const SizedBox.shrink(key: ValueKey('empty_extra'))
              : ImageButton(
                  key: const ValueKey('extra_button'),
                  image: const Icon(Icons.control_point, size: 40),
                  onPressed: () {
                    updateState(
                      _inputType.value != InputType.extra
                          ? InputType.extra
                          : InputType.text,
                    );
                  },
                ),
        );
      },
    );
  }

  /// 构建发送按钮（带动画效果）
  Widget _buildSendButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _sendButtonVisible,
      builder: (context, sendButtonVisible, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: sendButtonVisible
              ? IconButton(
                  key: const ValueKey('send_button'),
                  icon: Icon(
                    Icons.send,
                    color: ThemeManager.instance.getThemeColor('primary'),
                  ),
                  onPressed: _handleSendPressed,
                  padding: const EdgeInsets.only(left: 0),
                )
              : const SizedBox.shrink(key: ValueKey('empty_button')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 每次构建时都设置键盘监听器，确保能及时响应键盘变化
    _setupKeyboardListener();

    // 计算底部面板高度，实现丝滑切换
    // 使用 View.of(context) 获取全局的 viewInsets，避免被 Scaffold(resizeToAvoidBottomInset: true) 消费掉
    // 从而导致在键盘弹出时获取到的 bottomInset 为 0，引发面板高度计算错误（出现空白）
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;

    // iPhone 底部安全区域处理
    // 即使在键盘未弹出时，iPhone X+ 机型也有底部安全区域（通常34px）
    // 这会导致输入框和键盘之间出现空隙，因为 bottomInset 包含了这个安全区域
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // 修正后的 bottomInset：减去安全区域高度，但不能小于0
    // 当键盘弹出时，viewInsets.bottom 包含键盘高度 + 安全区域（某些情况下）或仅键盘高度
    // 我们主要关注的是键盘带来的"额外"高度
    if (Platform.isIOS && bottomInset > 0) {
      // 在 iOS 上，键盘弹出时的 viewInsets.bottom 通常已经处理了安全区域
      // 但在某些机型（如 iPhone 16E）上可能存在差异
      // 这里的逻辑是：如果 bottomInset 很小（接近安全区域高度），则认为是键盘未弹出或仅是安全区域干扰
    }

    // 更新记录的键盘高度 (只要看起来像键盘的高度就更新，适应不同输入法高度变化)
    // 增加判断：只有显著大于底部安全区域的高度才被视为键盘高度
    if (bottomInset > (bottomPadding + 50)) {
      _keyboardHeight = bottomInset;
    }

    final targetPanelHeight = _keyboardHeight > 0
        ? _keyboardHeight
        : _softKeyHeight;
    double panelHeight = 0;

    if (_inputType.value == InputType.emoji ||
        _inputType.value == InputType.extra) {
      // 面板展开模式：面板高度 = 目标高度 - 当前键盘高度（实现键盘收起时面板逐渐出现）
      // 这里使用原始 bottomInset，因为我们需要填补键盘腾出的空间
      panelHeight = max(0, targetPanelHeight - bottomInset);
    } else if (_inputType.value == InputType.text) {
      // 文本模式：
      // 如果正在从面板切换回文本，且键盘还未完全弹出，保持面板填充剩余空间
      if (_isTransitioningToTextFromPanel) {
        if (bottomInset > 0) {
          // 键盘开始弹起，面板高度 = 目标高度 - 当前键盘高度
          // 这样 键盘高度 + 面板高度 ≈ 目标高度，实现无缝过渡
          panelHeight = max(0, targetPanelHeight - bottomInset);

          // 当键盘高度接近完全展开时，结束过渡状态
          if (bottomInset >= targetPanelHeight * 0.9) {
            _isTransitioningToTextFromPanel = false;
            panelHeight = 0;
          }
        } else {
          // 键盘未弹起时，保持面板高度，避免闪烁
          panelHeight = targetPanelHeight;
        }
      } else {
        panelHeight = 0;
      }
    } else {
      panelHeight = 0;
    }

    return Container(
      color:
          widget.backgroundColor ??
          ThemeManager.instance.getThemeColor('surface'),
      child: Column(
        children: [
          // 引用消息提示条
          if (widget.quoteTipsWidget != null) widget.quoteTipsWidget!,

          // 主输入区域
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 左侧语音/键盘切换按钮
                _buildLeftButton(),

                // 中间输入区域（文本输入框或语音按钮）
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: 28,
                      maxHeight: (widget.maxLines ?? 6) * 24.0 + 24,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: ThemeManager.instance
                          .getThemeColor('surface')
                          .withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusLarge,
                      border: Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [_buildInputButton()],
                          ),
                        ),
                        // @提及列表
                        Positioned(
                          bottom: -180, // 将列表移到输入框外部，避免占用内部空间
                          left: 0,
                          right: 0,
                          child: _buildMentionList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // 表情按钮
                _buildEmojiButton(),

                // 发送按钮或附加功能按钮
                ValueListenableBuilder<bool>(
                  valueListenable: _sendButtonVisible,
                  builder: (context, sendButtonVisible, _) {
                    return sendButtonVisible
                        ? _buildSendButton()
                        : _buildExtraButton();
                  },
                ),
              ],
            ),
          ),

          // 底部面板（表情选择器或扩展功能）
          _buildBottomContainer(
            child: _buildBottomItems(),
            height: panelHeight,
          ),

          // 快捷回复面板
          _buildQuickRepliesPanel(),
        ],
      ),
    );
  }
}
