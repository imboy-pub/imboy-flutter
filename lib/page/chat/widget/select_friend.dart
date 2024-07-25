import 'package:azlistview/azlistview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';

// ignore: must_be_immutable
class SelectFriendPage extends StatefulWidget {
  final Map<String, String> peer;

  final bool peerIsReceiver;

  const SelectFriendPage({
    super.key,
    required this.peer,
    this.peerIsReceiver = false,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SelectFriendPageState createState() => _SelectFriendPageState();
}

class _SelectFriendPageState extends State<SelectFriendPage> {
  // final int _suspensionHeight = 30;
  final int _itemHeight = 60;

  RxList<ContactModel> contactList = RxList<ContactModel>();

  // ignore: prefer_collection_literals
  RxSet currIndexBarData = Set().obs;

  @override
  void initState() {
    super.initState();
    debugPrint("SelectFriendPage init ${widget.peer.toString()}");
    loadData();
  }

  List selects = [];

  void loadData() async {
    // 加载联系人列表
    contactList.value = await Get.find<ContactLogic>().listFriend(false);
    // debugPrint(
    //     "_handleVisitCardSelection contactList ${contactList.toString()}");
    _handleList(contactList);
  }

  void _handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        currIndexBarData.add(tag);
      } else {
        list[i].nameIndex = "#";
      }
    }
    currIndexBarData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(contactList);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(contactList);
  }

  /*
  Widget _buildSusWidget(String susTag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      height: _suspensionHeight.toDouble(),
      width: double.infinity,
      alignment: Alignment.centerLeft,
      color: AppColors.AppBarColor,
      child: Text(
        susTag,
        textScaleFactor: 1.2,
        style: const TextStyle(
          color: Color(0xff333333),
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  */

  void sendToDialog(ContactModel model) {
    Get.defaultDialog(
      title: 'send_to'.tr,
      backgroundColor: Get.isDarkMode
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      radius: 6,
      cancel: TextButton(
        onPressed: () {
          Get.close();
        },
        child: Text(
          'button_cancel'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
      confirm: TextButton(
        onPressed: () async {
          var nav = Navigator.of(context);
          nav.pop();
          nav.pop(model);
        },
        child: Text(
          'button_send'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
      ),
      content: SizedBox(
        height: 164,
        child: n.Column([
          widget.peerIsReceiver
              ? n.Row([
                  Avatar(
                    imgUri: model.avatar,
                    onTap: () {},
                  ),
                  Expanded(
                    child: n.Padding(
                      left: 10,
                      child: Text(
                        model.title,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ])
              : n.Row([
                  Avatar(
                    imgUri: widget.peer['avatar']!,
                    onTap: () {},
                  ),
                  Expanded(
                    child: n.Padding(
                      left: 10,
                      child: Text(
                        widget.peer['title']!,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ]),
          const Divider(),
          Expanded(
            child: Text(
              // visit_card
              widget.peerIsReceiver
                  ? "[${'personal_card'.tr}]${widget.peer['nickname']}"
                  : "[${'personal_card'.tr}]${model.nickname}",
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
        ])
          ..crossAxisAlignment = CrossAxisAlignment.start,
      ),
    );
  }

  Widget _buildListItem(ContactModel model) {
    // String susTag = model.getSuspensionTag();
    return n.Column([
      SizedBox(
        height: _itemHeight.toDouble(),
        child: InkWell(
          onTap: () {
            sendToDialog(model);
            // model.selected = !model.selected;
            // if (model.selected) {
            //   selects.insert(0, model);
            // } else {
            //   selects.remove(model);
            // }
            // setState(() {});
          },
          child: n.Row([
            n.Padding(
              left: 16,
              child: Avatar(
                imgUri: model.avatar,
                width: 49,
                height: 49,
              ),
            ),
            const Space(),
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(right: 30),
                height: _itemHeight.toDouble(),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      width: 0.5,
                    ),
                  ),
                ),
                child: Text(
                  model.title,
                  style: const TextStyle(fontSize: 14.0),
                ),
              ),
            ),
          ]),
        ),
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
        title: 'select_friends'.tr,
        leading: n.Padding(
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const Icon(Icons.close),
          ),
        ),
        // rightDMActions: <Widget>[
        //   ComMomButton(
        //     margin: const EdgeInsets.symmetric(
        //       vertical: 7,
        //       horizontal: 5,
        //     ),
        //     onTap: () {
        //       if (!listNoEmpty(selects)) {
        //         Get.snackbar('', 'please_select_members_for_add'.tr);
        //       }
        //     },
        //     text: 'button_confirm'.tr,
        //   ),
        // ],
      ),
      body: Obx(
        () => n.Stack([
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
              List<ContactModel> contact =
                  await Get.find<ContactLogic>().listFriend(true);
              if (contact.isNotEmpty) {
                contactList.value = contact;
                // contactIsEmpty.value = contactList.isEmpty;
                _handleList(contactList);
              }
            },
            child: AzListView(
              data: contactList,
              itemCount: contactList.length,
              itemBuilder: (context, i) => _buildListItem(contactList[i]),
              // 解决联系人数据量少的情况下无法刷新的问题
              // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
              physics: const AlwaysScrollableScrollPhysics(),
              susItemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList[index];
                if ('↑' == model.getSuspensionTag()) {
                  return Container();
                }

                return Get.find<ContactLogic>()
                    .getSusItem(context, model.getSuspensionTag());
              },
              // indexBarData: const ['↑', ...kIndexBarData],
              indexBarData:
                  contactList.isNotEmpty ? ['↑', ...currIndexBarData] : [],
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
                      AssetsService.getImgPath('ic_index_bar_bubble_gray'),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                indexHintAlignment: Alignment.centerRight,
                indexHintChildAlignment: const Alignment(-0.25, 0.0),
                indexHintOffset: const Offset(-20, 0),
              ),
            ),
          )
        ]),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
