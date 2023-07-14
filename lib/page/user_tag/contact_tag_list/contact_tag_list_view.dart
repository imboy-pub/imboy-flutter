import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_view.dart';
import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_view.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:niku/namespace.dart' as n;

import 'contact_tag_list_logic.dart';

// ignore: must_be_immutable
class ContactTagListPage extends StatelessWidget {
  final logic = Get.put(ContactTagListLogic());
  final state = Get.find<ContactTagListLogic>().state;
  ScrollController controller = ScrollController();

  ContactTagListPage({super.key});

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
        rightDMActions: <Widget>[
          InkWell(
            child: const SizedBox(
              width: 46.0,
              child: Icon(
                Icons.add,
                color: Colors.black54,
              ),
            ),
            onTap: () {
              // Get.close(0);
              Get.bottomSheet(
                n.Padding(
                  // top: 80,
                  child: UserTagSavePage(scene: 'friend'),
                ),
              );
            },
          ),
        ],
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
                    trailing: state.kwd.isEmpty
                        ? null
                        : [
                            InkWell(
                              onTap: () {
                                state.kwd.value = '';
                                state.searchController.text = '';
                                logic.doSearch(state.kwd.value);
                              },
                              child: const Icon(Icons.close),
                            )
                          ],
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
                                      extentRatio: 0.75,
                                      motion: const StretchMotion(),
                                      children: [
                                        SlidableAction(
                                          key: ValueKey("change_name_$index"),
                                          flex: 2,
                                          backgroundColor: Colors.black87,
                                          // foregroundColor: Colors.white,
                                          onPressed: (_) async {
                                            Get.bottomSheet(
                                              n.Padding(
                                                // top: 80,
                                                child: UserTagSavePage(
                                                  tag: obj,
                                                  scene: 'friend',
                                                ),
                                              ),
                                            );
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
                                            Get.bottomSheet(
                                              SizedBox(
                                                width: Get.width,
                                                height: 172,
                                                child: n.Wrap(
                                                  [
                                                    Center(
                                                      child: n.Padding(
                                                        top: 16,
                                                        bottom: 16,
                                                        child: Text(
                                                          '删除标签后，标签中的联系人不会被删除'
                                                              .tr,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                            // color: Colors.white,
                                                            fontSize: 16.0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const Divider(),
                                                    Center(
                                                      child: TextButton(
                                                        onPressed: () async {
                                                          const String scene =
                                                              'friend';
                                                          bool res = await logic
                                                              .deleteTag(
                                                                  tagId:
                                                                      obj.tagId,
                                                                  tagName:
                                                                      obj.name,
                                                                  scene: scene);
                                                          if (res) {
                                                            Get.find<
                                                                    ContactTagListLogic>()
                                                                .replaceObjectTag(
                                                                    scene:
                                                                        scene,
                                                                    oldName: obj
                                                                        .name,
                                                                    newName:
                                                                        '');

                                                            final index = state
                                                                .items
                                                                .indexWhere((e) =>
                                                                    e.tagId ==
                                                                    obj.tagId);
                                                            if (index > -1) {
                                                              state.items
                                                                  .removeAt(
                                                                      index);
                                                            }
                                                            Get.close(1);
                                                            EasyLoading
                                                                .showSuccess(
                                                                    '操作成功'.tr);
                                                          } else {
                                                            EasyLoading
                                                                .showError(
                                                                    '操作失败'.tr);
                                                          }
                                                        },
                                                        child: Text(
                                                          '删除'.tr,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 16.0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const HorizontalLine(
                                                        height: 6),
                                                    Center(
                                                      child: TextButton(
                                                        onPressed: () =>
                                                            Get.back(),
                                                        child: Text(
                                                          'button_cancel'.tr,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                            // color: Colors.white,
                                                            fontSize: 16.0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                              backgroundColor: Colors.white,
                                              //改变shape这里即可
                                              shape:
                                                  const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.only(
                                                  topLeft:
                                                      Radius.circular(20.0),
                                                  topRight:
                                                      Radius.circular(20.0),
                                                ),
                                              ),
                                            );
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
                                          // Tag详情
                                          Get.to(
                                            () =>
                                                ContactTagDetailPage(tag: obj),
                                            transition: Transition.rightToLeft,
                                            popGesture: true, // 右滑，返回上一页
                                          );
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
                                            Expanded(
                                                flex: 1,
                                                child: Text(
                                                  obj.subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.MainTextColor,
                                                    fontSize: 14.0,
                                                  ),
                                                )),
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
