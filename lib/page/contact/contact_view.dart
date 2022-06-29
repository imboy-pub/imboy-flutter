import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/assets.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/nodata_view.dart';
import 'package:imboy/page/new_friend/new_friend_view.dart';
import 'package:imboy/page/search/search_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:lpinyin/lpinyin.dart';

import 'contact_logic.dart';

// ignore: must_be_immutable
class ContactPage extends StatelessWidget {
  RxBool contactIsEmpty = true.obs;
  RxList<ContactModel> contactList = RxList<ContactModel>();
  List<ContactModel> topList = [
    ContactModel(
      nickname: '新的朋友'.tr,
      nameIndex: '↑',
      bgColor: Colors.orange,
      iconData: Icons.person_add,
      onPressed: () {
        Get.to(NewFriendPage());
      },
    ),
    ContactModel(
      nickname: '群聊'.tr,
      nameIndex: '↑',
      bgColor: Colors.green,
      iconData: Icons.people,
    ),
    ContactModel(
      nickname: '标签'.tr,
      nameIndex: '↑',
      bgColor: Colors.blue,
      iconData: Icons.local_offer,
    ),
    // ContactModel(
    //     nickname: '公众号',
    //     nameIndex: '↑',
    //     bgColor: Colors.blueAccent,
    //     iconData: Icons.person,
    // ),
  ];

  final ContactLogic logic = Get.put(ContactLogic());

  ContactPage({Key? key}) : super(key: key);

  void loadData() async {
    // 加载联系人列表
    contactList.value = await logic.listFriend();
    contactIsEmpty.value = contactList.isEmpty;
    _handleList(contactList);
  }

  void _handleList(List<ContactModel> list) {
    // if (list.isEmpty) return;
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].nickname);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
      } else {
        list[i].nameIndex = "#";
      }
    }
    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(contactList);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(contactList);

    // add topList.
    contactList.insertAll(0, topList);
  }

  @override
  Widget build(BuildContext context) {
    loadData();

    return Scaffold(
      appBar: NavAppBar(
        title: "联系人".tr,
        rightDMActions: <Widget>[
          InkWell(
            child: const SizedBox(
              width: 60.0,
              child: Image(
                  image: AssetImage('assets/images/search_black.webp'),),
            ),
            onTap: () => Get.to(const SearchPage()),
          ),
        ],
      ),
      body: Obx(
        () => Stack(
          children: [
            AzListView(
              data: contactList,
              itemCount: contactList.length,
              itemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList[index];
                return logic.getChatListItem(
                  context,
                  model,
                  defHeaderBgColor: const Color(0xFFE5E5E5),
                );
              },
              physics: const BouncingScrollPhysics(),
              susItemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList[index];
                if ('↑' == model.getSuspensionTag()) {
                  return Container();
                }
                return logic.getSusItem(context, model.getSuspensionTag());
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
                      Assets.getImgPath('ic_index_bar_bubble_gray'),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                indexHintAlignment: Alignment.centerRight,
                indexHintChildAlignment: const Alignment(-0.25, 0.0),
                indexHintOffset: const Offset(-20, 0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child:
                  contactIsEmpty.isTrue ? NoDataView(text: '无联系人'.tr) : const Space(),
            ),
          ],
        ),
      ),
    );
  }
}
