import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

import 'group_list_logic.dart';

class GroupListPage extends StatelessWidget {
  GroupListPage({super.key});

  final logic = Get.put(GroupListLogic());
  final state = Get.find<GroupListLogic>().state;

  /// Load group data
  void initData() async {
    if (state.page == 1) {
      List<GroupModel> list = await logic.page(
        page: state.page,
        size: state.size,
      );
      List<GroupModel> list2 = [];
      for (GroupModel m in list) {
        if (strEmpty(m.title)) {
          m.computeTitle = await logic.computeTitle(m.groupId);
        }
        list2.add(m);
      }
      state.groupList.value = list2;
      state.page += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        titleWidget: Obx(() => Text(
          "${'group_chat'.tr}(${state.groupList.length})",
        )),
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          // color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 10, right: 8, bottom: 10),
                child: searchBar(
                  context,
                  searchLabel: 'search'.tr,
                  hintText: 'search'.tr,
                  queryTips: 'group_search_tips'.tr,
                  doSearch: ((query) => GroupRepo().search(kwd: query)),
                  onTapForItem: (model) {
                    if (model is GroupModel) {
                      Get.to(
                            () => ChatPage(
                          peerId: model.groupId,
                          peerTitle: model.title,
                          peerAvatar: model.avatar,
                          peerSign: '',
                          type: 'C2G',
                          options: {'memberCount': model.memberCount},
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    }
                  },
                ),
              ),
              Expanded(
                child: SlidableAutoCloseBehavior(
                  child: Obx(() {
                    return state.groupList.isEmpty
                        ? NoDataView(text: 'no_data'.tr)
                        : ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.groupList.length,
                      itemBuilder: (BuildContext context, int index) {
                        GroupModel model = state.groupList[index];
                        return Column(
                          children: [
                            ListTile(
                              leading: SmartGroupAvatar(
                                avatar: model.avatar,
                                groupId: model.groupId,
                              ),
                              contentPadding: const EdgeInsets.only(left: 10, right: 10),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        strEmpty(model.title)
                                            ? model.computeTitle
                                            : model.title,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface, // 使用主题文字色
                                        ),
                                    ),
                                  )
                                ],
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0), // 增加圆角
                              ),
                              onTap: () {
                                Get.to(
                                      () => ChatPage(
                                    peerId: model.groupId,
                                    peerTitle: model.title,
                                    peerAvatar: model.avatar,
                                    peerSign: '',
                                    type: 'C2G',
                                    options: {'memberCount': model.memberCount},
                                  ),
                                  transition: Transition.rightToLeft,
                                  popGesture: true,
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 12, right: 20, bottom: 10),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}