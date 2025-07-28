import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/store/model/conversation_model.dart';

import 'group_select_logic.dart';
import 'group_select_state.dart';

class GroupSelectPage extends StatelessWidget {
  final GroupSelectLogic logic = Get.put(GroupSelectLogic());
  final GroupSelectState state = Get.find<GroupSelectLogic>().state;

  GroupSelectPage({super.key});

  void loadData() async {
    state.items.value = await Get.find<ConversationLogic>().conversationsList(
      type: 'C2G',
      recalculateRemind: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        title: 'select_group'.tr,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: Obx(() {
          return state.items.isEmpty
              ? NoDataView(text: 'no_data'.tr)
              : ListView.builder(
            shrinkWrap: true,
            itemCount: state.items.length,
            itemBuilder: (BuildContext context, int index) {
              ConversationModel model = state.items[index];
              return Column(
                children: [
                  ListTile(
                    leading: SmartGroupAvatar(
                      avatar: model.avatar,
                      groupId: model.peerId,
                    ),
                    contentPadding: const EdgeInsets.only(
                      left: 10,
                      right: 10,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                              strEmpty(model.title)
                                  ? model.computeTitle
                                  : model.title
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Get.to(
                            () => ChatPage(
                          peerId: model.peerId,
                          peerTitle: model.title,
                          peerAvatar: model.avatar,
                          peerSign: '',
                          type: 'C2G',
                          options: const {
                            'popTime': 2,
                            'memberCount': 0
                          },
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 12, right: 20, bottom: 10),
                    child: HorizontalLine(
                      height: Get.isDarkMode ? 0.5 : 1.0,
                    ),
                  ),
                ],
              );
            },
            // 解决联系人数据量少的情况下无法刷新的问题
            // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
            physics: const AlwaysScrollableScrollPhysics(),
          );
        }),
      ),
    );
  }
}