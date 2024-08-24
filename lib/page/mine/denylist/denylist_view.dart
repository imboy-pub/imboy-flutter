import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

import 'denylist_logic.dart';

// ignore: must_be_immutable
class DenylistPage extends StatelessWidget {
  final DenylistLogic logic = Get.put(DenylistLogic());

  int page = 1;
  int size = 1000;

  bool isSearch = false;
  bool showBtn = false;
  bool isResult = false;

  DenylistPage({super.key});

  /// 加载好友申请数据
  void initData() async {
    var list = await DenylistLogic.page(page: page, size: size);
    logic.handleList(list);
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'denylist'.tr,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Theme.of(context).colorScheme.surface,
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
                  return UserDenylistRepo().search(kwd: query);
                }),
                onTapForItem: (value) {
                  // debugPrint(
                  //     "> on search value ${value is DenylistModel}, ${value.toString()}");
                  if (value is DenylistModel) {
                    Get.to(
                      () => PeopleInfoPage(
                        id: value.deniedUid,
                        scene: 'denylist',
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
                return logic.items.isEmpty
                    ? NoDataView(text: 'no_data'.tr)
                    : AzListView(
                        data: logic.items,
                        itemCount: logic.items.length,
                        itemBuilder: (BuildContext context, int index) {
                          DenylistModel model = logic.items[index];
                          // debugPrint(
                          //     "model.avatar ${model.avatar.toString()}: ${model.toJson().toString()}");
                          return n.Column([
                            ListTile(
                              leading: Avatar(imgUri: model.avatar),
                              contentPadding: const EdgeInsets.only(left: 10),
                              title: Text(model.nickname),
                              // subtitle: Text('${model.remark}'),
                              onTap: () {
                                Get.to(
                                  () => PeopleInfoPage(
                                    id: model.deniedUid,
                                    scene: 'denylist',
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
                        susItemBuilder: (BuildContext context, int index) {
                          DenylistModel model = logic.items[index];
                          if ('↑' == model.getSuspensionTag()) {
                            return Container();
                          }
                          return Get.find<ContactLogic>().getSusItem(
                            context,
                            model.getSuspensionTag(),
                          );
                        },
                        // indexBarData: const ['↑', ...kIndexBarData],
                        indexBarData: logic.items.isNotEmpty
                            ? ['↑', ...logic.currIndexBarData]
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
                          indexHintChildAlignment: const Alignment(-0.25, 0.0),
                          indexHintOffset: const Offset(-20, 0),
                        ),
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
