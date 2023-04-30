import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/page/friend/add_friend_view.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:niku/namespace.dart' as n;
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/uqrcode/uqrcode_view.dart';
import 'package:imboy/store/model/conversation_model.dart';

import 'conversation_logic.dart';
import 'widget/conversation_item.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({Key? key}) : super(key: key);

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
      logic.replace(e);
    });
    // 加载会话记录
    if (logic.conversations.isEmpty) {
      await logic.conversationsList();
    }

    // 设置消息提醒数量
    for (ConversationModel obj in logic.conversations) {
      logic.recalculateConversationRemind(obj.peerId);
    }
  }

  void topRightMenu(popupmenu.MenuItemProvider item) {
    popupmenu.MenuItem it = item as popupmenu.MenuItem;
    String action = it.userInfo as String;
    if (action == 'scanner') {
      Get.to(
        const ScannerPage(),
        transition: Transition.rightToLeft,
        popGesture: true, // 右滑，返回上一页
      );
    } else if (action == 'my_qrcode') {
      Get.to(
        UqrcodePage(),
        transition: Transition.rightToLeft,
        popGesture: true, // 右滑，返回上一页
      );
    } else if (action == 'add_friend') {
      Get.to(
        AddFriendPage(),
        transition: Transition.rightToLeft,
        popGesture: true, // 右滑，返回上一页
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
          // title: 'title_message'.tr + logic.connectDesc.value,
          rightDMActions: <Widget>[
            InkWell(
              child: const SizedBox(
                width: 46.0,
                child: Icon(
                  Icons.add_circle_outline_sharp,
                  color: Colors.black54,
                ),
              ),
              onTap: () {
                List<popupmenu.MenuItemProvider> items = [
                  popupmenu.MenuItem(
                    title: '发起群聊'.tr,
                    textAlign: TextAlign.center,
                    textStyle: const TextStyle(
                      color: Color(0xffc5c5c5),
                      fontSize: 13.0,
                    ),
                    image: const Icon(
                      Icons.chat_bubble_outlined,
                      color: Colors.white,
                    ),
                    // userInfo: message,
                  ),
                  popupmenu.MenuItem(
                    title: '添加朋友'.tr,
                    userInfo: 'add_friend',
                    textAlign: TextAlign.center,
                    textStyle: const TextStyle(
                      fontSize: 13.0,
                      color: Colors.white,
                    ),
                    image: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.white,
                    ),
                    // userInfo: message,
                  ),
                  popupmenu.MenuItem(
                    title: '我的二维码'.tr,
                    userInfo: 'my_qrcode',
                    textAlign: TextAlign.center,
                    textStyle: const TextStyle(
                      fontSize: 13.0,
                      color: Colors.white,
                    ),
                    image: const Icon(
                      Icons.qr_code_2,
                      color: Colors.white,
                    ),
                    // userInfo: message,
                  ),
                  popupmenu.MenuItem(
                    title: '扫一扫'.tr,
                    userInfo: 'scanner',
                    textAlign: TextAlign.center,
                    textStyle: const TextStyle(
                      fontSize: 13.0,
                      color: Colors.white,
                    ),
                    image: const Icon(
                      Icons.qr_code_scanner_outlined,
                      color: Colors.white,
                    ),
                    // userInfo: message,
                  ),
                ];
                popupmenu.PopupMenu menu = popupmenu.PopupMenu(
                  items: items,
                  context: context,
                  config: const popupmenu.MenuConfig(
                    type: popupmenu.MenuType.list,
                    itemWidth: 114,
                    itemHeight: 44,
                    arrowHeight: 6,
                    backgroundColor: AppColors.ItemBgColor,
                    highlightColor: AppColors.ItemOnColor,
                    lineColor: Color.fromRGBO(255, 255, 255, 1),
                  ),
                  onClickMenu: topRightMenu,
                  // stateChanged: stateChanged,
                  // onDismiss: onDismiss,
                );
                double top = -4;
                double left = Get.width - 78;
                double width = 110;
                double height = 64;
                menu.show(
                  rect: Rect.fromLTWH(left, top, width, height),
                );
              },
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
          )),
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
                              ChatPage(
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
                            endActionPane: ActionPane(
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
                            child: ConversationItem(
                              model: model,
                              remindCounter: remindNum,
                              onTapAvatar: () {
                                Get.to(
                                  PeopleInfoPage(id: model.peerId, sence: ''),
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
