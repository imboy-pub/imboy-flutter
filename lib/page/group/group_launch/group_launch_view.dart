import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

import 'group_launch_logic.dart';
import 'group_launch_state.dart';

/// 发起群聊页面
class GroupLaunchPage extends StatelessWidget {
  final GroupLaunchLogic logic = Get.put(GroupLaunchLogic());
  final GroupLaunchState state = Get.find<GroupLaunchLogic>().state;

  GroupLaunchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      // appBar: PageAppBar(title: '选择联系人'.tr),
      appBar: NavAppBar(
        title: '选择联系人'.tr,
        leading: n.Padding(
          top: 8,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'button_cancel'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14.0,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
        rightDMActions: <Widget>[
          Obx(
            () => ElevatedButton(
              onPressed: () async {
                // var nav = Navigator.of(context);
                // bool res = await outCallback(logic.selectedVal.value);
                // iPrint("logic.selectedVal.value ${logic.selectedVal.value}");
                // if (res) {
                //   int t = logic.selectedVal.value.split(" ").length;
                //   // iPrint("logic.selectedVal.value $t");
                //   for (var i = 0; i < t; i++) {
                //     nav.pop();
                //   }
                // }
              },
              // ignore: sort_child_properties_last
              child: Text(
                'button_accomplish'.tr,
                textAlign: TextAlign.center,
              ),
              style: logic.state.valueChanged.isTrue
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        AppColors.primaryElement,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        Colors.white,
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    )
                  : ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        AppColors.AppBarColor,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        AppColors.LineColor,
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
            ),
          )
        ],
      ),

      body: n.Column([
        n.Row([
          Expanded(
              child: n.Padding(
            left: 8,
            top: 0,
            right: 8,
            bottom: 10,
            child: searchBar(
              context,
              searchLabel: '搜索'.tr,
              hintText: '搜索'.tr,
              queryTips: ''.tr,
              doSearch: ((query) {
                // debugPrint(
                //     "> on search doSearch ${query.toString()}");
                return ContactRepo().search(kwd: query);
              }),
              onTapForItem: (value) {
                // debugPrint(
                //     "> on search value ${value is DenylistModel}, ${value.toString()}");
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
        n.Row([
          Expanded(
              child: SingleChildScrollView(
            child: Container(
              width: Get.width,
              height: Get.height - 150,
              color: AppColors.BgColor,
              child: n.Column([
                n.ListTile(
                  title: Text('选择一个群'.tr),
                  trailing: Icon(
                    Icons.navigate_next,
                    color: AppColors.MainTextColor.withOpacity(0.5),
                  ),
                  onTap: () {
                    // Get.to(
                    //       () => MarkdownPage(
                    //     title: '更新日志'.tr,
                    //     url:
                    //     "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                    //   ),
                    //   transition: Transition.rightToLeft,
                    //   popGesture: true, // 右滑，返回上一页
                    // );
                  },
                ),
                n.Padding(left: 18, child: const Divider()),
                n.ListTile(
                  title: Text('面对面建群'.tr),
                  trailing: Icon(
                    Icons.navigate_next,
                    color: AppColors.MainTextColor.withOpacity(0.5),
                  ),
                  onTap: () {
                    // Get.to(
                    //       () => MarkdownPage(
                    //     title: '更新日志'.tr,
                    //     url:
                    //     "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                    //   ),
                    //   transition: Transition.rightToLeft,
                    //   popGesture: true, // 右滑，返回上一页
                    // );
                  },
                ),
                n.Padding(left: 18, child: const Divider()),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SlidableAutoCloseBehavior(child: Obx(() {
                      return logic.state.items.isEmpty
                          ? NoDataView(text: '暂无数据'.tr)
                          : AzListView(
                              data: logic.state.items,
                              itemCount: logic.state.items.length,
                              itemBuilder: (BuildContext context, int index) {
                                ContactModel model = logic.state.items[index];
                                // debugPrint(
                                //     "model.avatar ${model.avatar.toString()}: ${model.toJson().toString()}");
                                return ListTile(
                                  leading: Avatar(imgUri: model.avatar),
                                  contentPadding:
                                      const EdgeInsets.only(left: 10),
                                  title: Text(model.nickname),
                                  // subtitle: Text('${model.remark}'),
                                  onTap: () {
                                    // Get.to(
                                    //   () => PeopleInfoPage(
                                    //     id: model.deniedUid,
                                    //     scene: 'denylist',
                                    //   ),
                                    //   transition: Transition.rightToLeft,
                                    //   popGesture: true, // 右滑，返回上一页
                                    // );
                                  },
                                );
                              },
                              // 解决联系人数据量少的情况下无法刷新的问题
                              // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                              physics: const AlwaysScrollableScrollPhysics(),
                              susItemBuilder:
                                  (BuildContext context, int index) {
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
                                          'ic_index_bar_bubble_gray'),
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
                ),
              ], mainAxisSize: MainAxisSize.min),
            ),
          ))
        ]),
      ]),
    );
  }
}
