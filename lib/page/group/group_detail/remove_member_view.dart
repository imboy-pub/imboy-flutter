import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/page/group/launch_chat/launch_chat_logic.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';

class RemoveMemberPage extends StatefulWidget {
  final String groupId;

  const RemoveMemberPage({super.key, required this.groupId});

  @override
  RemoveMemberPageState createState() => RemoveMemberPageState();
}

class RemoveMemberPageState extends State<RemoveMemberPage> {
  final LaunchChatLogic logic = Get.put(LaunchChatLogic());

  final int _itemHeight = 60;
  List<GroupMemberModel> groupMemberList = [];

  String selectsTips = '';
  List<GroupMemberModel> selects = [];

  @override
  void initState() {
    super.initState();
    initData();
  }

  void initData() async {
    List<GroupMemberModel> list = await (GroupMemberRepo()).page(
        limit: 2000,
        where: "${GroupMemberRepo.groupId} = ?",
        whereArgs: [widget.groupId]);
    groupMemberList = [];
    for (GroupMemberModel obj in list) {
      if (obj.userId == UserRepoLocal.to.currentUid) {
        continue;
      }
      // 是否加入的群： 1 是 0 否 （0 是群创建者或者拥有者; 1 是 成员 嘉宾 管理员等）
      if (obj.isJoin == 0) {
        continue;
      }
      groupMemberList.add(obj);
    }
    if (mounted) {
      setState(() {});
    }
    iPrint(
        "remove_member_view/loadData ${widget.groupId} ${groupMemberList.length}");
  }

  Widget _buildListItem(BuildContext context, GroupMemberModel model) {
    // String susTag = model.getSuspensionTag();
    return n.Column([
      SizedBox(
        height: _itemHeight.toDouble(),
        child: Obx(() => InkWell(
              onTap: () {
                // debugPrint(" item_onTap ${model.selected}");
                model.selected.value = !model.selected.value;
                if (model.selected.isTrue) {
                  selects.insert(0, model);
                } else {
                  selects.remove(model);
                }
                if (selects.isNotEmpty) {
                  selectsTips = '(${selects.length})';
                } else {
                  selectsTips = '';
                }
                setState(() {});
              },
              child: n.Row([
                n.Padding(
                  left: 16,
                  right: 8,
                  child: Icon(
                    model.selected.isTrue
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.check_mark_circled,
                    color: model.selected.isTrue ? Colors.green : Colors.grey,
                  ),
                ),
                Avatar(
                  imgUri: model.avatar,
                  width: 49,
                  height: 49,
                ),
                const Space(),
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    height: _itemHeight.toDouble(),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          width: Get.isDarkMode ? 0.5 : 1.0,
                          color: Theme.of(Get.context!)
                              .colorScheme
                              .primaryContainer,
                        ),
                      ),
                    ),
                    child: n.Row([
                      Expanded(
                        flex: 3,
                        child: Text(
                          model.alias.isEmpty ? model.nickname : model.alias,
                          style: const TextStyle(fontSize: 14.0),
                        ),
                      ),
                      // const Spacer(), // Spacer 会自动填充可用空间
                      Expanded(
                          flex: 1,
                          child: IconButton(
                        // tooltip: 'info'.tr,
                        icon: const Icon(
                          Icons.info_outline,
                          // color: Theme.of(Get.context!).colorScheme.onPrimary,
                          color: Colors.green,
                        ),
                        padding: const EdgeInsets.only(left: 8, right: 8),
                        onPressed: () {
                          Get.to(
                            () => PeopleInfoPage(
                              id: model.userId,
                              scene: 'contact_page',
                            ),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        },
                      )),
                    ]) // 两端对齐
                      ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
                  ),
                ),
              ]),
            )),
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        title: 'remove_member'.tr,
        leading: n.Padding(
          top: 8,
          child: TextButton(
            onPressed: () {
              // Navigator.of(context).pop();
              Get.back(result: null);
            },
            child: Text(
              'button_cancel'.tr,
              style: TextStyle(
                  color: Theme.of(Get.context!).colorScheme.onPrimary),
            ),
            // child: Icon(
            //   Icons.close,
            //   color: Theme.of(Get.context!).colorScheme.onPrimary,
            // ),
          ),
        ),
        rightDMActions: <Widget>[
          RoundedElevatedButton(
              text: '${'button_accomplish'.tr}$selectsTips',
              highlighted: selects.isNotEmpty,
              onPressed: () async {
                // var nav = Navigator.of(context);
                if (selects.isEmpty) {
                  return;
                }
                EasyLoading.show(status: 'loading'.tr);
                int memberCount = selects.length;
                iPrint("selects $memberCount ${selects.toList().toString()}");
                bool res = await logic.leaveGroup(widget.groupId, selects);
                EasyLoading.dismiss();
                if (res) {
                  logic.resetData();
                  // nav.pop();
                  Get.back(result: selects);
                } else {
                  EasyLoading.showError('tip_failed'.tr);
                }
              }),
          const SizedBox(width: 10)
        ],
      ),
      body: SingleChildScrollView(
          // 包裹一个可滚动的容器
          child: n.Column([
        /* TODO leeyi 2024-04-12 00:05:34
        n.Row([
          Expanded(
              child: n.Padding(
            left: 8,
            top: 0,
            right: 8,
            bottom: 10,
            child: searchBar(
              context,
              searchLabel: 'search'.tr,
              hintText: 'search'.tr,
              queryTips: '',
              doSearch: ((query) async {
                debugPrint("launch_chat_view doSearch ${query.toString()}");
                List<ContactModel> li = await ContactRepo().search(kwd: query);
                return li;
              }),
              onTapForItem: (value) {
                debugPrint("launch_chat_view value ${value is ContactModel}, ${value.toString()}");
                if (value is ContactModel) {
                  //   Get.to(
                  //     () => PeopleInfoPage(
                  //       id: value.deniedUid,
                  //       scene: 'denylist',
                  //     ),
                  //     transition: Transition.rightToLeft,
                  //     popGesture: true, // 右滑，返回上一页
                  //   );
                }
              },
            ),
          )),
        ]),
        */
        n.Row([
          Expanded(
              child: SingleChildScrollView(
            child: Container(
              width: Get.width,
              // height: Get.height - 150,
              height: Get.height,
              color: Theme.of(context).colorScheme.surface,
              child: n.Column([
                Expanded(
                  child: SlidableAutoCloseBehavior(
                      child: groupMemberList.isEmpty
                          ? NoDataView(text: 'no_data'.tr)
                          : ListView.builder(
                              shrinkWrap: true,
                              // data: groupMemberList,
                              itemCount: groupMemberList.length,
                              itemBuilder: (BuildContext context, int index) {
                                GroupMemberModel model = groupMemberList[index];
                                return _buildListItem(context, model);
                              },
                              // 解决联系人数据量少的情况下无法刷新的问题
                              // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                              physics: const AlwaysScrollableScrollPhysics(),
                            )),
                ),
              ], mainAxisSize: MainAxisSize.min),
            ),
          ))
        ]),
      ])),
    );
  }
}
