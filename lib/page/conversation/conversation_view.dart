import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:niku/namespace.dart' as n;

import 'conversation_logic.dart';
import 'widget/conversation_item.dart';
import 'widget/right_button_list.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  @override
  void initState() {
    super.initState();
    if (!mounted) {
      return;
    }
    initData();
  }

  final ConversationLogic logic = Get.find();

  void initData() async {
    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      // ignore: prefer_interpolation_to_compose_strings
      logic.connectDesc.value = '(' + 'tip_connect_desc'.tr + ')';
    } else {
      logic.connectDesc.value = '';
    }
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((ConnectivityResult r) {
      if (r == ConnectivityResult.none) {
        // ignore: prefer_interpolation_to_compose_strings
        logic.connectDesc.value = '(${'tip_connect_desc'.tr})';
      } else {
        logic.connectDesc.value = '';
      }
    });

    // 监听会话消息
    eventBus.on<ConversationModel>().listen((e) async {
      // 更新会话
      await logic.replace(e);
      // 重新排序会话列表
      await logic.sortConversationsList();
    });
    // 加载会话记录
    if (logic.conversations.isEmpty) {
      await logic.conversationsList();
    }

    // 设置消息提醒数量
    for (ConversationModel obj in logic.conversations) {
      // 重新计算会话消息提醒数量
      logic.recalculateConversationRemind(obj.peerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
        // title: 'title_message'.tr + logic.connectDesc.value,
        rightDMActions: <Widget>[
          n.Padding(
            right: 4,
            child: const RightButton(),
          ),
        ],
        titleWidget: Obx(
          () => Text(
            'title_message'.tr + logic.connectDesc.value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: n.Column([
        Obx(() {
          return logic.connectDesc.isEmpty
              ? const SizedBox.shrink()
              : NetworkFailureTips();
        }),
        Expanded(
          child: SlidableAutoCloseBehavior(
            child: Obx(() {
              return logic.conversations.isEmpty
                  ? NoDataView(text: '无会话消息'.tr)
                  : ListView.builder(
                      itemCount: logic.conversations.length,
                      itemBuilder: (BuildContext context, int index) {
                        ConversationModel model = logic.conversations[index];
                        int conversationId = model.id;
                        var remindNum =
                            logic.conversationRemind.containsKey(model.peerId)
                                ? logic.conversationRemind[model.peerId]!.obs
                                : 0.obs;
                        return InkWell(
                          onTap: () {
                            Get.to(
                              () => ChatPage(
                                conversationId: model.id,
                                peerId: model.peerId,
                                peerTitle: model.title,
                                peerAvatar: model.avatar,
                                peerSign: model.sign,
                                type: strEmpty(model.type) ? 'C2C' : model.type,
                              ),
                              transition: Transition.rightToLeft,
                              popGesture: true, // 右滑，返回上一页
                            );
                          },
                          onTapDown: (TapDownDetails details) {},
                          onLongPress: () {},
                          child: Slidable(
                            key: ValueKey(model.id),
                            groupTag: '0',
                            closeOnScroll: true,
                            startActionPane: ActionPane(
                              extentRatio: 0.75,
                              motion: const StretchMotion(),
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
                                    model.unreadNum = num;
                                    logic.update([
                                      logic.conversationRemind[model.peerId] =
                                          num,
                                      logic.conversations[index].unreadNum =
                                          num,
                                    ]);
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
                                  key: ValueKey("hide_$index"),
                                  flex: 2,
                                  backgroundColor: Colors.amber,
                                  onPressed: (_) async {
                                    await logic.hideConversation(model.peerId);
                                    logic.update([
                                      logic.conversations.removeAt(index),
                                      logic.conversationRemind[model.peerId] =
                                          0,
                                      logic.chatMsgRemindCounter,
                                    ]);
                                  },
                                  label: "不显示".tr,
                                  spacing: 1,
                                ),
                                SlidableAction(
                                  key: ValueKey("delete_$index"),
                                  flex: 2,
                                  backgroundColor: Colors.red,
                                  // foregroundColor: Colors.white,
                                  onPressed: (_) async {
                                    await logic
                                        .removeConversation(conversationId);
                                    logic.update([
                                      logic.conversations.removeAt(index),
                                      logic.conversationRemind[model.peerId] =
                                          0,
                                      logic.chatMsgRemindCounter,
                                    ]);
                                  },
                                  label: "删除".tr,
                                  spacing: 1,
                                ),
                              ],
                            ),
                            // endActionPane: null,
                            child: ConversationItem(
                              model: model,
                              remindCounter: remindNum,
                              onTapAvatar: () {
                                Get.to(
                                  () => PeopleInfoPage(
                                    id: model.peerId,
                                    scene: '',
                                  ),
                                  transition: Transition.rightToLeft,
                                  popGesture: true, // 右滑，返回上一页
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
            }),
          ),
        ),
      ]),
    );
  }
}
