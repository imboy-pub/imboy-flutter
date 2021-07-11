import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/api/dialog_api.dart';
import 'package:imboy/component/view/indicator_page_view.dart';
import 'package:imboy/component/view/pop_view.dart';
import 'package:imboy/component/widget/chat/conversation_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/constant.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/store/model/message_model.dart';

import 'home_logic.dart';
import 'home_state.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final logic = Get.put(HomeLogic());

  final HomeState state = Get.find<HomeLogic>().state;

  List<MessageModel> _chatData = [];

  var tapPos;

  StreamSubscription<dynamic> _messageStreamSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    getChatData();
  }

  void canCelListener() {
    if (_messageStreamSubscription != null) {
      _messageStreamSubscription.cancel();
    }
  }

  Future<void> initPlatformState() async {
    if (!mounted) {
      return;
    }

    if (_messageStreamSubscription == null) {
      // _messageStreamSubscription = im.ws.onMessage.listen((dynamic onData) => getChatData());
    }
  }

  Future getChatData() async {
    final str = await getConversationsListData();
    List<MessageModel> listChat = str;
    if (listEmpty(listChat)) {
      return;
    }
    _chatData.clear();
    //_chatData..addAll(listChat?.reversed);
    _chatData..addAll(listChat);
    debugPrint('mounted >>> {$mounted}');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // if (!listNoEmpty(_chatData)) {
    //   return new HomeNullView();
    // }

    return new Container(
      color: Color(AppColors.BackgroundColor),
      child: new ScrollConfiguration(
        behavior: MyBehavior(),
        child: new ListView.builder(
          itemBuilder: (BuildContext context, int index) {
            MessageModel model = _chatData[index];

            return InkWell(
              onTap: () {
                Get.to(ChatPage(
                  id: model.fromId,
                  type: model.type,
                  // title: model.from?.nickname ?? '',
                  title: model.fromId,
                ));
              },
              onTapDown: (TapDownDetails details) {
                tapPos = details.globalPosition;
              },
              onLongPress: () {
                if (Platform.isAndroid) {
                  _showMenu(
                    context,
                    tapPos,
                    model.type,
                    model.fromId,
                  );
                } else {
                  debugPrint("IOS聊天长按选项功能开发中");
                }
              },
              child: new ConversationView(
                imageUrl: model.fromId,
                // title: model.from?.nickname ?? '',
                title: model.fromId,
                payload: model?.payload,
                time: timeView(model?.serverTs ?? 0),
                isBorder: model?.fromId != _chatData[0].fromId,
              ),
            );
          },
          itemCount: _chatData?.length ?? 1,
        ),
      ),
    );
  }

  Widget timeView(int time) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(time * 1000);

    String hourParse = "0${dateTime.hour}";
    String minuteParse = "0${dateTime.minute}";

    String hour = dateTime.hour.toString().length == 1
        ? hourParse
        : dateTime.hour.toString();
    String minute = dateTime.minute.toString().length == 1
        ? minuteParse
        : dateTime.minute.toString();

    String timeStr = '$hour:$minute';

    return new SizedBox(
      width: 40.0,
      child: new Text(
        timeStr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: mainTextColor, fontSize: 14.0),
      ),
    );
  }

  _showMenu(BuildContext context, Offset tapPos, String type, String id) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject();
    final RelativeRect position = RelativeRect.fromLTRB(tapPos.dx, tapPos.dy,
        overlay.size.width - tapPos.dx, overlay.size.height - tapPos.dy);
    showMenu<String>(
        context: context,
        position: position,
        items: <IMBoyPopupMenuItem<String>>[
          new IMBoyPopupMenuItem(child: Text('标为已读'), value: '标为已读'),
          new IMBoyPopupMenuItem(child: Text('置顶聊天'), value: '置顶聊天'),
          new IMBoyPopupMenuItem(child: Text('删除该聊天'), value: '删除该聊天'),
          // ignore: missing_return
        ]).then<String>((String selected) {
      switch (selected) {
        case '删除该聊天':
          deleteConversationAndLocalMsgModel(type, id, callback: (str) {
            debugPrint('deleteConversationAndLocalMsgModel' + str.toString());
          });
          delConversationModel(id, type, callback: (str) {
            debugPrint('deleteConversationModel' + str.toString());
          });
          getChatData();
          break;
        case '标为已读':
          getUnreadMessageNumModel(type, id, callback: (str) {
            int num = int.parse(str.toString());
            if (num != 0) {
              setReadMessageModel(type, id);
              setState(() {});
            }
          });
          break;
      }
    });
  }

  @override
  void dispose() {
    Get.delete<HomeLogic>();
    super.dispose();
  }
}
