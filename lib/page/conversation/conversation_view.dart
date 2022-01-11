import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/null_view.dart';
import 'package:imboy/component/widget/chat/conversation_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
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

  StreamSubscription<dynamic>? _convStreamSubs;

  @override
  void initState() {
    super.initState();

    debugPrint(">>>>> on _convStreamSubs ${_convStreamSubs.toString()}");
    if (_convStreamSubs == null) {
      // Register listeners for all events:
      _convStreamSubs = eventBus.on<ConversationModel>().listen((e) async {
        MessageService.to.conversations[e.typeId] = e;
        if (mounted) {
          setState(() {
            MessageService.to.conversations;
          });
        }
      });
    }
    debugPrint(">>>>> on _convStreamSubs ${_convStreamSubs.toString()}");
    initData();
  }

  void initData() async {
    if (!mounted) {
      return;
    }
    Map<String, ConversationModel> items = await logic.getConversationsList();
    if (items.isNotEmpty) {
      MessageService.to.conversations.value = items;
    }

    MessageService.to.conversations.forEach((key, obj) {
      debugPrint(
          ">>> on _ConversationPageState/initData ${obj.typeId} = ${obj.unreadNum}");
      int unreadNum = obj.unreadNum;
      MessageService.to.setConversationRemind(
        obj.typeId,
        unreadNum > 0 ? unreadNum : 0,
      );
    });
    setState(() {
      MessageService.to.conversations;
      MessageService.to.conversationRemind;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<ConversationModel> items =
        MessageService.to.conversations.values.toList();

    Widget body = ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        ConversationModel model = items[index];
        int conversationId = model.id;
        debugPrint(
            ">>> on _ConversationPageState build ${model.toJson().toString()}");
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
          onTapDown: (TapDownDetails details) {},
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
                  key: model.unreadNum > 0
                      ? ValueKey("mark_as_read${index}")
                      : ValueKey("mark_as_unread${index}"), // or mark_as_unread
                  flex: 2,
                  backgroundColor: Colors.blue,
                  onPressed: (_) async {
                    // Get.snackbar("title", model.unreadNum.toString());
                    int num = 1;
                    if (model.unreadNum > 0) {
                      num = 0;
                    }
                    logic.markAs(model.id, num);
                    setState(() {
                      MessageService.to.conversationRemind[model.typeId] = num;
                    });
                    model.unreadNum = num;
                  },
                  label: model.unreadNum > 0 ? "标为已读" : "标为未读",
                  spacing: 1,
                ),
                SlidableAction(
                  key: ValueKey("hide_${index}"),
                  flex: 2,
                  backgroundColor: Colors.amber,
                  onPressed: (_) async {
                    await logic.hideConversation(conversationId);
                    MessageService.to.conversations.remove(model.typeId);
                    setState(() {
                      MessageService.to.conversations.value;
                      MessageService.to.conversationRemind[model.typeId] = 0;
                      MessageService.to.chatMsgRemindCounter;
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
                    MessageService.to.conversations.remove(model.typeId);
                    setState(() {
                      MessageService.to.conversations.value;
                      MessageService.to.conversationRemind[model.typeId] = 0;
                      MessageService.to.chatMsgRemindCounter;
                    });
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
                  'msg_type': model.msgtype,
                  'text': model.subtitle,
                },
                time: _timeView(
                  model.lasttime ?? 0,
                ),
                // isBorder: model.typeId != _msgService.conversations.values[0].typeId,
                remindCounter:
                    MessageService.to.conversationRemind[model.typeId],
              ),
            ),
          ),
        );
      },
      itemCount: MessageService.to.conversations.values.length,
    );
    if (MessageService.to.conversations.isEmpty) {
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

    if (_convStreamSubs != null) {
      _convStreamSubs!.cancel();
      _convStreamSubs = null;
    }
    super.dispose();
  }
}
