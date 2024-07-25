import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
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
        body: SingleChildScrollView(child: Obx(() {
          // return NoDataView(text: 'no_data'.tr);
          return state.items.isEmpty
              ? NoDataView(text: 'no_data'.tr)
              : ListView.builder(
                  shrinkWrap: true,
                  // data: state.items,
                  itemCount: state.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    ConversationModel model = state.items[index];
                    debugPrint(
                        "computeAvatar ${model.computeAvatar.length} ${model.computeAvatar.toString()}");
                    return n.Column([
                      ListTile(
                        leading: ComputeAvatar(
                          imgUri: model.avatar,
                          computeAvatar: model.computeAvatar,
                        ),
                        contentPadding: const EdgeInsets.only(
                          left: 10,
                          right: 10,
                        ),
                        title: n.Row([
                          Expanded(
                            child: Text(strEmpty(model.title)
                                ? model.computeTitle
                                : model.title),
                          )
                        ]),
                        // subtitle: Text('${model.remark}'),
                        onTap: () {
                          Get.to(
                            () => ChatPage(
                              peerId: model.peerId,
                              peerTitle: model.title,
                              peerAvatar: model.avatar,
                              peerSign: '',
                              // computeTitle: model.computeTitle,
                              type: 'C2G',
                              options:  const {'popTime':2, 'memberCount': 0},
                              // options:  {'popTime':2, 'memberCount': model.memberCount},
                            ),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        },
                      ),
                      n.Padding(
                        left: 12,
                        right: 20,
                        bottom: 10,
                        child: HorizontalLine(
                          height: Get.isDarkMode ? 0.5 : 1.0,
                        ),
                      ),
                    ]);
                  },
                  // 解决联系人数据量少的情况下无法刷新的问题
                  // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                  physics: const AlwaysScrollableScrollPhysics(),
                );
        })));
  }
}
