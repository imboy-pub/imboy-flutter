import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

import 'user_collect_logic.dart';

// ignore: must_be_immutable
class UserCollectPage extends StatelessWidget {
  UserCollectPage({super.key});

  RxBool kindActive = false.obs;

  final logic = Get.put(UserCollectLogic());
  final state = Get.find<UserCollectLogic>().state;
  ScrollController controller = ScrollController();

  void initData() async {
    state.page = 1;
    var list =
        await logic.page(page: state.page, size: state.size, kind: state.kind);
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
            page: state.page, size: state.size, kind: state.kind);
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
        title: '我的收藏'.tr,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 检查网络状态
          var res = await Connectivity().checkConnectivity();
          if (res == ConnectivityResult.none) {
            String msg = 'tip_connect_desc'.tr;
            EasyLoading.showInfo(' $msg        ');
            return;
          }
        },
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.ChatBg,
          child: Obx(() => n.Column(
                [
                  n.Padding(
                    left: 8,
                    top: 10,
                    right: 8,
                    bottom: 10,
                    child: searchBar(
                      context,
                      leading: state.searchLeading?.value,
                      searchLabel: '搜索'.tr,
                      hintText: '搜索'.tr,
                      queryTips: '收藏人名、群名、标签等'.tr,
                      doSearch: ((query) {
                        // debugPrint(
                        //     "> on search doSearch ${query.toString()}");
                        return UserCollectRepo().search(kwd: query);
                      }),
                      onTapForItem: (value) {
                        // debugPrint(
                        //     "> on search value ${value is UserCollectModel}, ${value.toString()}");
                        if (value is UserCollectModel) {
                          // Get.to(
                          //   () => PeopleInfoPage(
                          //     id: value.deniedUid,
                          //     sence: 'denylist',
                          //   ),
                          //   transition: Transition.rightToLeft,
                          //   popGesture: true, // 右滑，返回上一页
                          // );
                        }
                      },
                    ),
                  ),
                  _buildKindList(),
                  Expanded(
                    child: SlidableAutoCloseBehavior(
                        child: state.items.isEmpty
                            ? NoDataView(text: '暂无数据'.tr)
                            : n.Padding(
                                top: 16,
                                left: 10,
                                right: 10,
                                child: ListView.builder(
                                  controller: controller,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: state.items.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    UserCollectModel obj = state.items[index];
                                    Widget body = logic.itemBody(obj);
                                    return Slidable(
                                      key: ValueKey(obj.kindId),
                                      groupTag: '0',
                                      closeOnScroll: true,
                                      endActionPane: ActionPane(
                                        extentRatio: 0.5,
                                        motion: const StretchMotion(),
                                        children: [
                                          // SlidableAction(
                                          //   key: ValueKey("hide_$index"),
                                          //   flex: 2,
                                          //   backgroundColor: Colors.amber,
                                          //   onPressed: (_) async {
                                          //     // await logic
                                          //     //     .hideConversation(model.peerId);
                                          //     // logic.update([
                                          //     //   logic.conversations.removeAt(index),
                                          //     //   logic.conversationRemind[
                                          //     //       model.peerId] = 0,
                                          //     //   logic.chatMsgRemindCounter,
                                          //     // ]);
                                          //   },
                                          //   label: "".tr,
                                          //   spacing: 1,
                                          // ),
                                          SlidableAction(
                                            key: ValueKey("delete_$index"),
                                            flex: 1,
                                            backgroundColor: AppColors.ChatBg,
                                            // foregroundColor: Colors.white,
                                            onPressed: (_) async {
                                              // await logic.removeConversation(
                                              //     conversationId);
                                              // logic.update([
                                              //   logic.conversations.removeAt(index),
                                              //   logic.conversationRemind[
                                              //       model.peerId] = 0,
                                              //   logic.chatMsgRemindCounter,
                                              // ]);
                                            },
                                            icon: Icons.delete_forever_sharp,
                                            label: "删除".tr,
                                            spacing: 1,
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            0, 0, 0, 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            // 收藏详情
                                          },
                                          child: n.Column([
                                            body,
                                            n.Row(const [SizedBox(height: 16)]),
                                            n.Row([
                                              Text(
                                                obj.source,
                                                maxLines: 6,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.MainTextColor,
                                                  fontSize: 14.0,
                                                ),
                                              ),
                                              const Expanded(child: SizedBox()),
                                              Text(
                                                state.kind == state.recentUse
                                                    ? DateTimeHelper
                                                        .lastTimeFmt(
                                                            obj.updatedAt)
                                                    : DateTimeHelper
                                                        .lastTimeFmt(
                                                            obj.createdAt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.MainTextColor,
                                                  fontSize: 14.0,
                                                ),
                                              ),
                                            ])
                                              ..mainAxisAlignment =
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                          ]),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )),
                  ),
                ],
                mainAxisSize: MainAxisSize.min,
              )),
        ),
      ),
    );
  }

  Widget _buildKindList() {
    // 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息
    Map<String, String> kindMap = {
      'recent_use': '最近使用',
      '1': '文本',
      '2': '图片',
      '3': '语音',
      '4': '视频',
      '5': '文件',
      '6': '位置消息',
    };
    List<Widget> items = [];
    kindMap.forEach((key, value) {
      items.add(ElevatedButton(
        onPressed: () {
          debugPrint("searchLeading ${state.searchLeading.toString()}");
          kindActive.value = !kindActive.value;
          logic.searchByKind("$key", value, () {
            kindActive.value = !kindActive.value;
          });
        },
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) {
                return Colors.white.withOpacity(0.75);
              }
              // Use the component's default.
              return Colors.white.withOpacity(0.95);
            },
          ),
        ),
        child: Text(
          "  $value  ",
          style: const TextStyle(color: AppColors.MainTextColor),
        ),
      ));
    });
    return Container(
        padding: const EdgeInsets.only(left: 8, right: 8.0),
        color: AppColors.ChatBg,
        child: n.Column(
          [
            ExpansionPanelList(
              expandIconColor: AppColors.ChatBg,
              expansionCallback: (panelIndex, isExpanded) {
                kindActive.value = !kindActive.value;
                debugPrint("kindActive $kindActive");

                // setState(() {});
              },
              children: <ExpansionPanel>[
                ExpansionPanel(
                  backgroundColor: AppColors.ChatBg,
                  headerBuilder: (context, isExpanded) {
                    if (isExpanded) {
                      return n.Row([
                        const SizedBox(width: 10),
                        Icon(
                          Icons.grid_view,
                          size: 18,
                          color: AppColors.MainTextColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 10),
                        Text('类型'.tr),
                      ]);
                    } else {
                      return n.Row([
                        const SizedBox(
                          width: 10,
                          height: 40,
                        ),
                        InkWell(
                          onTap: () {
                            kindActive.value = !kindActive.value;
                            kindActive.value = !kindActive.value;
                            logic.searchByKind(state.recentUse, '最近使用'.tr, () {
                              kindActive.value = !kindActive.value;
                            });
                          },
                          child: Text('最近使用'.tr),
                        ),
                        const SizedBox(width: 40),
                        InkWell(
                          onTap: () {
                            kindActive.value = !kindActive.value;
                            kindActive.value = !kindActive.value;
                            logic.searchByKind('1', '文本'.tr, () {
                              kindActive.value = !kindActive.value;
                            });
                          },
                          child: Text("  ${'文本'.tr}  "),
                        ),
                        const SizedBox(width: 40),
                        InkWell(
                          onTap: () {
                            kindActive.value = !kindActive.value;
                            kindActive.value = !kindActive.value;
                            logic.searchByKind('2', '图片'.tr, () {
                              kindActive.value = !kindActive.value;
                            });
                          },
                          child: Text("  ${'图片'.tr}  "),
                        ),
                        const SizedBox(width: 40),
                        InkWell(
                          onTap: () {
                            kindActive.value = !kindActive.value;
                            kindActive.value = !kindActive.value;
                            logic.searchByKind('4', '视频'.tr, () {
                              kindActive.value = !kindActive.value;
                            });
                          },
                          child: Text("  ${'视频'.tr}  "),
                        ),
                        const SizedBox(width: 40),
                        InkWell(
                          onTap: () {
                            kindActive.value = !kindActive.value;
                            kindActive.value = !kindActive.value;
                            logic.searchByKind('5', '文件'.tr, () {
                              kindActive.value = !kindActive.value;
                            });
                          },
                          child: Text("  ${'文件'.tr}  "),
                        ),
                      ]);
                    }
                  },
                  body: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 14,
                    children: items,
                    // children: [
                    //   ElevatedButton(
                    //       onPressed: () {},
                    //       style: ButtonStyle(
                    //           backgroundColor: MaterialStateProperty.all(
                    //               Colors.white.withOpacity(0.95))
                    //           // backgroundColor:
                    //           //     MaterialStateProperty.resolveWith<Color>(
                    //           //   (Set<MaterialState> states) {
                    //           //     if (states.contains(MaterialState.pressed))
                    //           //       return Colors.red;
                    //           //
                    //           //     // Use the component's default.
                    //           //     return Colors.white.withOpacity(0.7);
                    //           //   },
                    //           // ),
                    //           ),
                    //       child: Text(
                    //         "Football",
                    //         style: TextStyle(color: AppColors.MainTextColor),
                    //       )),
                    //   ElevatedButton(
                    //       onPressed: () {},
                    //       style: ButtonStyle(
                    //           backgroundColor: MaterialStateProperty.all(
                    //               Colors.white.withOpacity(0.95))
                    //           // backgroundColor:
                    //           //     MaterialStateProperty.resolveWith<Color>(
                    //           //   (Set<MaterialState> states) {
                    //           //     if (states.contains(MaterialState.pressed))
                    //           //       return Colors.red;
                    //           //
                    //           //     // Use the component's default.
                    //           //     return Colors.white.withOpacity(0.7);
                    //           //   },
                    //           // ),
                    //           ),
                    //       child: Text(
                    //         "Tennis",
                    //         style: TextStyle(color: AppColors.MainTextColor),
                    //       )),
                    //   ElevatedButton(
                    //       onPressed: () {},
                    //       style: ButtonStyle(
                    //           backgroundColor: MaterialStateProperty.all(
                    //               Colors.white.withOpacity(0.95))
                    //           // backgroundColor:
                    //           //     MaterialStateProperty.resolveWith<Color>(
                    //           //   (Set<MaterialState> states) {
                    //           //     if (states.contains(MaterialState.pressed))
                    //           //       return Colors.red;
                    //           //
                    //           //     // Use the component's default.
                    //           //     return Colors.white.withOpacity(0.7);
                    //           //   },
                    //           // ),
                    //           ),
                    //       child: Text(
                    //         "Fencing",
                    //         style: TextStyle(color: AppColors.MainTextColor),
                    //       )),
                    //   ElevatedButton(
                    //       onPressed: () {},
                    //       style: ButtonStyle(
                    //           backgroundColor: MaterialStateProperty.all(
                    //               Colors.white.withOpacity(0.95))
                    //           // backgroundColor:
                    //           //     MaterialStateProperty.resolveWith<Color>(
                    //           //   (Set<MaterialState> states) {
                    //           //     if (states.contains(MaterialState.pressed))
                    //           //       return Colors.red;
                    //           //
                    //           //     // Use the component's default.
                    //           //     return Colors.white.withOpacity(0.7);
                    //           //   },
                    //           // ),
                    //           ),
                    //       child: Text(
                    //         "Swimming",
                    //         style: TextStyle(color: AppColors.MainTextColor),
                    //       )),
                    //   ElevatedButton(
                    //       onPressed: () {},
                    //       style: ButtonStyle(
                    //           backgroundColor: MaterialStateProperty.all(
                    //               Colors.white.withOpacity(0.95))
                    //           // backgroundColor:
                    //           //     MaterialStateProperty.resolveWith<Color>(
                    //           //   (Set<MaterialState> states) {
                    //           //     if (states.contains(MaterialState.pressed))
                    //           //       return Colors.red;
                    //           //
                    //           //     // Use the component's default.
                    //           //     return Colors.white.withOpacity(0.7);
                    //           //   },
                    //           // ),
                    //           ),
                    //       child: Text(
                    //         "Hockey",
                    //         style: TextStyle(color: AppColors.MainTextColor),
                    //       )),
                    //   ElevatedButton(
                    //       onPressed: () {},
                    //       style: ButtonStyle(
                    //           backgroundColor: MaterialStateProperty.all(
                    //               Colors.white.withOpacity(0.95))
                    //           // backgroundColor:
                    //           //     MaterialStateProperty.resolveWith<Color>(
                    //           //   (Set<MaterialState> states) {
                    //           //     if (states.contains(MaterialState.pressed))
                    //           //       return Colors.red;
                    //           //
                    //           //     // Use the component's default.
                    //           //     return Colors.white.withOpacity(0.7);
                    //           //   },
                    //           // ),
                    //           ),
                    //       child: Text(
                    //         "Karate",
                    //         style: TextStyle(color: AppColors.MainTextColor),
                    //       )),
                    //   ElevatedButton(
                    //       onPressed: () {},
                    //       style: ButtonStyle(
                    //           backgroundColor: MaterialStateProperty.all(
                    //               Colors.white.withOpacity(0.95))
                    //           // backgroundColor:
                    //           //     MaterialStateProperty.resolveWith<Color>(
                    //           //   (Set<MaterialState> states) {
                    //           //     if (states.contains(MaterialState.pressed))
                    //           //       return Colors.red;
                    //           //
                    //           //     // Use the component's default.
                    //           //     return Colors.white.withOpacity(0.7);
                    //           //   },
                    //           // ),
                    //           ),
                    //       child: Text(
                    //         "Karate",
                    //         style: TextStyle(color: AppColors.MainTextColor),
                    //       )),
                    // ],
                  ),
                  isExpanded: kindActive.value,
                  canTapOnHeader: true,
                )
              ],
            ),
            // for (int i = 0; i < items.length; i++) items[i]
          ],
        ));
  }
}
