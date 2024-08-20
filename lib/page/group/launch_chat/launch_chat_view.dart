import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_view.dart';
import 'package:imboy/page/group/group_select/group_select_view.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/const.dart';

import 'launch_chat_logic.dart';
import 'launch_chat_state.dart';

/// 发起聊天页面
class LaunchChatPage extends StatelessWidget {
  final LaunchChatLogic logic = Get.put(LaunchChatLogic());
  final LaunchChatState state = Get.find<LaunchChatLogic>().state;

  final int _itemHeight = 60;

  LaunchChatPage({super.key});

  void loadData() async {
    logic.listFriend();
  }

  Widget _buildListItem(BuildContext context, ContactModel model) {
    // String susTag = model.getSuspensionTag();
    return n.Column([
      SizedBox(
        height: _itemHeight.toDouble(),
        child: Obx(() => InkWell(
              onTap: () {
                debugPrint(" item_onTap ${model.selected}");
                model.selected.value = !model.selected.value;
                if (model.selected.isTrue) {
                  state.selects.insert(0, model);
                } else {
                  state.selects.remove(model);
                }
                if (state.selects.value.isNotEmpty) {
                  state.selectsTips.value = '(${state.selects.value.length})';
                } else {
                  state.selectsTips.value = '';
                }
                // setState(() {});
              },
              child: n.Row([
                n.Padding(
                  left: 8,
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
                    padding: const EdgeInsets.only(right: 30),
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
                    child: Text(
                      model.title,
                      style: const TextStyle(fontSize: 14.0),
                    ),
                  ),
                ),
              ]),
            )),
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        title: 'select_contacts'.tr,
        leadingWidth: 72,
        leading: n.Padding(
          top: 8,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'button_cancel'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 14.0,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
        rightDMActions: <Widget>[
          Obx(
            () => RoundedElevatedButton(
                text:
                    '${'button_accomplish'.tr}${logic.state.selectsTips.value}',
                highlighted: logic.state.selects.isNotEmpty,
                onPressed: () async {
                  // var nav = Navigator.of(context);
                  EasyLoading.show(status: 'loading'.tr);
                  int memberCount = logic.state.selects.length;
                  iPrint("logic.state.selects $memberCount ${logic.state.selects.toJson()}");
                  GroupModel? m =
                      await logic.groupAdd(logic.state.selects.value);
                  if (m != null) {
                    EasyLoading.dismiss();
                    logic.resetData();
                    Get.to(
                      () => ChatPage(
                          peerId: m.groupId,
                          type: 'C2G',
                          peerTitle: m.title,
                          peerAvatar: m.avatar,
                          peerSign: '',
                          options: {'memberCount': memberCount + 1}),
                      transition: Transition.rightToLeft,
                      popGesture: true, // 右滑，返回上一页
                      // binding: ChatBinding(),
                    );
                  }
                }),
          ),
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
              height: Get.height - 150,
              color: Theme.of(context).colorScheme.surface,
              child: n.Column([
                n.ListTile(
                  title: Text('select_a_group'.tr),
                  trailing: navigateNextIcon,
                  onTap: () {
                    Get.to(
                      () => GroupSelectPage(),
                      transition: Transition.rightToLeft,
                      popGesture: true, // 右滑，返回上一页
                    );
                  },
                ),
                n.Padding(left: 18, child: const Divider()),
                n.ListTile(
                  title: Text('create_group_f2f'.tr),
                  trailing: navigateNextIcon,
                  onTap: () {
                    Get.to(
                      () => FaceToFacePage(),
                      // () => FaceToFaceConfirmPage(
                      //   code: '1258',
                      // ),
                      transition: Transition.rightToLeft,
                      popGesture: true, // 右滑，返回上一页
                    );
                  },
                ),
                n.Padding(left: 18, child: const Divider()),
                Expanded(
                  child: SlidableAutoCloseBehavior(child: Obx(() {
                    return logic.state.items.isEmpty
                        ? NoDataView(text: 'no_data'.tr)
                        : AzListView(
                            data: logic.state.items,
                            itemCount: logic.state.items.length,
                            itemBuilder: (BuildContext context, int index) {
                              ContactModel model = logic.state.items[index];
                              // debugPrint(
                              //     "model.avatar ${model.avatar.toString()}: ${model.toJson().toString()}");
                              return _buildListItem(context, model);
                            },
                            // 解决联系人数据量少的情况下无法刷新的问题
                            // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                            physics: const AlwaysScrollableScrollPhysics(),
                            susItemBuilder: (BuildContext context, int index) {
                              ContactModel model = logic.state.items[index];
                              if ('↑' == model.getSuspensionTag()) {
                                return Container();
                              }
                              return Get.find<ContactLogic>().getSusItem(
                                context,
                                model.getSuspensionTag(),
                              );
                            },
                            // indexBarData: const ['↑', ...kIndexBarData],
                            indexBarData: logic.state.items.isNotEmpty
                                ? ['↑', ...logic.state.currIndexBarData]
                                : [],
                            indexBarOptions: IndexBarOptions(
                              needRebuild: true,
                              ignoreDragCancel: true,
                              downTextStyle: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              downItemDecoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                              indexHintWidth: 128 / 2,
                              indexHintHeight: 128 / 2,
                              indexHintDecoration: BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    AssetsService.getImgPath(
                                        'index_bar_bubble_gray'),
                                  ),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              indexHintAlignment: Alignment.centerRight,
                              indexHintChildAlignment:
                                  const Alignment(-0.25, 0.0),
                              indexHintOffset: const Offset(-20, 0),
                            ),
                          );
                  })),
                ),
              ], mainAxisSize: MainAxisSize.min),
            ),
          ))
        ]),
      ])),
    );
  }
}
