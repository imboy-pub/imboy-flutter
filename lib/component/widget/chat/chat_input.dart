import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:emoji_picker_flutter/src/emoji_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_ui/src/widgets/inherited_chat_theme.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/image_button.dart';
import 'package:imboy/component/view/emoji_picker_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/message_model.dart';

/**
 * 部分代码来自该项目，感谢作者 CaiJingLong https://github.com/CaiJingLong/flutter_like_wechat_input
 */
enum InputType {
  text,
  voice,
  emoji,
  extra,
}

Widget _buildVoiceButton(BuildContext context) {
  return Container(
    width: double.infinity,
    child: FlatButton(
      color: Colors.white70,
      onPressed: () {
        Get.snackbar('Tips', '语音输入功能暂无实现');
      },
      child: Text('chat_hold_down_talk'.tr),
    ),
  );
}

typedef void OnSend(String text);

InputType _initType = InputType.text;

double _softKeyHeight = 200;

class ChatInput extends StatefulWidget {
  const ChatInput({
    Key? key,
    this.isAttachmentUploading,
    this.onAttachmentPressed,
    required this.onSendPressed,
    this.onTextChanged,
    this.onTextFieldTap,
    required this.sendButtonVisibilityMode,
    this.extraWidget,
    this.voiceWidget,
  }) : super(key: key);

  /// See [AttachmentButton.onPressed]
  final void Function()? onAttachmentPressed;

  /// Whether attachment is uploading. Will replace attachment button with a
  /// [CircularProgressIndicator]. Since we don't have libraries for
  /// managing media in dependencies we have no way of knowing if
  /// something is uploading so you need to set this manually.
  final bool? isAttachmentUploading;

  /// Will be called on [SendButton] tap. Has [types.PartialText] which can
  /// be transformed to [types.TextMessage] and added to the messages list.
  final Future<bool> Function(types.PartialText) onSendPressed;

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

  @override
  _ChatInputState createState() => _ChatInputState();
}

/// [Input] widget state
class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  InputType inputType = _initType;
  final _inputFocusNode = FocusNode();
  bool _sendButtonVisible = false;
  final _textController = TextEditingController();
  late AnimationController _bottomHeightController;

  bool emojiShowing = false;

  /**
   * https://stackoverflow.com/questions/60057840/flutter-how-to-insert-text-in-middle-of-text-field-text
   */
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
      _sendButtonVisible = _textController.text.trim() != '';
      _textController.addListener(_handleTextControllerChange);
    } else {
      _sendButtonVisible = true;
    }
    _bottomHeightController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 150,
      ),
    );
    // 接收到新的消息订阅
    eventBus.on<ReeditMessage>().listen((msg) async {
      debugPrint(">>> on reedit ${msg.toString()}");
      if (_textController.text.toString() != msg.text) {
        _setText(msg.text);
      }
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSendPressed() async {
    final trimmedText = _textController.text.trim();
    if (trimmedText != '') {
      final _partialText = types.PartialText(text: trimmedText);
      bool res = await widget.onSendPressed(_partialText);
      debugPrint(">>> on _handleSendPressed res ${res.toString()}");
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
      _sendButtonVisible = _textController.text.trim() != '';
    });
  }

  void changeBottomHeight(final double height) {
    if (height > 0) {
      _bottomHeightController.animateTo(1);
    } else {
      _bottomHeightController.animateBack(0);
    }
  }

  /**
   * 语音按钮事件
   */
  Future<void> _voiceBtnOnPressed(InputType type) async {
    if (type == inputType) {
      return;
    }
    this.inputType = type;
    if (type != InputType.text) {
      hideSoftKey();
    } else {
      showSoftKey();
    }

    changeBottomHeight(0);
    setState(() {
      this.inputType;
    });
  }

  Future<void> updateState(InputType type) async {
    if (type == InputType.text || type == InputType.voice) {
      _initType = type;
    }
    if (type == inputType) {
      return;
    }
    this.inputType = type;
    // InputTypeNotification(type).dispatch(context);

    if (type != InputType.text) {
      hideSoftKey();
    } else {
      showSoftKey();
    }

    if (type == InputType.emoji || type == InputType.extra) {
      // _currentOtherHeight = _softKeyHeight;
      changeBottomHeight(1);
    } else {
      changeBottomHeight(0);
      // _currentOtherHeight = 0;
    }

    setState(() {
      this.emojiShowing = type == InputType.emoji;
      this.inputType;
    });
  }

  void showSoftKey() {
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  void hideSoftKey() {
    _inputFocusNode.unfocus();
  }

  Widget _buildBottomContainer({required Widget child}) {
    return SizeTransition(
      sizeFactor: _bottomHeightController,
      child: Container(
        child: child,
        height: _softKeyHeight,
      ),
    );
  }

  Widget _buildBottomItems() {
    if (this.inputType == InputType.extra) {
      return widget.extraWidget ?? Center(child: Text("其他item"));
    } else if (this.inputType == InputType.emoji) {
      return Offstage(
        offstage: !emojiShowing,
        child: SizedBox(
          height: 400,
          child: EmojiPicker(
            onEmojiSelected: (Category category, Emoji emoji) {
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
              progressIndicatorColor: Colors.blue,
              backspaceColor: Colors.black54,
              showRecentsTab: true,
              recentsLimit: 19,
              noRecentsText: 'No Recents',
              noRecentsStyle: const TextStyle(
                fontSize: 20,
                color: Colors.black87,
              ),
              tabIndicatorAnimDuration: kTabScrollDuration,
              categoryIcons: const CategoryIcons(),
              buttonMode: ButtonMode.MATERIAL,
            ),
            customWidget: (Config config, EmojiViewState state) =>
                EmojiPickerView(config, state, _handleSendPressed),
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
            hintText: 'tip_chat_hint'.tr,
          ),
      focusNode: _inputFocusNode,
      keyboardType: TextInputType.multiline,
      maxLines: 5,
      minLines: 1,
      onChanged: widget.onTextChanged,
      onTap: () {
        if (inputType != InputType.emoji) {
          updateState(InputType.text);
        } else {
          hideSoftKey();
          updateState(InputType.emoji);
        }
        widget.onTextFieldTap;
      },
      style: InheritedChatTheme.of(ctx).theme.inputTextStyle.copyWith(
            color: InheritedChatTheme.of(ctx).theme.inputTextColor,
          ),
      // 长按是否展示【剪切/复制/粘贴菜单LengthLimitingTextInputFormatter】
      enableInteractiveSelection: true,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      // 点击键盘的动作按钮时的回调，参数为当前输入框中的值
      onSubmitted: (_) => _handleSendPressed(),
    );

    return Stack(
      children: <Widget>[
        Offstage(
          child: inputButton,
          offstage: inputType == InputType.voice,
        ),
        Offstage(
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
      },
      image: AssetImage(
        inputType != InputType.voice
            ? 'assets/images/chat/voice.png'
            : 'assets/images/chat/keyboard.png',
      ),
    );
  }

  Widget buildEmojiButton() {
    return ImageButton(
      image: AssetImage(inputType != InputType.emoji
          ? 'assets/images/chat/emoji.png'
          : 'assets/images/chat/keyboard.png'),
      onPressed: () {
        if (inputType != InputType.emoji) {
          updateState(InputType.emoji);
        } else {
          updateState(InputType.text);
        }
      },
    );
  }

  Widget buildExtra() {
    return ImageButton(
      image: AssetImage('assets/images/chat/extra.png'),
      onPressed: () => updateState(InputType.extra),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _query = MediaQuery.of(context);

    return GestureDetector(
      onTap: () {
        debugPrint(">>> on chat_input build");
        _inputFocusNode.requestFocus();
      },
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
                _query.padding.left,
                4,
                _query.padding.right,
                4 + _query.viewInsets.bottom + _query.padding.bottom,
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
                      buildExtra(),
                    ],
                  ),
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
