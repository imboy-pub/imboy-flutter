import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
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

  bool alive = true;
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
      setState(() {
        _counter.conversations.value = items;
        _counter.conversationRemind;
      });
      return;
    }

    items.forEach((key, obj) {
      debugPrint(">>>>> on ${obj.typeId} = ${obj.unreadNum}");
      int unreadNum = obj.unreadNum!;
      _counter.setConversationRemind(
        obj.typeId,
        unreadNum > 0 ? unreadNum : 0,
      );
    });
    setState(() {
      _counter.conversations.value = items;
      _counter.conversationRemind;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(">>>>> on _ConversationPageState build");
    List<ConversationModel> items = _counter.conversations.values.toList();

    Widget body = ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        ConversationModel model = items[index];
        int conversationId = model.id;
        return InkWell(
          onTap: () {
            Get.to(
              () => ChatPage(
                id: model.id,
                toId: model.typeId,
                title: model.title,
                avatar: model.avatar,
                type: model.type,
              ),
            );
          },
          onTapDown: (TapDownDetails details) {
            tapPos = details.globalPosition;
          },
          onLongPress: () {},
          child: Slidable(
            key: ValueKey(model.id),
            groupTag: '0',
            closeOnScroll: true,
            endActionPane: ActionPane(
              extentRatio: 0.75,
              motion: StretchMotion(),
              children: [
                SlidableAction(
                  key: ValueKey("mark_as_read${index}"), // or mark_as_unread
                  flex: 2,
                  backgroundColor: Colors.blue,
                  onPressed: (_) async {
                    setState(() {
                      _counter.conversations.value;
                    });
                  },
                  label: "标为已读",
                  spacing: 1,
                ),
                SlidableAction(
                  key: ValueKey("not_show_${index}"),
                  flex: 2,
                  backgroundColor: Colors.amber,
                  onPressed: (_) async {
                    setState(() {
                      _counter.conversations.value;
                    });
                  },
                  label: "不显示",
                  spacing: 1,
                ),
                SlidableAction(
                  key: ValueKey("delete_${index}"),
                  flex: 2,
                  backgroundColor: Colors.red,
                  // foregroundColor: Colors.white,
                  onPressed: (_) async {
                    await logic.removeConversation(conversationId);
                    _counter.conversations.remove(model.typeId);
                    setState(() {
                      _counter.conversations.value;
                    });
                    debugPrint(
                        ">>>>> on SlidableAction/onPressed index: ${index}; conversationId: ${conversationId}");
                  },
                  label: "删除",
                  spacing: 1,
                ),
              ],
            ),
            child: Obx(
              () => ConversationView(
                imageUrl: model.avatar,
                title: model.title,
                payload: {
                  "msg_type": model.msgtype,
                  "text": model.subtitle,
                },
                time: _timeView(
                  model.lasttime ?? 0,
                ),
                // isBorder: model.typeId != _counter.conversations.values[0].typeId,
                remindCounter: _counter.conversationRemind[model.typeId],
              ),
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
      body: SlidableAutoCloseBehavior(
        child: body,
      ),
    );
  }

  Widget _timeView(int time) {
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

    return Padding(
      padding: EdgeInsets.only(top: 0),
      child: new Text(
        timeStr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.MainTextColor,
          fontSize: 14.0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<ConversationLogic>();
    super.dispose();
  }
}
