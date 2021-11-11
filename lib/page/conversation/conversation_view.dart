import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/indicator_page_view.dart';
import 'package:imboy/component/view/null_view.dart';
import 'package:imboy/component/widget/chat/conversation_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/model/conversation_model.dart';

import 'conversation_logic.dart';

class ConversationPage extends StatefulWidget {
  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final logic = Get.put(ConversationLogic());

  var tapPos;

  final _counter = Get.put(MessageService());

  @override
  void initState() {
    super.initState();
    initData();
  }

  void initData() async {
    Map<String, ConversationModel> items = await logic.getConversationsList();
    if (items.isEmpty) {
      return;
    }

    debugPrint(">>>>> on ConversationRemind _ConversationPageState/initData");
    if (items == null || items.length == 0) {
      return;
    }
    setState(() {
      items.forEach((key, obj) {
        debugPrint(">>>>> on ${obj.typeId} = ${obj.unreadNum}");
        int unreadNum = obj.unreadNum!;
        _counter.setConversationRemind(
          obj.typeId,
          unreadNum > 0 ? unreadNum : 0,
        );
      });
      _counter.conversations.value = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(">>>>> on _ConversationPageState build");
    Widget body = ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        List<ConversationModel> items = _counter.conversations.values.toList();
        ConversationModel model = items[index];
        return InkWell(
          onTap: () {
            Get.to(
              () => ChatPage(
                id: model.typeId,
                title: model.title,
                avatar: model.avatar,
                type: model.type,
              ),
            );
          },
          onTapDown: (TapDownDetails details) {
            tapPos = details.globalPosition;
          },
          onLongPress: () {
            // _showMenu(
            //   context,
            //   tapPos,
            //   model.type!,
            //   model.fromId!,
            // );
          },
          child: Obx(
            () => ConversationView(
              imageUrl: _counter.conversations[model.typeId]!.avatar,
              title: _counter.conversations[model.typeId]!.title,
              payload: {
                "msg_type": _counter.conversations[model.typeId]!.msgtype,
                "text": _counter.conversations[model.typeId]!.subtitle,
              },
              time:
                  timeView(_counter.conversations[model.typeId]!.lasttime ?? 0),
              // isBorder: model.typeId != _counter.conversations.values[0].typeId,
              remindCounter: _counter.conversationRemind[model.typeId],
            ),
          ),
        );
      },
      itemCount: _counter.conversations.values.length,
    );
    if (_counter.conversations.isEmpty) {
      body = ConversationNullView();
    }
    return Scaffold(
      appBar: NavAppBar(
        title: '消息',
      ),
      body: Container(
        color: AppColors.BgColor,
        child: ScrollConfiguration(
          behavior: MyBehavior(),
          child: body,
        ),
      ),
    );
  }

  Widget timeView(int time) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(time);

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
        style: TextStyle(color: AppColors.MainTextColor, fontSize: 14.0),
      ),
    );
  }

  // _showMenu(BuildContext context, Offset tapPos, String type, String id) {
  //   final RenderObject? overlay =
  //       Overlay.of(context)?.context?.findRenderObject();
  //   final RelativeRect position = RelativeRect.fromLTRB(
  //     tapPos.dx,
  //     tapPos.dy,
  //     overlay?.size?.width - tapPos.dx,
  //     overlay?.size?.height - tapPos.dy,
  //   );
  //   showMenu<String>(
  //       context: context,
  //       position: position,
  //       items: <IMBoyPopupMenuItem<String>>[
  //         new IMBoyPopupMenuItem(child: Text('标为已读'), value: '标为已读'),
  //         new IMBoyPopupMenuItem(child: Text('置顶聊天'), value: '置顶聊天'),
  //         new IMBoyPopupMenuItem(child: Text('删除该聊天'), value: '删除该聊天'),
  //         // ignore: missing_return
  //       ]).then<String>((String selected) {
  //     switch (selected) {
  //       case '删除该聊天':
  //         deleteConversationAndLocalMsgModel(type, id, callback: (str) {
  //           debugPrint('deleteConversationAndLocalMsgModel' + str.toString());
  //         });
  //         delConversationModel(id, type, callback: (str) {
  //           debugPrint('deleteConversationModel' + str.toString());
  //         });
  //         getChatData();
  //         break;
  //       case '标为已读':
  //         getUnreadMessageNumModel(type, id, callback: (str) {
  //           int num = int.parse(str.toString());
  //           if (num != 0) {
  //             setReadConversationModel(type, id);
  //             setState(() {});
  //           }
  //         });
  //         break;
  //     }
  //   });
  // }

  @override
  void dispose() {
    Get.delete<ConversationLogic>();
    super.dispose();
  }
}
