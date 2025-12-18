import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/conversation/widget/right_button.dart'
    show RightButton;
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/service/sqlite.dart';

import 'conversation_logic.dart';
import 'widget/conversation_item.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  StreamSubscription? ssMsg;

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
    ssMsg?.cancel();
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
      obj.title = await logic.computeTitle(obj);
      // 更新会话
      await logic.replace(obj);
    });
    // 加载会话记录
    if (logic.conversations.isEmpty) {
      await logic.conversationsList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: Text(
          'title_message'.tr + logic.connectDesc.value,
          // style: AppStyle.navAppBarTitleStyle, // 传入BuildContext
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: const RightButton(),
          ),
        ],
      ),
      // backgroundColor: Get.isDarkMode ? darkBgColor : lightBgColor,
      body: Column(
        children: [
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
                          RxInt remindNum =
                              RxInt(logic.conversationRemind[model.uk3] ?? 0);
                          return InkWell(
                            onTap: () {
                              Get.to(
                                () => ChatPage(
                                  peerId: model.peerId,
                                  peerTitle: model.title,
                                  peerAvatar: model.avatar,
                                  peerSign: model.sign,
                                  type: strEmpty(model.type)
                                      ? 'C2C'
                                      : model.type,
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
                                  CustomSlidableAction(
                                    onPressed: (_) async {
                                      int num = 1;
                                      if (model.unreadNum > 0) {
                                        // 当前有未读消息，标记为已读
                                        num = 0;
                                        // 同步将该会话未读消息状态从 delivered 改为 seen，避免刷新后红点恢复
                                        try {
                                          final db = await SqliteService.to.db;
                                          if (db != null) {
                                            final tb = MessageRepo.getTableName(model.type);
                                            await db.update(
                                              tb,
                                              {MessageRepo.status: IMBoyMessageStatus.seen},
                                              where:
                                                  "${MessageRepo.conversationUk3} = ? and ${MessageRepo.status} = ? and ${MessageRepo.isAuthor} = ?",
                                              whereArgs: [
                                                model.uk3,
                                                IMBoyMessageStatus.delivered,
                                                0,
                                              ],
                                            );
                                          }
                                        } catch (e) {
                                          // 忽略异常以保证交互流畅，后续重算会再次校正
                                        }
                                        // 推进水位到该会话来自对方的最新消息
                                        await logic.advanceWatermarkToLatest(model);
                                        await logic.setConversationRemind(model, 0);
                                      } else {
                                        // 当前没有未读消息，标记为未读
                                        num = 1;
                                        await logic.setConversationRemind(model, 1);
                                      }
                                      // 更新本地模型
                                      model.unreadNum = num;
                                      // 更新内存中的会话映射
                                      logic.conversationMap[model.uk3] = model.copyWith(unreadNum: num);
                                      // 更新提醒计数
                                      logic.conversationRemind[model.uk3] = num;
                                      remindNum.value = num;
                                    },
                                    autoClose: true,
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    flex: 2,
                                    child: Obx(
                                      () => Text(
                                        remindNum > 0 ? "标为已读" : "标为未读",
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  SlidableAction(
                                    key: ValueKey("hide_$index"),
                                    flex: 3,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    onPressed: (_) async {
                                      final uk3 = model.uk3;
                                      await logic.hideConversation(model.id);
                                      // 从 Map 中移除对应会话
                                      logic.conversationMap.remove(uk3);
                                      // 清空提醒计数
                                      logic.conversationRemind[uk3] = 0;
                                      // 通知 UI 更新（GetX 会自动响应）
                                      logic.update();
                                    },
                                    label: 'not_show'.tr,
                                    spacing: 1,
                                  ),
                                  SlidableAction(
                                    key: ValueKey("delete_$index"),
                                    flex: 2,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onError,
                                    onPressed: (_) async {
                                      final uk3 = model.uk3;
                                      await logic.removeConversation(model);
                                      // 从 Map 中移除对应会话
                                      logic.conversationMap.remove(uk3);
                                      // 清空提醒计数
                                      logic.conversationRemind[uk3] = 0;
                                      // 通知 UI 更新（GetX 会自动响应）
                                      logic.update();
                                    },
                                    label: 'button_delete'.tr,
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
        ],
      ),
    );
  }
}
