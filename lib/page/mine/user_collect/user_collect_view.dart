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
import 'package:imboy/page/single/chat_video.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:niku/namespace.dart' as n;

import 'user_collect_detail_view.dart';
import 'user_collect_logic.dart';

// ignore: must_be_immutable
class UserCollectPage extends StatelessWidget {
  UserCollectPage({super.key});

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
                      leading: state.searchLeading?.value ??
                          InkWell(
                            onTap: () {
                              logic.doSearch(state.kwd);
                            },
                            child: const Icon(Icons.search),
                          ),
                      trailing: state.searchTrailing?.value,
                      controller: state.searchController,
                      searchLabel: '搜索'.tr,
                      hintText: '搜索'.tr,
                      queryTips: '收藏人名、群名、标签等'.tr,
                      onChanged: ((query) {
                        state.kwd = query.obs;
                        debugPrint(
                            "user_collect_s_onChanged ${query.toString()}");
                      }),
                      doSearch: logic.doSearch,
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
                                              bool res = await logic.remove(obj);
                                              debugPrint(
                                                  "user_collect_remove $res; i $index");
                                              if (res) {
                                                state.items.removeAt(index);
                                                // logic.update(state.items);
                                              }
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
                                            if (obj.kind == 4) {
                                              String uri = obj.info['payload']
                                                      ['thumb']['uri'] ??
                                                  '';
                                              Get.to(
                                                () => ChatVideoPage(url: uri),
                                                transition:
                                                    Transition.rightToLeft,
                                                popGesture: true, // 右滑，返回上一页
                                              );
                                            } else {
                                              // 收藏详情
                                              Get.to(
                                                () => UserCollectDetailPage(
                                                  obj: obj,
                                                  pageIndex: index,
                                                ),
                                                transition:
                                                    Transition.rightToLeft,
                                                popGesture: true, // 右滑，返回上一页
                                              );
                                            }
                                          },
                                          child: n.Column([
                                            logic.buildItemBody(obj, 'page'),
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
                                                state.kind == state.recentUse &&
                                                        obj.updatedAt > 0
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
      state.recentUse: '最近使用'.tr,
      '1': '文本'.tr,
      '2': '图片'.tr,
      '3': '语音'.tr,
      '4': '视频'.tr,
      '5': '文件'.tr,
      '6': '位置消息'.tr,
      'all': '所有'.tr,
    };

    List<Widget> items = [];
    kindMap.forEach((key, value) {
      items.add(ElevatedButton(
        onPressed: () {
          debugPrint("searchLeading ${state.searchLeading.toString()}");
          state.kindActive.value = !state.kindActive.value;
          logic.searchByKind(key, value, () {
            state.kindActive.value = !state.kindActive.value;
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
        padding: const EdgeInsets.only(left: 8, right: 16.0),
        color: AppColors.ChatBg,
        child: ExpansionPanelList(
          expandIconColor: AppColors.ChatBg,
          expansionCallback: (panelIndex, isExpanded) {
            state.kindActive.value = !state.kindActive.value;
            debugPrint("state.kindActive $state.kindActive");
          },
          children: <ExpansionPanel>[
            ExpansionPanel(
              backgroundColor: AppColors.ChatBg,
              headerBuilder: (context, isExpanded) {
                if (isExpanded) {
                  return n.Row([
                    const SizedBox(width: 8),
                    Icon(
                      Icons.grid_view,
                      size: 18,
                      color: AppColors.MainTextColor.withOpacity(0.8),
                    ),
                    const SizedBox(width: 10),
                    Text('类型'.tr),
                  ]);
                } else {
                  return n.Wrap([
                    InkWell(
                      onTap: () {
                        state.kindActive.value = !state.kindActive.value;
                        state.kindActive.value = !state.kindActive.value;
                        logic.searchByKind(state.recentUse, '最近使用'.tr, () {
                          // state.kindActive.value = !state.kindActive.value;
                        });
                      },
                      child: n.Padding(
                        top: 16,
                        bottom: 16,
                        left: 8,
                        right: 8,
                        child: Text('最近使用'.tr),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        state.kindActive.value = !state.kindActive.value;
                        state.kindActive.value = !state.kindActive.value;
                        logic.searchByKind('1', '文本'.tr, () {
                          // state.kindActive.value = !state.kindActive.value;
                        });
                      },
                      child: n.Padding(
                        top: 16,
                        bottom: 16,
                        left: 8,
                        right: 8,
                        child: Text(" ${'文本'.tr} "),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        state.kindActive.value = !state.kindActive.value;
                        state.kindActive.value = !state.kindActive.value;
                        logic.searchByKind('2', '图片'.tr, () {
                          // state.kindActive.value = !state.kindActive.value;
                        });
                      },
                      child: n.Padding(
                        top: 16,
                        bottom: 16,
                        left: 8,
                        right: 8,
                        child: Text(" ${'图片'.tr} "),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        state.kindActive.value = !state.kindActive.value;
                        state.kindActive.value = !state.kindActive.value;
                        logic.searchByKind('4', '视频'.tr, () {
                          //
                        });
                      },
                      child: n.Padding(
                        top: 16,
                        bottom: 16,
                        left: 8,
                        right: 8,
                        child: Text(" ${'视频'.tr} "),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        state.kindActive.value = !state.kindActive.value;
                        state.kindActive.value = !state.kindActive.value;
                        logic.searchByKind('5', '文件'.tr, () {
                          // state.kindActive.value = !state.kindActive.value;
                        });
                      },
                      child: n.Padding(
                        top: 16,
                        bottom: 16,
                        left: 8,
                        right: 8,
                        child: Text(" ${'文件'.tr} "),
                      ),
                    ),
                  ]);
                }
              },
              body: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                children: items,
              ),
              isExpanded: state.kindActive.value,
              canTapOnHeader: true,
            )
          ],
        ));
  }
}
