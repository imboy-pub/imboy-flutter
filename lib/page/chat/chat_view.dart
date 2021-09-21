import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/chat/chat_details_body.dart';
import 'package:imboy/component/ui/chat/chat_details_row.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/edit/emoji_text.dart';
import 'package:imboy/component/ui/edit/text_span.dart';
import 'package:imboy/component/view/indicator_page_view.dart';
import 'package:imboy/component/view/main_input.dart';
import 'package:imboy/component/widget/item/chat_more_icon.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/helper/constant.dart';
import 'package:imboy/helper/win_media.dart';
import 'package:imboy/page/chat_info/chat_info_view.dart';
import 'package:imboy/page/chat_more/chat_more_view.dart';
import 'package:imboy/page/group_detail/group_detail_view.dart';

import 'chat_logic.dart';
import 'chat_state.dart';

class ChatPage extends StatefulWidget {
  final String? id; // 用户ID
  final String? type; // [C2C | GROUP]
  final String? title;

  ChatPage({
    required this.id,
    this.type = 'C2C',
    this.title,
  });

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final logic = Get.put(ChatLogic());
  final ChatState state = Get.find<ChatLogic>().state;

  // EventBus _msgStreamSubs;
  bool _isVoice = false;
  bool _isMore = false;
  double keyboardHeight = 270.0;
  bool _emojiState = false;
  String? newGroupName;

  TextEditingController _textController = TextEditingController();
  FocusNode _focusNode = new FocusNode();
  ScrollController _sC = ScrollController();
  PageController pageC = new PageController();

  @override
  void initState() {
    super.initState();
    _sC.addListener(() => FocusScope.of(context).requestFocus(new FocusNode()));

    initPlatformState();
    logic.getChatMsgData();
    if (mounted) setState(() {});

    // Notice.addListener(ChatActions.msg(), (v) => getChatMsgData());
    // bus.on<MessageModel>().listen((event) {
    //   getChatMsgData();
    // });
    // if (widget.type == 'GROUP') {
    //   bus.on<MessageModel>().listen((event) {
    //     setState(() => newGroupName = event.type);
    //   });
    // }
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _emojiState = false;
    });
  }

  void insertText(String text) {
    var value = _textController.value;
    var start = value.selection.baseOffset;
    var end = value.selection.extentOffset;
    if (value.selection.isValid) {
      String newText = '';
      if (value.selection.isCollapsed) {
        if (end > 0) {
          newText += value.text.substring(0, end);
        }
        newText += text;
        if (value.text.length > end) {
          newText += value.text.substring(end, value.text.length);
        }
      } else {
        newText = value.text.replaceRange(start, end, text);
        end = start;
      }

      _textController.value = value.copyWith(
          text: newText,
          selection: value.selection.copyWith(
              baseOffset: end + text.length, extentOffset: end + text.length));
    } else {
      _textController.value = TextEditingValue(
          text: text,
          selection:
              TextSelection.fromPosition(TextPosition(offset: text.length)));
    }
  }

  void canCelListener() {
    // if (_msgStreamSubs != null) {
    //   _msgStreamSubs.destroy();
    // }
  }

  Future<void> initPlatformState() async {
    if (!mounted) {
      return;
    }

    // if (_msgStreamSubs == null) {
    //   // Register listeners for all events:
    //   _msgStreamSubs = (new EventBus()).on().listen((e) {
    //     String dtype = e['type'] ?? 'error';
    //     debugPrint(">>>>>>>>>>>>>>>>>>> on _msgStreamSubs ${e}");
    //     // {"type":"C2C","from":"18aw3p","to":"kybqdp","payload":{"msg_type":10,"content":"b1","send_ts":1596502941380},"server_ts":1596502941499}
    //     switch (dtype.toUpperCase()) {
    //       case 'C2C':
    //         chatData.insert(0, MessageModel.fromMap(e));
    //         break;
    //     }
    //   }) as EventBus;
    // }
  }

  onTapHandle(ButtonType type) {
    setState(() {
      if (type == ButtonType.voice) {
        _focusNode.unfocus();
        _isMore = false;
        _isVoice = !_isVoice;
      } else {
        _isVoice = false;
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
          _isMore = true;
        } else {
          _isMore = !_isMore;
        }
      }
      _emojiState = false;
    });
  }

  Widget edit(context, size) {
    // 计算当前的文本需要占用的行数
    TextSpan _text = TextSpan(
      text: _textController.text,
      style: AppStyles.ChatBoxTextStyle,
    );

    TextPainter _tp = TextPainter(
      text: _text,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
    _tp.layout(maxWidth: size.maxWidth);

    return ExtendedTextField(
      specialTextSpanBuilder: TextSpanBuilder(showAtBackground: true),
      onTap: () => setState(() {
        if (_focusNode.hasFocus) _emojiState = false;
      }),
      onChanged: (v) => setState(() {}),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(5.0),
      ),
      controller: _textController,
      focusNode: _focusNode,
      maxLines: 99,
      cursorColor: const Color(AppColors.ChatBoxCursorColor),
      style: AppStyles.ChatBoxTextStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (keyboardHeight == 270.0 &&
        MediaQuery.of(context).viewInsets.bottom != 0) {
      keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    }
    var body = [
      state.chatData != null
          ? new ChatDetailsBody(sC: _sC, msgs: state.chatData)
          : new Spacer(),
      new ChatDetailsRow(
        voiceOnTap: () => onTapHandle(ButtonType.voice),
        onEmojio: () {
          if (_isMore) {
            _emojiState = true;
          } else {
            _emojiState = !_emojiState;
          }
          if (_emojiState) {
            FocusScope.of(context).requestFocus(new FocusNode());
            _isMore = false;
          }
          setState(() {});
        },
        isVoice: _isVoice,
        edit: edit,
        more: new ChatMoreIcon(
          value: _textController.text,
          onTap: () => logic.handleSubmittedData(
            widget.type!,
            widget.id!,
            _textController.text,
          ),
          moreTap: () => onTapHandle(ButtonType.more),
        ),
        id: widget.id,
        type: widget.type,
      ),
      new Visibility(
        visible: _emojiState,
        child: emojiWidget(),
      ),
      new Container(
        height: _isMore && !_focusNode.hasFocus ? keyboardHeight : 0.0,
        width: winWidth(context),
        color: Color(AppColors.ChatBoxBg),
        child: new IndicatorPageView(
          pageC: pageC,
          pages: List.generate(2, (index) {
            return new ChatMorePage(
              index: index,
              id: widget.id!,
              type: widget.type!,
              keyboardHeight: keyboardHeight,
            );
          }),
        ),
      ),
    ];

    var rWidget = [
      new InkWell(
        child: new Image(image: AssetImage('assets/images/right_more.png')),
        onTap: () => Get.to(widget.type == 'GROUP'
            ? GroupDetailPage(
                widget.id ?? widget.title,
                callBack: (v) {},
              )
            : ChatInfoPage(widget.id!)),
      )
    ];

    return Scaffold(
      appBar: new PageAppBar(
        title: newGroupName ?? widget.title,
        rightDMActions: rWidget,
      ),
      body: new MainInputBody(
        onTap: () => setState(
          () {
            _isMore = false;
            _emojiState = false;
          },
        ),
        decoration: BoxDecoration(color: chatBg),
        child: new Column(children: body),
      ),
    );
  }

  Widget emojiWidget() {
    return new GestureDetector(
      child: new SizedBox(
        height: _emojiState ? keyboardHeight : 0,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return GestureDetector(
              child: Image(
                image:
                    AssetImage(EmojiUitl.instance.emojiMap["[${index + 1}]"]!),
              ),
              behavior: HitTestBehavior.translucent,
              onTap: () {
                insertText("[${index + 1}]");
              },
            );
          },
          itemCount: EmojiUitl.instance.emojiMap.length,
          padding: EdgeInsets.all(5.0),
        ),
      ),
      onTap: () {},
    );
  }

  @override
  void dispose() {
    Get.delete<ChatLogic>();

    canCelListener();
    // Notice.removeListenerByEvent(ChatActions.msg());
    // Notice.removeListenerByEvent(ChatActions.groupName());

    super.dispose();
  }
}
