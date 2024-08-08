import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/store/model/conversation_model.dart';

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
  late StreamSubscription ssMsg;

  @override
  void initState() {
    super.initState();
    if (!mounted) {
      return;
    }
    initData();
  }

  @override
  void dispose() {
    ssMsg.cancel();
    super.dispose();
  }

  final ConversationLogic logic = Get.find();

  void initData() async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // ignore: prefer_interpolation_to_compose_strings
      logic.connectDesc.value = '(' + 'tip_connect_desc'.tr + ')';
    } else {
      logic.connectDesc.value = '';
    }
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        logic.connectDesc.value = '(${'tip_connect_desc'.tr})';
      } else {
        logic.connectDesc.value = '';
      }
    });

    // 监听会话消息
    ssMsg = eventBus.on<ConversationModel>().listen((obj) async {
      if (obj.type == 'C2G' && obj.avatar.isEmpty) {
        obj.computeAvatar = await Get.find<GroupListLogic>().computeAvatar(
          obj.peerId,
        );
      }
      if (obj.type == 'C2G' && obj.title.trim().isEmpty) {
        obj.computeTitle = await Get.find<GroupListLogic>().computeTitle(
          obj.peerId,
        );
      }
      // 更新会话
      await logic.replace(obj);
      // 重新排序会话列表
      await logic.sortConversationsList();
    });
    // 加载会话记录
    if (logic.conversations.isEmpty) {
      await logic.conversationsList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
        leading: const SizedBox.shrink(),
        titleWidget: Obx(
          () => Text(
            'title_message'.tr + logic.connectDesc.value,
            style: AppStyle.navAppBarTitleStyle,
          ),
        ),
        rightDMActions: <Widget>[
          n.Padding(
            right: 4,
            child: const RightButton(),
          ),
        ],
      ),
      // backgroundColor: Get.isDarkMode ? darkBgColor : lightBgColor,
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
                  ? NoDataView(text: 'no_conversation_messages'.tr)
                  : ListView.builder(
                      itemCount: logic.conversations.length,
                      itemBuilder: (BuildContext context, int index) {
                        ConversationModel model = logic.conversations[index];
                        // RxInt remindNum =
                        //     logic.conversationRemind[model.peerId] ?? 0.obs;
                        return InkWell(
                          onTap: () {
                            Get.to(
                              () => ChatPage(
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

                            endActionPane: ActionPane(
                              extentRatio: 0.618,
                              motion: const StretchMotion(),
                              children: [
                                /*
                                CustomSlidableAction(
                                  onPressed: (_) async {
                                    int num = 1;
                                    remindNum.value = 1;
                                    if (model.unreadNum > 0) {
                                      num = 0;
                                      remindNum.value = 0;
                                    }
                                    logic.markAs(model.peerId, num);
                                    model.unreadNum = num;
                                  },
                                  autoClose: true,
                                  backgroundColor: Colors.blue,
                                  flex: 2,
                                  child: Obx(
                                    () => Text(
                                      remindNum > 0 ? "标为已读" : "标为未读",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                */
                                SlidableAction(
                                  key: ValueKey("hide_$index"),
                                  flex: 3,
                                  backgroundColor: Colors.amber,
                                  onPressed: (_) async {
                                    await logic.hideConversation(model.id);
                                    logic.update([
                                      logic.conversations.removeAt(index),
                                      logic.conversationRemind[model.uk3] =
                                          0.obs,
                                      logic.chatMsgRemindCounter,
                                    ]);
                                  },
                                  label: 'not_show'.tr,
                                  spacing: 1,
                                ),
                                SlidableAction(
                                  key: ValueKey("delete_$index"),
                                  flex: 2,
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  onPressed: (_) async {
                                    await logic.removeConversation(model);
                                    logic.update([
                                      logic.conversations.removeAt(index),
                                      logic.conversationRemind[model.uk3] =
                                          0.obs,
                                      logic.chatMsgRemindCounter,
                                    ]);
                                  },
                                  label: 'button_delete'.tr,
                                  spacing: 1,
                                ),
                              ],
                            ),
                            // endActionPane: null,
                            child: ConversationItem(
                              model: model,
                              // remindCounter: remindNum,
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
