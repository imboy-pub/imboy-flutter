import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/config/theme.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
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

  /// 加载好友申请数据
  void initData() async {
    if (state.page == 1) {
      // state.groupList.value = await logic.page(page: page, size: size);
      List<GroupModel> list =
          await logic.page(page: state.page, size: state.size);
      List<GroupModel> list2 = [];
      for (GroupModel m in list) {
        if (strEmpty(m.title)) {
          m.computeTitle = await logic.computeTitle(m.groupId);
        }
        if (strEmpty(m.avatar)) {
          m.computeAvatar = await logic.computeAvatar(m.groupId);
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
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        // title: "${'group_chat'.tr}(${state.groupList.length})",
        titleWidget: Obx(() => Text(
              "${'group_chat'.tr}(${state.groupList.length})",
              style: AppStyle.navAppBarTitleStyle,
            )),
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Theme.of(context).colorScheme.background,
          child: n.Column([
            n.Padding(
              left: 8,
              top: 10,
              right: 8,
              bottom: 10,
              child: searchBar(
                context,
                searchLabel: 'search'.tr,
                hintText: 'search'.tr,
                queryTips: 'search_friends_tips'.tr,
                doSearch: ((query) {
                  // debugPrint(
                  //     "> on search doSearch ${query.toString()}");
                  return GroupRepo().search(kwd: query);
                }),
                onTapForItem: (model) {
                  // debugPrint(
                  //     "> on search value ${value is GroupModel}, ${value.toString()}");
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
                      popGesture: true, // 右滑，返回上一页
                    );
                  }
                },
              ),
            ),
            Expanded(
              child: SlidableAutoCloseBehavior(child: Obx(() {
                // return NoDataView(text: 'no_data'.tr);
                return state.groupList.isEmpty
                    ? NoDataView(text: 'no_data'.tr)
                    : ListView.builder(
                        shrinkWrap: true,
                        // data: state.groupList,
                        itemCount: state.groupList.length,
                        itemBuilder: (BuildContext context, int index) {
                          GroupModel model = state.groupList[index];
                          debugPrint(
                              "computeAvatar ${model.computeAvatar.length} ${model.computeAvatar.toString()}");
                          return n.Column([
                            ListTile(
                              leading: ComputeAvatar(
                                imgUri: model.avatar,
                                computeAvatar: model.computeAvatar,
                              ),
                              contentPadding:
                                  const EdgeInsets.only(left: 10, right: 10),
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
                                    peerId: model.groupId,
                                    peerTitle: model.title,
                                    peerAvatar: model.avatar,
                                    peerSign: '',
                                    type: 'C2G',
                                    options: {'memberCount': model.memberCount},
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
                                  height: Get.isDarkMode ? 0.5 : 1.0),
                            ),
                          ]);
                        },
                        // 解决联系人数据量少的情况下无法刷新的问题
                        // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                        physics: const AlwaysScrollableScrollPhysics(),
                      );
              })),
            ),
          ])
            ..mainAxisSize = MainAxisSize.min,
        ),
      ),
    );
  }
}
