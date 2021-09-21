import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/null_view.dart';
import 'package:imboy/helper/assets.dart';
import 'package:imboy/page/search/search_view.dart';
import 'package:lpinyin/lpinyin.dart';

import 'contacts_logic.dart';
import 'contacts_model.dart';
import 'contacts_state.dart';

class ContactsPage extends StatefulWidget {
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool contactIsEmpty = true;
  List<ContactModel> contactList = [];
  List<ContactModel> topList = [];

  final ContactsLogic logic = Get.put(ContactsLogic());
  final ContactsState state = Get.find<ContactsLogic>().state;

  @override
  void initState() {
    super.initState();
    topList.add(ContactModel(
        nickname: '新的朋友',
        nameIndex: '↑',
        bgColor: Colors.orange,
        iconData: Icons.person_add));
    topList.add(ContactModel(
        nickname: '群聊',
        nameIndex: '↑',
        bgColor: Colors.green,
        iconData: Icons.people));
    topList.add(ContactModel(
        nickname: '标签',
        nameIndex: '↑',
        bgColor: Colors.blue,
        iconData: Icons.local_offer));
    topList.add(ContactModel(
        nickname: '公众号',
        nameIndex: '↑',
        bgColor: Colors.blueAccent,
        iconData: Icons.person));
    loadData();
  }

  void loadData() async {
    //加载联系人列表
    contactList = await logic.listFriend();
    contactIsEmpty = contactList.isEmpty;
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

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
        children: [
          AzListView(
            data: contactList,
            itemCount: contactList.length,
            itemBuilder: (BuildContext context, int index) {
              ContactModel model = contactList[index];
              return logic.getWeChatListItem(
                context,
                model,
                defHeaderBgColor: Color(0xFFE5E5E5),
              );
            },
            physics: BouncingScrollPhysics(),
            susItemBuilder: (BuildContext context, int index) {
              ContactModel model = contactList[index];
              if ('↑' == model.getSuspensionTag()) {
                return Container();
              }
              return logic.getSusItem(context, model.getSuspensionTag());
            },
            indexBarData: ['↑', '☆', ...kIndexBarData],
            indexBarOptions: IndexBarOptions(
              needRebuild: true,
              ignoreDragCancel: true,
              downTextStyle: TextStyle(fontSize: 12, color: Colors.white),
              downItemDecoration:
                  BoxDecoration(shape: BoxShape.circle, color: Colors.green),
              indexHintWidth: 120 / 2,
              indexHintHeight: 100 / 2,
              indexHintDecoration: BoxDecoration(
                image: DecorationImage(
                  image:
                      AssetImage(Assets.getImgPath('ic_index_bar_bubble_gray')),
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
            child: contactIsEmpty ? HomeNullView(str: '无联系人') : Space(),
          ),
        ],
      ),
    );
  }
}
