import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:niku/namespace.dart' as n;
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'contact_tag_logic.dart';

// ignore: must_be_immutable
class ContactTagPage extends StatelessWidget {
  ContactTagPage({super.key});

  final logic = Get.put(ContactTagLogic());
  final state = Get.find<ContactTagLogic>().state;
  ScrollController controller = ScrollController();

  void initData() async {
    state.page = 1;
    var list = await logic.page(
        page: state.page, size: state.size, kwd: state.kwd.value);
    if (list.isNotEmpty) {
      state.items.addAll(list);
      state.page += 1;
    }

    controller.addListener(() async {
      double pixels = controller.position.pixels;
      double maxScrollExtent = controller.position.maxScrollExtent;
      // debugPrint("RefreshIndicator_collect_ $pixels; $maxScrollExtent; ");
      // 滑动到底部，执行加载更多操作
      if (pixels == maxScrollExtent) {
        var list = await logic.page(
            page: state.page, size: state.size, kwd: state.kwd.value);
        if (list.isNotEmpty) {
          state.items.addAll(list);
          state.page = state.page + 1;
        } else {
          EasyLoading.showToast('没有更多数据了'.tr);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '联系人标签'.tr,
      ),
      body: RefreshIndicator(
        // color: Colors.white,
        onRefresh: () async {
          // 检查网络状态
          var res = await Connectivity().checkConnectivity();
          if (res == ConnectivityResult.none) {
            String msg = 'tip_connect_desc'.tr;
            EasyLoading.showInfo(' $msg        ');
            return;
          }
        },
        child: Obx(() => n.Column(
              [
                n.Padding(
                  left: 8,
                  top: 2,
                  right: 8,
                  bottom: 2,
                  child: searchBar(
                    context,
                    leading: state.searchLeading?.value ??
                        InkWell(
                          onTap: () {
                            logic.doSearch(state.kwd);
                          },
                          child: const Icon(Icons.search),
                        ),
                    trailing: state.kwd.isEmpty ? null : [InkWell(
                      onTap: () {
                        state.kwd.value = '';
                        state.searchController.text = '';
                        logic.doSearch(state.kwd.value);
                      },
                      child: const Icon(Icons.close),
                    )],
                    controller: state.searchController,
                    searchLabel: '搜索'.tr,
                    hintText: '搜索'.tr,
                    // queryTips: '收藏人名、群名、标签等'.tr,
                    onChanged: ((query) {
                      state.kwd.value = query;
                      debugPrint(
                          "contact_tag_view_onChanged ${query.toString()}");
                      logic.doSearch(state.kwd.value);
                    }),
                    doSearch: logic.doSearch,
                  ),
                ),
                Expanded(
                  child: n.Padding(
                    left: 8,
                    right: 8,
                    child: SlidableAutoCloseBehavior(
                        child: state.items.isEmpty
                            ? NoDataView(text: '暂无数据'.tr)
                            : ListView.builder(
                                controller: controller,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: state.items.length,
                                itemBuilder: (BuildContext context, int index) {
                                  UserTagModel obj = state.items[index];
                                  return Slidable(
                                    key: ValueKey(obj.tagId),
                                    groupTag: '0',
                                    closeOnScroll: true,
                                    endActionPane: ActionPane(
                                      // extentRatio: 0.5,
                                      motion: const StretchMotion(),
                                      children: [
                                        SlidableAction(
                                          key: ValueKey("change_name_$index"),
                                          flex: 1,
                                          backgroundColor: Colors.black87,
                                          // foregroundColor: Colors.white,
                                          onPressed: (_) async {
                                            // bool res =
                                            // await logic.remove(obj);
                                            // debugPrint(
                                            //     "user_collect_remove $res; i $index");
                                            // if (res) {
                                            //   state.items.removeAt(index);
                                            //   // logic.update(state.items);
                                            // }
                                          },
                                          // icon: Icons.delete_forever_sharp,
                                          label: "修改名称".tr,
                                          spacing: 1,
                                        ),
                                        SlidableAction(
                                          key: ValueKey("delete_$index"),
                                          flex: 1,
                                          backgroundColor: Colors.red,
                                          // foregroundColor: Colors.white,
                                          onPressed: (_) async {
                                            // bool res =
                                            // await logic.remove(obj);
                                            // debugPrint(
                                            //     "user_collect_remove $res; i $index");
                                            // if (res) {
                                            //   state.items.removeAt(index);
                                            //   // logic.update(state.items);
                                            // }
                                          },
                                          // icon: Icons.delete_forever_sharp,
                                          label: "删除".tr,
                                          spacing: 1,
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      // width: Get.width - 24,
                                      // height: Get.height - 125,
                                      color: Colors.white,
                                      margin:
                                          const EdgeInsets.fromLTRB(0, 0, 0, 2),
                                      padding: const EdgeInsets.all(10),
                                      // decoration: BoxDecoration(
                                      //   color: Colors.white,
                                      //   borderRadius:
                                      //   BorderRadius.circular(8),
                                      // ),
                                      child: InkWell(
                                        onTap: () {
                                          // 收藏详情
                                          // Get.to(
                                          //       () => UserCollectDetailPage(
                                          //     obj: obj,
                                          //     pageIndex: index,
                                          //   ),
                                          //   transition:
                                          //   Transition.rightToLeft,
                                          //   popGesture: true, // 右滑，返回上一页
                                          // );
                                        },
                                        child: n.Column([
                                          // logic.buildItemBody(obj, 'page'),
                                          // n.Row(const [SizedBox(height: 16)]),
                                          n.Row([
                                            Text(
                                              obj.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              ' (${obj.refererTime})',
                                              style: const TextStyle(
                                                color: AppColors.MainTextColor,
                                                // fontSize: 14.0,
                                              ),
                                            ),
                                          ]),
                                          n.Row([
                                            Text(
                                              obj.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.MainTextColor,
                                                fontSize: 14.0,
                                              ),
                                            ),
                                          ]),
                                        ]),
                                      ),
                                    ),
                                  );
                                },
                              )),
                  ),
                ),
              ],
              mainAxisSize: MainAxisSize.min,
            )),
      ),
    );
  }
}
