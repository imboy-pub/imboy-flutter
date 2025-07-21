import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/image_button.dart' show ImageButton;
import 'package:imboy/component/ui/line.dart' show HorizontalLine;
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';

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
  final RxDouble composerHeight; // 外部传递的输入区高度notifier（用于丝滑动画）

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final _inputFocusNode = FocusNode(); // 输入框焦点
  final _textController = TextEditingController(); // 文本输入控制器
  late AnimationController _bottomHeightController; // 兼容旧动画逻辑
  late String draftKey; // 草稿key
  StreamSubscription? ssMsg;
  Timer? _debounceTimer;

  // 用于外部控制消息区/输入区高度实现丝滑动画
  late RxDouble _composerHeight;

  final _emojiShowing = ValueNotifier<bool>(false); // 是否显示表情面板
  final _inputType = ValueNotifier<InputType>(InputType.text); // 当前输入类型
  final _sendButtonVisible = ValueNotifier<bool>(false); // 发送按钮可见性

  final double iconSize = 40; // 图标大小
  final double _softKeyHeight = 198; // 软键盘默认高度
  final double fontSize = 22 * (Platform.isIOS ? 1.2 : 1.0); // 字体大小
  double _keyboardHeight = 0; // 当前键盘高度

  @override
  void initState() {
    super.initState();
    draftKey = "draft${widget.type}_${widget.peerId}";
    // 如果外部传入了 composerHeight，则使用外部的；否则自己新建一个
    _composerHeight = widget.composerHeight;

    _initTextController();
    _initAnimationController();
    _initEventListeners();

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

  /// 初始化事件监听器（输入框获取焦点自动切回文本模式）
  void _initEventListeners() {

    /// 加载本地草稿（避免信息丢失提升用户体验）
    final draft = StorageService.to.getString(draftKey);
    if (draft != null && draft.isNotEmpty) {
      _setText(draft);
    }

    // 接收到新的消息订阅
    ssMsg = eventBus.on<ReEditMessage>().listen((msg) async {
      if (_textController.text.toString() != msg.text) {
        _setText(msg.text);
      }
    });

    // 监听输入框焦点变化，自动切换到文本输入模式
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        updateState(InputType.text);
      }
    });
  }

  /// 设置键盘监听器（获取键盘高度，兼容多机型，动态设置输入区高度实现丝滑）
  void _setupKeyboardListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mediaQuery = MediaQuery.of(context);
      _keyboardHeight = mediaQuery.viewInsets.bottom;
      _updateComposerHeightByKeyboard();
    });
  }

  /// 根据系统键盘/自定义面板动态设置输入区高度
  void _updateComposerHeightByKeyboard() {
    final mediaQuery = MediaQuery.of(context);
    // 系统键盘弹起时
    if (mediaQuery.viewInsets.bottom > 0) {
      _composerHeight.value = mediaQuery.viewInsets.bottom;
    } else if (_inputType.value == InputType.emoji ||
        _inputType.value == InputType.extra) {
      _composerHeight.value = _softKeyHeight;
    } else {
      _composerHeight.value = widget.composerHeight.value;
    }
  }

  /// 处理文本控制器变化（带节流，存储草稿，发送文本变更回调）
  void _handleTextControllerChange() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final text = _textController.text.trim();
      _sendButtonVisible.value = text.isNotEmpty;

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
    _textController.dispose();
    _bottomHeightController.dispose();
    ssMsg?.cancel();
    _emojiShowing.dispose();
    _inputType.dispose();
    _sendButtonVisible.dispose();
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

  /// 处理发送按钮点击（异步发送，草稿清理，安全判断 mounted）
  Future<void> _handleSendPressed() async {
    final trimmedText = _textController.text.trim();
    if (trimmedText.isNotEmpty) {
      final res = await widget.onSendPressed(trimmedText);
      if (!mounted) return; // 异步gap后安全检查
      if (res) {
        _textController.clear();
        StorageService.to.remove(draftKey);
      }
    }
  }

  /// 统一对外收起所有面板（键盘、emoji、extra），并让输入区高度归零
  void hideAllPanel() {
    FocusScope.of(context).unfocus();
    _inputType.value = InputType.text;
    _emojiShowing.value = false;
    _composerHeight = widget.composerHeight;
  }

  /// 切换输入类型（文本/语音/表情/扩展面板），丝滑动画关键：直接设置高度
  Future<void> updateState(InputType type) async {
    if (type == _inputType.value) return;

    _inputType.value = type;
    _emojiShowing.value = type == InputType.emoji;

    // final isIOS = Platform.isIOS;

    if (type == InputType.text) {
      // 切换到文本输入，先收起面板，再唤起键盘，并同步高度
      _composerHeight.value = 0.0;
      // await Future.delayed(Duration(milliseconds: isIOS ? 100 : 60));
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_inputFocusNode);
      // 等待键盘弹起监听同步高度
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _updateComposerHeightByKeyboard(),
      );
    } else {
      // 切换到emoji/extra/voice，先收起键盘，再展示面板，并同步高度
      FocusScope.of(context).unfocus();
      // await Future.delayed(Duration(milliseconds: isIOS ? 100 : 60));
      if (!mounted) return;
      if (type == InputType.emoji || type == InputType.extra) {
        _composerHeight.value = _softKeyHeight;
      } else {
        _composerHeight.value = widget.composerHeight.value;
      }
    }
  }

  /// 构建语音按钮（未实现时弹出提示）
  Widget _buildVoiceButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () {
          // 暂未实现语音输入
          Get.snackbar('Tips', 'voice_input_not_implemented'.tr);
        },
        child: Text('chat_hold_down_talk'.tr),
      ),
    );
  }

  /// 构建底部容器（emoji/扩展面板，带动画）—— 丝滑高度逻辑已交由外部AnimatedPadding处理
  Widget _buildBottomContainer({required Widget child}) {
    return Offstage(
      // 根据输入类型决定是否显示
      offstage:
          _inputType.value != InputType.emoji &&
          _inputType.value != InputType.extra,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: max(_softKeyHeight, _keyboardHeight),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: IntrinsicHeight(child: child),
        ),
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
          final columns = Get.width ~/ (fontSize + 10);
          return ValueListenableBuilder<bool>(
            valueListenable: _emojiShowing,
            builder: (context, emojiShowing, _) {
              return Offstage(
                offstage: !emojiShowing,
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
                      backgroundColor: Get.isDarkMode
                          ? const Color.fromRGBO(34, 34, 34, 1.0)
                          : const Color.fromRGBO(246, 246, 246, 1.0),
                    ),
                    skinToneConfig: SkinToneConfig(
                      indicatorColor: Get.isDarkMode
                          ? const Color.fromRGBO(34, 34, 34, 1.0)
                          : const Color.fromRGBO(246, 246, 246, 1.0),
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      tabBarHeight: 48,
                      backgroundColor: Get.isDarkMode
                          ? const Color.fromRGBO(34, 34, 34, 1.0)
                          : const Color.fromRGBO(246, 246, 246, 1.0),
                      iconColorSelected: Theme.of(
                        context,
                      ).colorScheme.onPrimary,
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
                      backgroundColor: Get.isDarkMode
                          ? const Color.fromRGBO(35, 35, 35, 1.0)
                          : const Color.fromRGBO(246, 246, 246, 1.0),
                      buttonColor: Theme.of(context).colorScheme.surface,
                      buttonIconColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      buttonIconColor: Theme.of(context).colorScheme.onPrimary,
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

  /// 构建输入框（支持多行、emoji、安全选择等）
  Widget _buildInputField() {
    return TextField(
      controller: _textController,
      focusNode: _inputFocusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      enableInteractiveSelection: true,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        counterText: '',
      ),
      onChanged: (val) {
        _handleTextControllerChange();
      },
      onTap: () {
        updateState(InputType.text);
        widget.onTextFieldTap?.call();
      },
      onSubmitted: (_) => _handleSendPressed(),
    );
  }

  /// 构建语音输入组件（自定义或默认按钮）
  Widget _buildVoiceInput() {
    return widget.voiceWidget ?? _buildVoiceButton(context);
  }

  /// 构建输入按钮（文本/语音切换，Stack切换）
  Widget _buildInputButton() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        return Stack(
          children: [
            Offstage(
              offstage: inputType == InputType.voice,
              child: _buildInputField(),
            ),
            Offstage(
              offstage: inputType != InputType.voice,
              child: _buildVoiceInput(),
            ),
          ],
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
            _composerHeight.value = 0.0; // 切换语音时收起所有面板
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
    return ImageButton(
      image: const Icon(Icons.control_point, size: 40),
      onPressed: () {
        updateState(
          _inputType.value != InputType.extra
              ? InputType.extra
              : InputType.text,
        );
      },
    );
  }

  /// 构建发送按钮
  Widget _buildSendButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _sendButtonVisible,
      builder: (context, sendButtonVisible, _) {
        return Visibility(
          visible: sendButtonVisible,
          child: IconButton(
            icon: const Icon(Icons.send),
            onPressed: _handleSendPressed,
            padding: const EdgeInsets.only(left: 0),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = MediaQuery.of(context);
    // 处理底部安全区（兼容全面屏、刘海屏等场景）
    final bottomSafeArea = widget.handleSafeArea == true
        ? query.viewInsets.bottom + query.padding.bottom + 4
        : 0;

    _keyboardHeight = query.viewInsets.bottom;

    return Material(
      color: widget.backgroundColor,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          query.padding.left,
          4,
          query.padding.right,
          bottomSafeArea.toDouble(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.quoteTipsWidget ?? const SizedBox.shrink(),
            Row(
              children: [
                _buildLeftButton(),
                Expanded(child: _buildInputButton()),
                _buildEmojiButton(),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textController,
                  builder: (context, value, _) {
                    return value.text.isEmpty
                        ? _buildExtraButton()
                        : _buildSendButton();
                  },
                ),
              ],
            ),
            // 分隔线，仅在emoji/扩展面板展开时显示
            ValueListenableBuilder<InputType>(
              valueListenable: _inputType,
              builder: (context, inputType, _) {
                return inputType == InputType.emoji ||
                        inputType == InputType.extra
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: const HorizontalLine(),
                      )
                    : const SizedBox.shrink();
              },
            ),
            _buildBottomContainer(child: _buildBottomItems()),
          ],
        ),
      ),
    );
  }
}
