import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/null_view.dart';
import 'package:imboy/helper/assets.dart';
import 'package:imboy/page/search/search_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:lpinyin/lpinyin.dart';

import 'contact_logic.dart';
import 'contact_state.dart';

class ContactPage extends StatelessWidget {
  RxBool contactIsEmpty = true.obs;
  RxList<ContactModel> contactList = RxList<ContactModel>();
  List<ContactModel> topList = [
    ContactModel(
      nickname: '新的朋友',
      nameIndex: '↑',
      bgColor: Colors.orange,
      iconData: Icons.person_add,
    ),
    ContactModel(
      nickname: '群聊',
      nameIndex: '↑',
      bgColor: Colors.green,
      iconData: Icons.people,
    ),
    ContactModel(
      nickname: '标签',
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
  final ContactState state = Get.find<ContactLogic>().state;

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
    contactList.value.insertAll(0, topList);
  }

  @override
  Widget build(BuildContext context) {
    loadData();

    var appBar = new NavAppBar(
      title: "联系人",
      rightDMActions: <Widget>[
        new InkWell(
          child: new Container(
            width: 60.0,
            child:
                new Image(image: AssetImage('assets/images/search_black.webp')),
          ),
          onTap: () => Get.to(() => SearchPage()),
        ),
      ],
    );
    return Scaffold(
      appBar: appBar,
      body: Obx(
        () => Stack(
          children: [
            AzListView(
              data: contactList.value,
              itemCount: contactList.value.length,
              itemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList.value[index];
                return logic.getChatListItem(
                  context,
                  model,
                  defHeaderBgColor: Color(0xFFE5E5E5),
                );
              },
              physics: BouncingScrollPhysics(),
              susItemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList.value[index];
                if ('↑' == model.getSuspensionTag()) {
                  return Container();
                }
                return logic.getSusItem(context, model.getSuspensionTag());
              },
              indexBarData: ['↑', ...kIndexBarData],
              indexBarOptions: IndexBarOptions(
                needRebuild: true,
                ignoreDragCancel: true,
                downTextStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
                downItemDecoration: BoxDecoration(
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
                indexHintChildAlignment: Alignment(-0.25, 0.0),
                indexHintOffset: Offset(-20, 0),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: contactIsEmpty.isTrue
                  ? ConversationNullView(str: '无联系人')
                  : Space(),
            ),
          ],
        ),
      ),
    );
  }
}
