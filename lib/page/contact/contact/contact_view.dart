import 'package:azlistview/azlistview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/service/assets.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/icon_image_provider.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/contact/new_friend/add_friend_view.dart';
import 'package:imboy/store/model/contact_model.dart';

import 'contact_logic.dart';

// ignore: must_be_immutable
class ContactPage extends StatelessWidget {
  RxBool contactIsEmpty = true.obs;

  final ContactLogic logic = Get.find();

  ContactPage({super.key});

  void loadData() async {
    // 加载联系人列表
    var list = await logic.listFriend(false);
    logic.handleList(list);
    contactIsEmpty.value = logic.contactList.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      appBar: NavAppBar(
        leading: const SizedBox.shrink(),
        title: 'title_contact'.tr,
        rightDMActions: <Widget>[
          InkWell(
            onTap: () {
              Get.to(
                () => AddFriendPage(),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
              );
            },
            child: n.Padding(
                top: 10,
                bottom: 10,
                child: const SizedBox(
                  width: 60.0,
                  child: Icon(Icons.person_add_alt_outlined),
                )),
          ),
        ],
      ),
      body: n.Stack([
        RefreshIndicator(
          onRefresh: () async {
            debugPrint(">>> contact onRefresh");
            // 检查网络状态
            var connectivityResult = await Connectivity().checkConnectivity();
            if (connectivityResult.contains(ConnectivityResult.none)) {
              String msg = 'tip_connect_desc'.tr;
              EasyLoading.showInfo(' $msg        ');
              return;
            }
            List<ContactModel> contactList = await logic.listFriend(true);
            if (contactList.isNotEmpty) {
              contactIsEmpty.value = contactList.isEmpty;
              logic.handleList(contactList);
            }
          },
          child: n.Column([
            Expanded(
              flex: 1,
              child: Obx(() => AzListView(
                    data: logic.contactList,
                    itemCount: logic.contactList.length,
                    itemBuilder: (BuildContext context, int index) {
                      ContactModel model = logic.contactList[index];
                      return logic.getChatListItem(
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
                      return logic.getSusItem(
                        context,
                        model.getSuspensionTag(),
                      );
                    },
                    // indexBarData: const ['↑', ...kIndexBarData],
                    indexBarData: logic.contactList.isNotEmpty
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
                            AssetsService.getImgPath('index_bar_bubble_gray'),
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                      indexHintAlignment: Alignment.centerRight,
                      indexHintChildAlignment: const Alignment(-0.15, 0.0),
                      indexHintOffset: const Offset(-20.0, 0),
                    ),
                  )),
            ),
          ]),
        ),
        Obx(() => Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: contactIsEmpty.isTrue
                  ? NoDataView(text: 'no_contacts'.tr)
                  : const SizedBox.shrink(),
            )),
      ]),
    );
  }
}
