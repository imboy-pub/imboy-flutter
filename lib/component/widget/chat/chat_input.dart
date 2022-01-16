import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:emoji_picker_flutter/src/emoji_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_ui/src/widgets/inherited_chat_theme.dart';
import 'package:get/get.dart';
import 'package:imboy/component/widget/chat/emoji_picker.dart';
import 'package:imboy/config/const.dart';
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

  StreamSubscription<dynamic>? _msgStreamSubs;

  /**
   * https://stackoverflow.com/questions/60057840/flutter-how-to-insert-text-in-middle-of-text-field-text
   */
  void _setText(String val) {
    String text = _textController.text;
    TextSelection textSelection = _textController.selection;
    String newText = text.replaceRange(
      textSelection.start,
      textSelection.end,
      val,
    );
    final len = val.length;
    _textController.text = newText;
    _textController.selection = textSelection.copyWith(
      baseOffset: textSelection.start + len,
      extentOffset: textSelection.start + len,
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
    _msgStreamSubs = eventBus.on<ReeditMessage>().listen((msg) async {
      debugPrint(">>> on reedit ${msg.toString()}");
      if (_textController.text.toString() != msg.text) {
        _setText(msg.text);
      }
    });
  }

  @override
  void dispose() {
    if (_msgStreamSubs != null) {
      _msgStreamSubs!.cancel();
      _msgStreamSubs = null;
    }

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

  /**
   * 表情符号按钮事件
   */
  Future<void> _emojiBtnOnPressed(InputType type) async {
    if (type == inputType) {
      return;
    }
    this.inputType = type;
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

  Future<void> updateState(InputType type) async {
    // if (type == InputType.text || type == InputType.voice) {
    //   _initType = type;
    // }
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

    setState(() {});
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
          height: 250,
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
              recentsLimit: 28,
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
      onTap: widget.onTextFieldTap,
      style: InheritedChatTheme.of(ctx).theme.inputTextStyle.copyWith(
            color: InheritedChatTheme.of(ctx).theme.inputTextColor,
          ),
      textCapitalization: TextCapitalization.sentences,
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

  @override
  Widget build(BuildContext context) {
    final _query = MediaQuery.of(context);

    return GestureDetector(
      onTap: () => _inputFocusNode.requestFocus(),
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.enter): const SendMessageIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter, LogicalKeyboardKey.alt):
              const NewLineIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter, LogicalKeyboardKey.shift):
              const NewLineIntent(),
        },
        child: Actions(
          actions: {
            SendMessageIntent: CallbackAction<SendMessageIntent>(
              onInvoke: (SendMessageIntent intent) => _handleSendPressed(),
            ),
            NewLineIntent: CallbackAction<NewLineIntent>(
              onInvoke: (NewLineIntent intent) {
                final _newValue = '${_textController.text}\r\n';
                _textController.value = TextEditingValue(
                  text: _newValue,
                  selection: TextSelection.fromPosition(
                    TextPosition(offset: _newValue.length),
                  ),
                );
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Padding(
              padding: InheritedChatTheme.of(context).theme.inputPadding,
              child: Material(
                borderRadius:
                    InheritedChatTheme.of(context).theme.inputBorderRadius,
                color:
                    InheritedChatTheme.of(context).theme.inputBackgroundColor,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    0 + _query.padding.left,
                    0,
                    0 + _query.padding.right,
                    2 + _query.viewInsets.bottom + _query.padding.bottom,
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: [
                          // voice
                          IconButton(
                            onPressed: () {
                              if (inputType == InputType.voice) {
                                _voiceBtnOnPressed(InputType.text);
                              } else {
                                _voiceBtnOnPressed(InputType.voice);
                              }
                            },
                            icon: Icon(
                              (inputType != InputType.voice
                                  ? Icons.keyboard_voice_outlined
                                  : Icons.keyboard),
                              color: AppColors.ButtonTextColor,
                              size: 32.0,
                            ),
                            iconSize: 12,
                            padding: const EdgeInsets.only(
                              left: 0.0,
                              top: 0.0,
                              right: 8.0,
                              bottom: 0.0,
                            ),
                            alignment: Alignment.centerRight,
                          ),
                          // input
                          Expanded(
                            child: _buildInputButton(context),
                          ),
                          // emoji
                          IconButton(
                            onPressed: () {
                              if (inputType != InputType.emoji) {
                                _emojiBtnOnPressed(InputType.emoji);
                              } else {
                                _emojiBtnOnPressed(InputType.text);
                              }
                            },
                            icon: Icon(
                              (inputType != InputType.emoji
                                  ? Icons.emoji_emotions_outlined
                                  : Icons.keyboard),
                              color: AppColors.ButtonTextColor,
                              size: 32.0,
                            ),
                            tooltip: "",
                            iconSize: 1,
                            padding: const EdgeInsets.all(0.0),
                            // alignment: Alignment.centerRight,
                          ),
                          //extra
                          IconButton(
                            // send
                            // onPressed: _handleSendPressed,
                            onPressed: () => updateState(InputType.extra),
                            icon: const Icon(
                              Icons.add_circle_outline_outlined,
                              color: AppColors.ButtonTextColor,
                              size: 32.0,
                            ),
                            tooltip: "",
                            iconSize: 4,
                            padding: const EdgeInsets.all(0.0),
                          ),
                        ],
                      ),
                      _buildBottomContainer(child: _buildBottomItems()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
