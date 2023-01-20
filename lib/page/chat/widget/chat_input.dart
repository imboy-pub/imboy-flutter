import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
// ignore: implementation_imports
import 'package:flutter_chat_ui/src/widgets/state/inherited_chat_theme.dart'
    show InheritedChatTheme;
import 'package:get/get.dart';
import 'package:imboy/component/ui/emoji_picker_view.dart';
import 'package:imboy/component/ui/image_button.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/message_model.dart';

/// 部分代码来自该项目，感谢作者 CaiJingLong https://github.com/CaiJingLong/flutter_like_wechat_input
enum InputType {
  text,
  voice,
  emoji,
  extra,
}

Widget _buildVoiceButton(BuildContext context) {
  return SizedBox(
    width: double.infinity,
    child: TextButton(
      // color: Colors.white70,
      onPressed: () {
        Get.snackbar('Tips', '语音输入功能暂无实现');
      },
      child: Text(
        'chat_hold_down_talk'.tr,
      ),
    ),
  );
}

InputType _initType = InputType.text;

double _softKeyHeight = 210;

class ChatInput extends StatefulWidget {
  const ChatInput({
    // super.key,
    Key? key,
    this.isAttachmentUploading,
    this.onAttachmentPressed,
    required this.onSendPressed,
    // this.options = const InputOptions(),
    // imboy add
    this.onTextChanged,
    this.onTextFieldTap,
    required this.sendButtonVisibilityMode,
    this.extraWidget,
    this.voiceWidget,
    // imboy add end
  }) : super(key: key);

  /// Whether attachment is uploading. Will replace attachment button with a
  /// [CircularProgressIndicator]. Since we don't have libraries for
  /// managing media in dependencies we have no way of knowing if
  /// something is uploading so you need to set this manually.
  final bool? isAttachmentUploading;

  /// See [AttachmentButton.onPressed].
  final VoidCallback? onAttachmentPressed;

  /// Will be called on [SendButton] tap. Has [types.PartialText] which can
  /// be transformed to [types.TextMessage] and added to the messages list.
  // final void Function(types.PartialText) onSendPressed;
  final Future<bool> Function(types.PartialText) onSendPressed;

  // /// Customisation options for the [Input].
  // final InputOptions options;

  // imboy add

  /// Will be called whenever the text inside [TextField] changes
  final void Function(String)? onTextChanged;

  /// Will be called on [TextField] tap
  final void Function()? onTextFieldTap;

  /// Controls the visibility behavior of the [SendButton] based on the
  /// [TextField] state inside the [Input] widget.
  /// Defaults to [SendButtonVisibilityMode.editing].
  final SendButtonVisibilityMode sendButtonVisibilityMode;

  final Widget? extraWidget;
  final Widget? voiceWidget;

  // imboy add end

  @override
  // ignore: library_private_types_in_public_api
  _ChatInputState createState() => _ChatInputState();
}

/// [Input] widget state
class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  double iconSize = 30;
  InputType inputType = _initType;
  final _inputFocusNode = FocusNode();
  bool sendButtonVisible = false;
  final _textController = TextEditingController();
  late AnimationController _bottomHeightController;

  bool emojiShowing = false;

  /// https://stackoverflow.com/questions/60057840/flutter-how-to-insert-text-in-middle-of-text-field-text
  void _setText(String val) {
    String text = _textController.text;
    TextSelection textSelection = _textController.selection;
    int start = textSelection.start > -1 ? textSelection.start : 0;
    String newText = text.replaceRange(
      start,
      textSelection.end > -1 ? textSelection.end : 0,
      val,
    );
    _textController.text = newText;
    int offset = start + val.length;
    _textController.selection = textSelection.copyWith(
      baseOffset: offset,
      extentOffset: offset,
    );
  }

  @override
  void initState() {
    super.initState();
    if (!mounted) {
      return;
    }
    if (widget.sendButtonVisibilityMode == SendButtonVisibilityMode.editing) {
      sendButtonVisible = _textController.text.trim() != '';
      _textController.addListener(_handleTextControllerChange);
    } else {
      sendButtonVisible = true;
    }

    _bottomHeightController = Get.put(AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 150,
      ),
    ));
    // 解决"重新进入聊天页面的时候_bottomHeightController在开启状态"的问题
    _bottomHeightController.animateBack(0);

    // 接收到新的消息订阅
    eventBus.on<ReEditMessage>().listen((msg) async {
      if (_textController.text.toString() != msg.text) {
        _setText(msg.text);
      }
    });
    //添加listener监听
    //对应的TextField失去或者获取焦点都会回调此监听
    _inputFocusNode.addListener(() {
      // debugPrint(">>> on chatinput ${_inputFocusNode.hasFocus}");
      if (_inputFocusNode.hasFocus) {
        updateState(InputType.text);
      } else {}
    });
  }

  @override
  void dispose() {
    Get.delete<AnimationController>();
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSendPressed() async {
    final trimmedText = _textController.text.trim();
    if (trimmedText != '') {
      bool res = await widget.onSendPressed(types.PartialText(text: trimmedText));
      if (res) {
        _textController.clear();
      } else {
        WSService.to.openSocket();
        // 网络原因，发送失败
      }
    }
  }

  void _handleTextControllerChange() {
    setState(() {
      sendButtonVisible = _textController.text.trim() != '';
    });
  }

  void changeBottomHeight(final double height) {
    if (height > 0) {
      _bottomHeightController.animateTo(1);
    } else {
      _bottomHeightController.animateBack(0);
    }
  }

  /// 语音按钮事件
  Future<void> _voiceBtnOnPressed(InputType type) async {
    if (type == inputType) {
      return;
    }
    if (type != InputType.text) {
      hideSoftKey();
    } else {
      showSoftKey();
    }

    setState(() {
      inputType = type;
    });
  }

  Future<void> updateState(InputType type) async {
    if (type == InputType.text || type == InputType.voice) {
      _initType = type;
    }
    if (type == inputType) {
      return;
    }
    inputType = type;
    // InputTypeNotification(type).dispatch(context);

    if (type != InputType.text) {
      hideSoftKey();
    } else {
      showSoftKey();
    }

    if (type == InputType.emoji || type == InputType.extra) {
      changeBottomHeight(1);
      hideSoftKey();
    } else {
      changeBottomHeight(0);
    }

    setState(() {
      emojiShowing = type == InputType.emoji;
      inputType;
    });
  }

  void showSoftKey() {
    FocusScope.of(context).requestFocus(_inputFocusNode);
    changeBottomHeight(0);
    // debugPrint(">>> on chatinput showSoftKey");
  }

  void hideSoftKey() {
    _inputFocusNode.unfocus();

    // 隐藏键盘而不丢失文本字段焦点：from https://developer.aliyun.com/article/763095
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  Widget _buildBottomContainer({required Widget child}) {
    return SizeTransition(
      sizeFactor: _bottomHeightController,
      child: SizedBox(
        // ignore: sort_child_properties_last
        child: child,
        height: _softKeyHeight,
      ),
    );
  }

  Widget _buildBottomItems() {
    if (inputType == InputType.extra) {
      return widget.extraWidget ?? const Center(child: Text("其他item"));
    } else if (inputType == InputType.emoji) {
      return Offstage(
        offstage: !emojiShowing,
        child: SizedBox(
          height: 400,
          child: EmojiPicker(
            onEmojiSelected: (Category? category, Emoji emoji) {
              _setText(emoji.emoji);
            },
            onBackspacePressed: () {
              _textController
                ..text = _textController.text.characters.skipLast(1).toString()
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
            },
            config: Config(
              columns: 7,
              // Issue: https://github.com/flutter/flutter/issues/28894
              emojiSizeMax: 24 * (GetPlatform.isIOS ? 1.30 : 1.0),
              verticalSpacing: 0,
              horizontalSpacing: 0,
              initCategory: Category.RECENT,
              bgColor: const Color(0xFFF2F2F2),
              indicatorColor: Colors.black87,
              iconColorSelected: Colors.black87,
              iconColor: Colors.grey,
              backspaceColor: Colors.black54,
              showRecentsTab: true,
              recentsLimit: 19,
              // noRecentsText: 'No Recents'.tr,
              // noRecentsStyle: const TextStyle(
              //   fontSize: 20,
              //   color: Colors.black87,
              // ),
              tabIndicatorAnimDuration: kTabScrollDuration,
              categoryIcons: const CategoryIcons(),
              buttonMode: ButtonMode.MATERIAL,
            ),
            customWidget: (Config config, EmojiViewState state) =>
                EmojiPickerView(
              config,
              state,
              _handleSendPressed,
            ),
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  Widget _buildInputButton(BuildContext ctx) {
    final voiceButton = widget.voiceWidget ?? _buildVoiceButton(ctx);
    final inputButton = TextField(
      controller: _textController,
      cursorColor: InheritedChatTheme.of(ctx).theme.inputTextCursorColor,
      decoration: InheritedChatTheme.of(ctx).theme.inputTextDecoration.copyWith(
            hintStyle: InheritedChatTheme.of(ctx).theme.inputTextStyle.copyWith(
                  color: InheritedChatTheme.of(ctx)
                      .theme
                      .inputTextColor
                      .withOpacity(0.5),
                ),
            hintText: '',
          ),
      focusNode: _inputFocusNode,
      // maxLength: 400,
      maxLines: 6,
      minLines: 1,
      // 长按是否展示【剪切/复制/粘贴菜单LengthLimitingTextInputFormatter】
      enableInteractiveSelection: true,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      onChanged: widget.onTextChanged,
      onTap: () {
        updateState(inputType);
        widget.onTextFieldTap;
      },
      style: InheritedChatTheme.of(ctx).theme.inputTextStyle.copyWith(
            color: InheritedChatTheme.of(ctx).theme.inputTextColor,
          ),
      // 点击键盘的动作按钮时的回调，参数为当前输入框中的值
      onSubmitted: (_) => _handleSendPressed(),
    );

    return Stack(
      children: <Widget>[
        Offstage(
          // ignore: sort_child_properties_last
          child: inputButton,
          offstage: inputType == InputType.voice,
        ),
        Offstage(
          // ignore: sort_child_properties_last
          child: voiceButton,
          offstage: inputType != InputType.voice,
        ),
      ],
    );
  }

  Widget buildLeftButton() {
    return ImageButton(
      onPressed: () {
        if (inputType == InputType.voice) {
          _voiceBtnOnPressed(InputType.text);
        } else {
          _voiceBtnOnPressed(InputType.voice);
        }
        changeBottomHeight(0);
      },
      // image: AssetImage(
      //   inputType != InputType.voice
      //       ? 'assets/images/chat/input_voice.png'
      //       : 'assets/images/chat/input_keyboard.png',
      // ),
        image: inputType != InputType.voice ? Icon(Icons.keyboard_voice_outlined, size: iconSize)
            : Icon(Icons.keyboard_alt_outlined, size: iconSize),
    );
  }

  ///
  Widget buildEmojiButton() {
    return ImageButton(
      // image: AssetImage(inputType != InputType.emoji
      //     ? 'assets/images/chat/input_emoji.png'
      //     : 'assets/images/chat/input_keyboard.png'),
      image: inputType != InputType.emoji ? Icon(Icons.emoji_emotions_outlined, size: iconSize)
          : Icon(Icons.keyboard_alt_outlined, size: iconSize),
      onPressed: () {
        if (inputType != InputType.emoji) {
          updateState(InputType.emoji);
        } else {
          updateState(InputType.text);
        }
      },
    );
  }

  /// 更多输入消息类型入口
  /// More input message types entries
  Widget buildExtra() {
    return ImageButton(
      // image: const AssetImage('assets/images/chat/input_extra.png'),
      image: Icon(Icons.control_point, size: iconSize),
      onPressed: () {
        if (inputType != InputType.extra) {
          updateState(InputType.extra);
        } else {
          updateState(InputType.text);
        }
      },
    );
  }

  /// 实现换行效果
  /// Implement line breaks
  // void _handleNewLine() {
  //   final _newValue = '${_textController.text}\r\n';
  //   _textController.value = TextEditingValue(
  //     text: _newValue,
  //     selection: TextSelection.fromPosition(
  //       TextPosition(offset: _newValue.length),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final query = MediaQuery.of(context);

    return InkWell(
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: InheritedChatTheme.of(context).theme.inputPadding,
          child: Material(
            borderRadius:
                InheritedChatTheme.of(context).theme.inputBorderRadius,
            color: InheritedChatTheme.of(context).theme.inputBackgroundColor,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                query.padding.left,
                4,
                query.padding.right,
                4 + query.viewInsets.bottom + query.padding.bottom,
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: [
                      // voice
                      buildLeftButton(),
                      // input
                      Expanded(
                        child: _buildInputButton(context),
                      ),
                      // emoji
                      buildEmojiButton(),
                      //extra
                      _textController.text.isEmpty
                          ? buildExtra()
                          : IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _handleSendPressed,
                              padding: const EdgeInsets.only(left: 0),
                            ),
                    ],
                  ),
                  inputType == InputType.emoji || inputType == InputType.extra
                      ? const Divider()
                      : const SizedBox.shrink(), // 横线
                  _buildBottomContainer(child: _buildBottomItems()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
