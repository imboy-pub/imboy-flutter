import 'package:azlistview/azlistview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
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
    List<ContactModel> list = await logic.listFriend(false);
    logic.handleList(list);
    logic.update(logic.contactList);
    // iPrint("loadData ${logic.contactList.isEmpty}");
    contactIsEmpty.value = logic.contactList.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: Text('titleContact'.tr),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Get.to(
                () => AddFriendPage(),
                transition: Transition.rightToLeft,
                popGesture: true,
              );
            },
            icon: Icon(
              Icons.person_add_alt_outlined
            ),
            tooltip: '添加朋友',
            splashRadius: 24,
          ),
        ],
      ),
      // backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              debugPrint(">>> contact onRefresh");
              // 检查网络状态
              var connectivityResult = await Connectivity().checkConnectivity();
              if (connectivityResult.contains(ConnectivityResult.none)) {
                String msg = 'tipConnectDesc'.tr;
                EasyLoading.showInfo(' $msg        ');
                return;
              }
              List<ContactModel> contactList = await logic.listFriend(true);
              if (contactList.isNotEmpty) {
                contactIsEmpty.value = contactList.isEmpty;
                logic.handleList(contactList);
              }
            },
            // 使用优化后的主题色作为刷新指示器颜色
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            strokeWidth: 2.5, // 设置刷新指示器线条宽度
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Obx(
                    () => AzListView(
                      data: logic.contactList,
                      itemCount: logic.contactList.length,
                      itemBuilder: (BuildContext context, int index) {
                        ContactModel model = logic.contactList[index];
                        return logic.getChatListItem(
                          context,
                          model,
                          defHeaderBgColor: Theme.of(context).colorScheme.surfaceContainerHighest, // 使用主题变体色
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
                        // 使用优化后的主题色和字体
                        downTextStyle: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        downItemDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indexHintWidth: 64,
                        indexHintHeight: 64,
                        indexHintDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indexHintTextStyle: TextStyle(
                          fontSize: 24,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        indexHintAlignment: Alignment.centerRight,
                        indexHintChildAlignment: const Alignment(0, 0),
                        indexHintOffset: const Offset(-20.0, 0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 无数据提示 - 使用优化后的样式
          Obx(
            () => Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: contactIsEmpty.isTrue
                  ? NoDataView(text: 'noContacts'.tr)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
