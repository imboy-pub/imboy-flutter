import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/null_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/model/conversation_model.dart';

import 'conversation_logic.dart';
import 'widget/conversation_view.dart';

class ConversationPage extends StatefulWidget {
  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final logic = Get.put(ConversationLogic());

  bool alive = true;

  var subscription;

  String _connectDesc = "";

  @override
  void initState() {
    super.initState();

    eventBus.on<ConversationModel>().listen((e) async {
      if (mounted) {
        setState(() {
          MessageService.to.conversations[e.typeId] = e;
        });
      }
    });
    subscription =
        Connectivity().onConnectivityChanged.listen((ConnectivityResult r) {
      debugPrint(">>> on checkConnectivity onConnectivityChanged ${r}");
      if (r == ConnectivityResult.none) {
        setState(() {
          _connectDesc = 'tip_connect_desc'.tr;
        });
      }
    });
    initData();
  }

  void initData() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    debugPrint(">>> on checkConnectivity ${connectivityResult}");
    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        _connectDesc = 'tip_connect_desc'.tr;
      });
    }
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
    // await UserRepoLocal.to.refreshtoken();
    // final keyPair = await generateKeys();
    // debugPrint(">>> on e2ee pubkey ${keyPair.publicKey}");
  }

  @override
  Widget build(BuildContext context) {
    List<ConversationModel> items =
        MessageService.to.conversations.values.toList();

    Widget body = ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        ConversationModel model = items[index];
        // debugPrint(
        //     ">>> on conversation_view build item ${model.toJson().toString()}");
        int conversationId = model.id;
        return InkWell(
          onTap: () {
            Get.to(
              () => ChatPage(
                id: model.id,
                toId: model.typeId,
                title: model.title,
                avatar: model.avatar,
                type: model.type == null ? 'C2C' : model.type,
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
                status: model.lastMsgStatus,
                time: Text(
                  DateTimeHelper.lastConversationFmt(
                    model.lasttime ?? 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.MainTextColor,
                    fontSize: 14.0,
                  ),
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
    String title = 'title_message'.tr;
    return Scaffold(
      appBar: NavAppBar(
        title: strEmpty(_connectDesc) ? title : '${title}(${_connectDesc.tr})',
      ),
      body: SlidableAutoCloseBehavior(
        child: body,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    Get.delete<ConversationLogic>();
    subscription.cancel();
  }
}
