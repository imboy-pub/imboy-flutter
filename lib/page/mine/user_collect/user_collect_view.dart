import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:niku/namespace.dart' as n;

import 'user_collect_detail_view.dart';
import 'user_collect_logic.dart';

// ignore: must_be_immutable
class UserCollectPage extends StatelessWidget {
  final bool isSelect;
  final Map<String, String> peer;

  final logic = Get.put(UserCollectLogic());

  final state = Get.find<UserCollectLogic>().state;
  ScrollController controller = ScrollController();

  UserCollectPage({
    super.key,
    this.peer = const {},
    this.isSelect = false,
  });

  void initData() async {
    state.page = 1;
    String? kind = isSelect ? state.recentUse : state.kind;
    var list = await logic.page(
      page: state.page,
      size: state.size,
      kind: kind,
    );
    if (list.isNotEmpty) {
      state.items.value = list;
      state.page += 1;
    }

    state.tagItems.value = await logic.tagItems();

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

  Widget buildItemTag(String tagStr) {
    List<Widget> items = [];
    List<String> tagList =
        tagStr.split(',').where((o) => o.trim().isNotEmpty).toList();
    for (String tag in tagList) {
      items.add(// icon 翻转
          n.Padding(
        // left: 10,
        top: 2,
        right: 8,
        child: InkWell(
          onTap: () {
            // state.kindActive.value = !state.kindActive.value;
            logic.searchByTag(tag, tag, () {
              state.kindActive.value = !state.kindActive.value;
            });
          },
          child: n.Row(
            [
              Transform.scale(
                scaleX: -1,
                child: Icon(
                  Icons.local_offer,
                  size: 12,
                  color: AppColors.MainTextColor.withOpacity(0.8),
                ),
              ),
              Text(
                ' $tag',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
          ),
        ),
      ));
    }
    return n.Wrap(items);
  }

  Future<void> sendToDialog(BuildContext ctx, UserCollectModel model) async {
    types.Message msg = MessageModel.fromJson(model.info).toTypeMessage();
    Get.defaultDialog(
      title: '发送给'.tr,
      radius: 6,
      cancel: TextButton(
        onPressed: () {
          Get.back();
        },
        child: Text(
          '取消'.tr,
          textAlign: TextAlign.center,
        ),
      ),
      confirm: TextButton(
        onPressed: () async {
          // Navigator.pop(context, model); //这里的url在上一页调用的result可以拿到
          var nav = Navigator.of(ctx);
          nav.pop();
          nav.pop(model);
          // bool res = await sendToLogic.sendMsg(conversation!, msg);
          // if (res) {
          //   EasyLoading.showSuccess('发送成功'.tr);
          //   logic.change(kindId);
          //
          //
          //   // Future.delayed(const Duration(milliseconds: 1600), () {
          //   //   Get.close(2);
          //   // });
          // } else {
          //   EasyLoading.showError('发送失败'.tr);
          // }
        },
        child: Text(
          '发送'.tr,
          textAlign: TextAlign.center,
        ),
      ),
      content: SizedBox(
        height: 200,
        child: n.Column([
          n.Row([
            Avatar(
              imgUri: peer['avatar']!,
              onTap: () {},
            ),
            Expanded(
              child: n.Padding(
                left: 10,
                child: Text(
                  // 会话对象标题
                  peer['title']!,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ]),
          const Divider(),
          Expanded(
            child: Center(child: messageMsgWidget(msg)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        leading: isSelect
            ? InkWell(
                onTap: () {
                  Get.close(1);
                },
                child: const Icon(Icons.close),
              )
            : null,
        title: isSelect ? '收藏'.tr : '我的收藏'.tr,
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
          state.page = 1;
          var list = await logic.page(
            page: state.page,
            size: state.size * 200,
            kwd: state.kwd.value,
            onRefresh: true,
          );
          state.items.value = list;
          state.page += 1;
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
                        logic.doSearch(state.kwd);
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
                                          SlidableAction(
                                            key: ValueKey("tag_$index"),
                                            flex: 1,
                                            backgroundColor: AppColors.ChatBg,
                                            // foregroundColor: Colors.white,
                                            onPressed: (_) async {
                                              Get.to(
                                                () => UserTagRelationPage(
                                                  peerId: obj.kindId,
                                                  // peerTag: peerTag.value,
                                                  peerTag: obj.tag,
                                                  scene: 'collect',
                                                  title: '编辑标签'.tr,
                                                ),
                                                // () => TagAddPage(peerId:peerId, peerTag:'标签1, 标签1,标签1,标签1,标签1,标签1,标签1,标签1,标签1,标签1,ABCD'),
                                                transition:
                                                    Transition.rightToLeft,
                                                popGesture: true, // 右滑，返回上一页
                                              )?.then((value) {
                                                // iPrint(
                                                //     "UserCollectListPage_TagAddPage_back then $value");
                                                if (value != null &&
                                                    value is String) {
                                                  obj.tag = value.toString();
                                                  logic.updateItem(obj);
                                                }
                                              });
                                            },
                                            icon: Icons.local_offer,
                                            foregroundColor: Colors.green,
                                            label: "标签".tr,
                                            spacing: 1,
                                          ),
                                          SlidableAction(
                                            key: ValueKey("delete_$index"),
                                            flex: 1,
                                            backgroundColor: AppColors.ChatBg,
                                            // foregroundColor: Colors.white,
                                            onPressed: (_) async {
                                              Get.bottomSheet(
                                                SizedBox(
                                                  width: Get.width,
                                                  height: 106,
                                                  child: n.Wrap([
                                                    Center(
                                                      child: TextButton(
                                                        onPressed: () async {
                                                          bool res = await logic
                                                              .remove(obj);
                                                          debugPrint(
                                                              "user_collect_remove $res; i $index");
                                                          if (res) {
                                                            state.items
                                                                .removeAt(
                                                                    index);
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
                                                          '删除无法找回，确认删除？'.tr,
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
                                                  ]),
                                                ),
                                                backgroundColor: Colors.white,
                                                //改变shape这里即可
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(20.0),
                                                    topRight:
                                                        Radius.circular(20.0),
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: Icons.delete_forever_sharp,
                                            foregroundColor: Colors.red,
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
                                          onTap: () async {
                                            if (isSelect) {
                                              // 转发消息
                                              sendToDialog(context, obj);
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
                                            buildItemTag(obj.tag),
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
    //  Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
    Map<String, String> kindMap = {
      state.recentUse: '最近使用'.tr,
      '1': '文本'.tr,
      '2': '图片'.tr,
      '7': '个人名片'.tr,
      '4': '视频'.tr,
      '5': '文件'.tr,
      '6': '位置消息'.tr,
      '3': '语音'.tr,
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
          value,
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
                          state.kindActive.value = !state.kindActive.value;
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
              body: n.Column(
                [
                  n.Padding(
                    left: 8,
                    bottom: 10,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      children: items,
                    ),
                  ),
                  if (state.tagItems.value.isNotEmpty)
                    n.Padding(
                      top: 16,
                      child: n.Row([
                        const SizedBox(width: 8),
                        Icon(
                          Icons.sell_outlined,
                          size: 18,
                          color: AppColors.MainTextColor.withOpacity(0.8),
                        ),
                        const SizedBox(width: 10),
                        Text('标签'.tr),
                      ]),
                    ),
                  if (state.tagItems.value.isNotEmpty)
                    n.Padding(
                      left: 8,
                      bottom: 12,
                      child: Obx(() => Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            children: state.tagItems.value,
                          )),
                    )
                ],
                // 内容文本左对齐
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
              isExpanded: state.kindActive.value,
              canTapOnHeader: true,
            )
          ],
        ));
  }
}
