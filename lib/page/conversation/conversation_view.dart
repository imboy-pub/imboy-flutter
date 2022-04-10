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
import 'package:imboy/page/contact_detail/contact_detail_view.dart';
import 'package:imboy/store/model/conversation_model.dart';

import 'conversation_logic.dart';
import 'widget/conversation_item.dart';

class ConversationPage extends StatelessWidget {
  final logic = Get.put(ConversationLogic());

  void initData() async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      logic.connectDesc.value = '(' + 'tip_connect_desc'.tr + ')';
    } else {
      logic.connectDesc.value = '';
    }
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((ConnectivityResult r) {
      if (r == ConnectivityResult.none) {
        logic.connectDesc.value = '(' + 'tip_connect_desc'.tr + ')';
      } else {
        logic.connectDesc.value = '';
      }
    });

    // 监听会话消息
    eventBus.on<ConversationModel>().listen((e) async {
      debugPrint(
          ">>> on logic.conversations listen ${e.typeId} = ${e.unreadNum}");
      // 更新会话
      logic.replace(e);
    });
    // 设置消息提醒数量
    logic.conversations.value.forEach((obj) {
      debugPrint(">>> on logic.conversations ${obj.typeId} = ${obj.unreadNum}");
      if (obj.unreadNum > 0) {
        logic.setConversationRemind(
          obj.typeId,
          obj.unreadNum,
        );
      }
    });
    // 加载会话记录
    await logic.getConversationsList();
  }

  @override
  Widget build(BuildContext context) {
    initData();
    Widget body = Obx(() {
      return logic.conversations.isEmpty
          ? ConversationNullView()
          : ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                ConversationModel model = logic.conversations[index];
                int conversationId = model.id;
                var remindNum =
                    logic.conversationRemind.containsKey(model.typeId)
                        ? logic.conversationRemind[model.typeId]!.obs
                        : 0.obs;
                return InkWell(
                  onTap: () {
                    Get.to(
                      () => ChatPage(
                        id: model.id,
                        toId: model.typeId,
                        title: model.title,
                        avatar: model.avatar,
                        type: strEmpty(model.type) ? 'C2C' : model.type,
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
                        CustomSlidableAction(
                          onPressed: (_) async {
                            int num = 1;
                            remindNum.value = 1;
                            if (model.unreadNum > 0) {
                              num = 0;
                              remindNum.value = 0;
                            }
                            logic.markAs(model.id, num);
                            logic.conversationRemind[model.typeId] = num;
                            model.unreadNum = num;
                          },
                          autoClose: true,
                          backgroundColor: Colors.blue,
                          flex: 2,
                          child: Obx(
                            () => Text(
                              remindNum.value > 0 ? "标为已读" : "标为未读",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SlidableAction(
                          key: ValueKey("hide_${index}"),
                          flex: 2,
                          backgroundColor: Colors.amber,
                          onPressed: (_) async {
                            await logic.hideConversation(conversationId);
                            logic.conversations.removeAt(index);
                            logic.conversationRemind[model.typeId] = 0;
                            logic.chatMsgRemindCounter;
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
                            logic.conversations.removeAt(index);
                            logic.conversationRemind[model.typeId] = 0;
                            logic.chatMsgRemindCounter;
                          },
                          label: "删除",
                          spacing: 1,
                        ),
                      ],
                    ),
                    child: ConversationItem(
                      imgUri: model.avatar,
                      onTapAvatar: () {
                        Get.to(
                          ContactDetailPage(
                            id: model.typeId,
                            nickname: model.title,
                            avatar: model.avatar,
                            account: "",
                          ),
                        );
                      },
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
                      remindCounter: remindNum,
                    ),
                  ),
                );
              },
              itemCount: logic.conversations.length,
            );
    });

    return Scaffold(
      appBar: NavAppBar(
          // title: 'title_message'.tr + logic.connectDesc.value,
          titleWiew: Obx(
        () => Text(
          'title_message'.tr + logic.connectDesc.value,
          style: new TextStyle(
            color: Colors.black,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      )),
      body: SlidableAutoCloseBehavior(
        child: body,
      ),
    );
  }
}
