import 'dart:async';
import 'dart:io';

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
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/emoji_picker_view.dart';
import 'package:imboy/component/ui/image_button.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:niku/namespace.dart' as n;

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
      onPressed: () {
        Get.snackbar('Tips', 'voice_input_not_implemented'.tr);
      },
      child: Text(
        'chat_hold_down_talk'.tr,
      ),
    ),
  );
}

InputType _initType = InputType.text;

double _softKeyHeight = 198;
double fontSize = 22 * (Platform.isIOS ? 1.2 : 1.0);

class ChatInput extends StatefulWidget {
  const ChatInput({
    // super.key,
    super.key,
    required this.type,
    required this.peerId,
    required this.onSendPressed,
    required this.sendButtonVisibilityMode,
    this.isAttachmentUploading,
    this.onAttachmentPressed,
    // this.options = const InputOptions(),
    // imboy add
    this.onTextChanged,
    this.onTextFieldTap,
    this.extraWidget,
    this.voiceWidget,
    this.quoteTipsWidget,
    // imboy add end
  });

  final String type; // [C2C | C2G | C2S]
  final String peerId;

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

  final Widget? quoteTipsWidget;

  // imboy add end

  @override
  // ignore: library_private_types_in_public_api
  _ChatInputState createState() => _ChatInputState();
}

/// [Input] widget state
class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final _inputFocusNode = FocusNode();
  final _textController = TextEditingController();
  late AnimationController _bottomHeightController;

  double iconSize = 40;
  bool emojiShowing = false;
  bool sendButtonVisible = false;
  InputType inputType = _initType;
  late String draftKey;

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
    draftKey = "draft${widget.type}_${widget.peerId}";
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


    String? draft = StorageService.to.getString(draftKey);
    if (strNoEmpty(draft)) {
      _setText(draft!);
    }
    // 接收到新的消息订阅
    eventBus.on<ReEditMessage>().listen((msg) async {
      if (_textController.text.toString() != msg.text) {
        _setText(msg.text);
      }
    });
    //添加listener监听
    //对应的TextField失去或者获取焦点都会回调此监听
    _inputFocusNode.addListener(() {
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
    _bottomHeightController.dispose();
    super.dispose();
  }

  Future<void> _handleSendPressed() async {
    final trimmedText = _textController.text.trim();
    if (trimmedText != '') {
      bool res =
          await widget.onSendPressed(types.PartialText(text: trimmedText));
      if (res) {
        _textController.clear();
        StorageService.to.remove(draftKey);
      } else {
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
      int columns = Get.width ~/ (fontSize + 10);
      return Offstage(
        offstage: !emojiShowing,
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
            checkPlatformCompatibility: true,
            // emojiTextStyle: TextStyle(fontSize: fontSize),
            emojiViewConfig: EmojiViewConfig(
              columns: columns,
              emojiSizeMax: fontSize,
              verticalSpacing: 0,
              horizontalSpacing: 4,
              recentsLimit: columns * 3 - 2,
              // tabIndicatorAnimDuration: kTabScrollDuration,
              // categoryIcons: const CategoryIcons(),
              buttonMode: ButtonMode.MATERIAL,
              backgroundColor: Get.isDarkMode
                  ? const Color.fromRGBO(34, 34, 34, 1.0)
                  : const Color.fromRGBO(246, 246, 246, 1.0),
            ),
            swapCategoryAndBottomBar: true,
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
              // dividerColor: Colors.white,
              // indicatorColor: AppColors.primaryElement,
              iconColorSelected: Theme.of(context).colorScheme.onPrimary,
              // iconColor: AppColors.tabBarElement,
              customCategoryView: (
                config,
                state,
                tabController,
                pageController,
              ) {
                return EmojiCategoryView(
                  config,
                  state,
                  tabController,
                  pageController,
                );
              },
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
              // showSearchViewButton: false,
              backgroundColor: Get.isDarkMode
                  ? const Color.fromRGBO(35, 35, 35, 1.0)
                  : const Color.fromRGBO(246, 246, 246, 1.0),
              buttonColor: Theme.of(context).colorScheme.surface,
              buttonIconColor: Theme.of(context).colorScheme.onPrimary,
              customBottomActionBar: (
                config,
                state,
                showEmojiView,
              ) {
                return AppBottomActionBar(config, state, showEmojiView);
              },
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Theme.of(context).colorScheme.surface,
              buttonIconColor: Theme.of(context).colorScheme.onPrimary,
              customSearchView: (
                config,
                state,
                showEmojiView,
              ) {
                return EmojiSearchView(
                  config,
                  state,
                  showEmojiView,
                );
              },
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
                  color: InheritedChatTheme.of(ctx).theme.inputTextColor,
                  // color: Colors.red,
                ),
            fillColor:
                Get.isDarkMode ? darkInputFillColor : lightInputFillColor,
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
      onChanged: (String val) {
        StorageService.to.setString(draftKey, val);
        if (widget.onTextChanged != null) widget.onTextChanged!(val);
      },
      onTap: () {
        updateState(inputType);
        widget.onTextFieldTap;
      },
      style: InheritedChatTheme.of(ctx).theme.inputTextStyle.copyWith(
          color: InheritedChatTheme.of(ctx).theme.inputTextColor,
          // backgroundColor: Colors.red,
          height: 1.8,
          fontSize: fontSize),
      // 点击键盘的动作按钮时的回调，参数为当前输入框中的值
      onSubmitted: (_) => _handleSendPressed(),
    );

    return n.Stack([
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
    ]);
  }

  Widget buildLeftButton() {
    return ImageButton(
      width: 48,
      height: 48,
      onPressed: () {
        if (inputType == InputType.voice) {
          _voiceBtnOnPressed(InputType.text);
        } else {
          _voiceBtnOnPressed(InputType.voice);
        }
        changeBottomHeight(0);
      },
      image: inputType != InputType.voice
          ? Icon(Icons.keyboard_voice_outlined, size: iconSize)
          : Icon(Icons.keyboard_alt_outlined, size: iconSize),
    );
  }

  ///
  Widget buildEmojiButton() {
    return ImageButton(
      image: inputType != InputType.emoji
          ? Icon(Icons.emoji_emotions_outlined, size: iconSize)
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

    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: InkWell(
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
                  query.viewInsets.bottom + query.padding.bottom + 4,
                ),
                child: n.Column([
                  widget.quoteTipsWidget ?? const SizedBox.shrink(),
                  n.Row([
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
                  ]),
                  inputType == InputType.emoji || inputType == InputType.extra
                      ? n.Padding(top: 4, child: const HorizontalLine())
                      : const SizedBox.shrink(), // 横线
                  _buildBottomContainer(child: _buildBottomItems()),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
