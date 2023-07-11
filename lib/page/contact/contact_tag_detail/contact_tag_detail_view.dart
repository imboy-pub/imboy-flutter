import 'package:azlistview/azlistview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/widget/select_friend.dart';
import 'package:imboy/page/contact/contact_tag/contact_tag_logic.dart';
import 'package:imboy/page/user_tag/user_tag_update/user_tag_update_view.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:niku/namespace.dart' as n;

import 'contact_tag_detail_logic.dart';

class ContactTagDetailPage extends StatelessWidget {
  UserTagModel tag;

  // ignore: prefer_const_constructors_in_immutables
  ContactTagDetailPage({super.key, required this.tag});

  RxBool contactIsEmpty = true.obs;

  final logic = Get.put(ContactTagDetailLogic());
  final state = Get.find<ContactTagDetailLogic>().state;

  void loadData() async {
    state.tagName.value = tag.name;
    // 加载联系人列表
    // var list = await logic.listFriend(false);
    // logic.handleList(list);
    // contactIsEmpty.value = logic.contactList.isEmpty;
    if (tag.refererTime > 0) {
      var list = await logic.pageRelation(false, 'friend');
      // logic.handleList(list);
      contactIsEmpty.value = logic.contactList.isEmpty;

    }
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      appBar: PageAppBar(
        titleWidget: Obx(() => Text('${state.tagName} (${tag.refererTime})')),
        rightDMActions: [
          InkWell(
            onTap: () {
              Get.bottomSheet(
                SizedBox(
                  width: Get.width,
                  height: 172,
                  child: n.Wrap(
                    [
                      Center(
                        child: TextButton(
                          child: Text(
                            '更改标签名称'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onPressed: () async {
                            Get.close(0);
                            Get.bottomSheet(
                              n.Padding(
                                // top: 80,
                                child: UserTagUpdatePage(
                                    tag: tag, scene: 'friend'),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            Get.close(0);
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
                                          '删除标签后，标签中的联系人不会被删除'.tr,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            // color: Colors.white,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    Center(
                                      child: TextButton(
                                        onPressed: () async {
                                          const String scene = 'friend';
                                          bool res = await Get.find<ContactTagLogic>().deleteTag(
                                            tagId: tag.tagId,
                                            tagName: tag.name,
                                            scene: scene,
                                          );
                                          if (res) {
                                            Get.find<ContactTagLogic>().replaceObjectTag(scene: scene, oldName:tag.name, newName: '');

                                            final index =
                                                Get.find<ContactTagLogic>()
                                                    .state
                                                    .items
                                                    .indexWhere((e) =>
                                                        e.tagId == tag.tagId);
                                            if (index > -1) {
                                              Get.find<ContactTagLogic>()
                                                  .state
                                                  .items
                                                  .removeAt(index);
                                            }
                                            Get.close(2);
                                            EasyLoading.showSuccess('操作成功'.tr);
                                          } else {
                                            EasyLoading.showError('操作失败'.tr);
                                          }
                                        },
                                        child: Text(
                                          '删除'.tr,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const HorizontalLine(height: 6),
                                    Center(
                                      child: TextButton(
                                        onPressed: () => Get.back(),
                                        child: Text(
                                          'button_cancel'.tr,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            // color: Colors.white,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              backgroundColor: Colors.white,
                              //改变shape这里即可
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20.0),
                                  topRight: Radius.circular(20.0),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            '删除'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const HorizontalLine(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          child: Text(
                            'button_cancel'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                backgroundColor: Colors.white,
                //改变shape这里即可
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
              );
            },
            // 三点更多 more icon
            child: n.Padding(
              left: 10,
              right: 10,
              child: const Icon(
                Icons.more_horiz,
                // size: 40,
              ),
            ),
          )
        ],
      ),
      body: n.Stack([
        RefreshIndicator(
          onRefresh: () async {
            debugPrint(">>> contact onRefresh");
            // 检查网络状态
            var res = await Connectivity().checkConnectivity();
            if (res == ConnectivityResult.none) {
              String msg = 'tip_connect_desc'.tr;
              EasyLoading.showInfo(' $msg        ');
              return;
            }
            // List<ContactModel> contactList = await logic.listFriend(true);
            // if (contactList.isNotEmpty) {
            //   contactIsEmpty.value = contactList.isEmpty;
            //   logic.handleList(contactList);
            // }
          },
          child: n.Column([
            Expanded(
              flex: 1,
              child: Obx(() => AzListView(
                    data: logic.contactList,
                    itemCount: logic.contactList.length,
                    itemBuilder: (BuildContext context, int index) {
                      ContactModel model = logic.contactList[index];
                      return Get.find().getChatListItem(
                        context,
                        model,
                        defHeaderBgColor: const Color(0xFFE5E5E5),
                      );
                    },
                    // 解决联系人数据量少的情况下无法刷新的问题
                    // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                    physics: const AlwaysScrollableScrollPhysics(),
                    susItemBuilder: (BuildContext context, int index) {
                      ContactModel model = logic.contactList[index];
                      if ('↑' == model.getSuspensionTag()) {
                        return Container();
                      }
                      return Get.find()
                          .getSusItem(context, model.getSuspensionTag());
                    },
                    indexBarData: const ['↑', ...kIndexBarData],
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
                      indexHintChildAlignment: const Alignment(-0.25, 0.0),
                      indexHintOffset: const Offset(-20, 0),
                    ),
                  )),
            ),
          ]),
        ),
        Obx(() => Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: contactIsEmpty.isTrue
                  ? n.Column([
                      n.Row([NoDataView(text: '当前标签无成员'.tr)])
                        // 内容居中
                        ..mainAxisAlignment = MainAxisAlignment.center,
                      n.Row([
                        ElevatedButton(
                          onPressed: () async {
                            ContactModel? c1 = await Navigator.push(
                              context,
                              CupertinoPageRoute(
                                // “右滑返回上一页”功能
                                builder: (_) => const SelectFriendPage(
                                  peer: {},
                                  peerIsReciver: true,
                                ),
                              ),
                            );
                          },
                          // ignore: sort_child_properties_last
                          child: n.Padding(
                            left: 40,
                            right: 40,
                            child: Text(
                              '添加'.tr,
                              style:
                                  const TextStyle(color: AppColors.ItemOnColor),
                            ),
                          ),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(
                              AppColors.AppBarColor,
                            ),
                            minimumSize:
                                MaterialStateProperty.all(const Size(60, 40)),
                            visualDensity: VisualDensity.compact,
                            padding: MaterialStateProperty.all(EdgeInsets.zero),
                          ),
                        )
                      ])
                        // 内容居中
                        ..mainAxisAlignment = MainAxisAlignment.center,
                    ],
                      // 垂直居中
                      mainAxisAlignment: MainAxisAlignment.center)
                  : const SizedBox.shrink(),
            )),
      ]),
    );
  }
}
