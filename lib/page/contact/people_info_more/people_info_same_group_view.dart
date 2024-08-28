import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';

// ignore: must_be_immutable
class PeopleInfoSameGroupPage extends StatelessWidget {
  final List<GroupModel> groupList;

  const PeopleInfoSameGroupPage({
    super.key,
    required this.groupList,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'mutual_groups_with_her'.tr,
        // backgroundColor: Colors.white,
      ),
      body: n.Column([
        /*
            n.Padding(
              left: 8,
              top: 10,
              right: 8,
              bottom: 10,
              child: searchBar(
                context,
                searchLabel: 'search'.tr,
                hintText: 'search'.tr,
                queryTips: 'group_search_tips'.tr,
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
            */
        Expanded(
            child: SingleChildScrollView(
          child: n.Padding(
            top: 10,
            child: SlidableAutoCloseBehavior(
              child: groupList.isEmpty
                  ? NoDataView(text: 'no_data'.tr)
                  : ListView.builder(
                      shrinkWrap: true,
                      // data: state.groupList,
                      itemCount: groupList.length,
                      itemBuilder: (BuildContext context, int index) {
                        GroupModel model = groupList[index];
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
                    ),
            ),
          ),
        )),
        n.Padding(
          top: 8,
          bottom: 8,
          child: Text('num_unit'.trArgs(['${groupList.length}'])),
        )
      ])
        ..mainAxisSize = MainAxisSize.min,
    );
  }
}
