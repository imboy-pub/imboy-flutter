import 'package:azlistview/azlistview.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/new_friend/new_friend_view.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_logic.dart';
import 'package:imboy/page/group/group_list/group_list_view.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_view.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactLogic extends GetxController {
  RxList<ContactModel> contactList = RxList<ContactModel>();

  // ignore: prefer_collection_literals
  RxSet currIndexBarData = Set().obs;

  void handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        currIndexBarData.add(tag);
      } else {
        list[i].nameIndex = '#';
      }
    }
    currIndexBarData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(list);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(list);

    final List<ContactModel> topList = [
      ContactModel(
        peerId: 'people_nearby',
        nickname: '找附近的人'.tr,
        nameIndex: '↑',
        bgColor: Colors.orange,
        iconData: const Center(
          child: Icon(
            Icons.person_pin_circle,
            size: 24,
            color: Colors.white,
          ),
        ),
        onPressed: () {
          Get.to(
            () => PeopleNearbyPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      ContactModel(
        peerId: 'new_friend',
        nickname: '新的朋友'.tr,
        nameIndex: '↑',
        bgColor: Colors.orange,
        iconData: Obx(() => badges.Badge(
              showBadge: Get.find<BottomNavigationLogic>()
                  .newFriendRemindCounter
                  .isNotEmpty,
              // shape: badges.BadgeShape.square,
              // borderRadius: BorderRadius.circular(10),
              position: badges.BadgePosition.topStart(top: 0, start: 128),
              // padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
              badgeContent: Container(
                color: Colors.red,
                alignment: Alignment.center,
                child: Text(
                  Get.find<BottomNavigationLogic>()
                      .newFriendRemindCounter
                      .length
                      .toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.person_add,
                  size: 24,
                ),
              ),
            )),
        onPressed: () {
          Get.to(
            () => NewFriendPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      ContactModel(
        peerId: 'group',
        nickname: '群聊'.tr,
        nameIndex: '↑',
        bgColor: Colors.green,
        iconData: const Icon(
          Icons.people,
          size: 24,
          color: Colors.white,
        ),
        onPressed: () {
          Get.to(
            () => const GroupListPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      ContactModel(
        peerId: 'tag',
        nickname: '标签'.tr,
        nameIndex: '↑',
        bgColor: Colors.blue,
        // icon 翻转
        iconData: Transform.scale(
          scaleX: -1,
          child: const Icon(
            Icons.local_offer,
            color: Colors.white,
            size: 24,
          ),
        ),
        onPressed: () {
          Get.to(
            () => ContactTagListPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
    ];
    // add topList.
    list.insertAll(0, topList);

    //
    contactList.value = list;
  }

  listFriend(bool onRefresh) async {
    List<ContactModel> contact = [];
    if (onRefresh == false) {
      contact = await (ContactRepo()).findFriend();
    }
    if (contact.isNotEmpty) {
      return contact;
    }
    var repo = ContactRepo();
    List<dynamic> dataMap = await (ContactProvider()).listFriend();
    for (var json in dataMap) {
      // debugPrint("> on findFriend2 item ${model.toJson().toString()} ");
      await repo.save(json);
    }
    contact = await (ContactRepo()).findFriend();
    return contact;
  }

  Widget getChatListItem(
    BuildContext context,
    ContactModel model, {
    double susHeight = 40,
    Color? defHeaderBgColor,
  }) {
    return InkWell(
      onTap: model.onPressed ??
          () {
            Get.to(
              () => PeopleInfoPage(
                id: model.peerId,
                scene: 'contact_page',
              ),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
      onLongPress: model.onLongPressed ??
          () {
            if (model.iconData == null) {
              Get.to(
                () => ChatPage(
                  peerId: model.peerId,
                  peerTitle: model.title,
                  peerAvatar: model.avatar,
                  peerSign: model.sign,
                  type: 'C2C',
                ),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
              );
            }
          },
      child: getChatItem(context, model, defHeaderBgColor: defHeaderBgColor),
    );
  }

  Widget getChatItem(
    BuildContext context,
    ContactModel model, {
    Color? defHeaderBgColor,
  }) {
    DecorationImage? avatar;
    if (model.avatar.isNotEmpty) {
      avatar = dynamicAvatar(model.avatar);
    }
    // debugPrint("getChatItem ${model.toJson().toString()}");
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 10.0, bottom: 6),
      color: Colors.white,
      child: n.Row([
        n.Padding(
          right: 2,
          child: model.iconData == null
              ? Avatar(
                  imgUri: model.avatar,
                  width: 49,
                  height: 49,
                )
              : Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(4.0),
                    color: model.bgColor ?? defHeaderBgColor,
                    image: avatar,
                  ),
                  child: model.iconData,
                ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.only(
            left: 0,
            right: 0,
            top: 10.0,
            bottom: 10.0,
          ),
          width: Get.width - 78,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.LineColor, width: 0.25),
            ),
          ),
          child: n.Row([
            Expanded(
              child: Text(
                model.title,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Space(width: mainSpace),
            // n.Column([
            //   // 最近会话时间
            //   Text(
            //     DateTimeHelper.lastTimeFmt(model.lastTime),
            //     maxLines: 1,
            //     overflow: TextOverflow.ellipsis,
            //     style: const TextStyle(
            //       color: AppColors.MainTextColor,
            //       fontSize: 14.0,
            //     ),
            //   ),
            //   const Icon(Icons.flag, color: Colors.transparent),
            // ])
          ]),
        )
      ])
        ..crossAxisAlignment = CrossAxisAlignment.center,
    );
  }

  Widget getSusItem(BuildContext context, String tag, {double susHeight = 24}) {
    return Container(
      height: susHeight,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 10.0),
      color: const Color(0xFFF3F4F5),
      alignment: Alignment.centerLeft,
      child: Text(
        tag,
        softWrap: false,
        style: const TextStyle(
          fontSize: 14.0,
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  /// 接受消息人（to）新增联系人
  void receivedConfirmFriend(Map data) {
    debugPrint("receivedConfirmFriend ${data.toString()}");
    var repo = ContactRepo();
    Map<String, dynamic> json = {
      ContactRepo.peerId: data['id'],
      'account': data['account'],
      'nickname': data['nickname'],
      'avatar': data['avatar'],
      'sign': data['sign'],
      'gender': data['gender'],
      'remark': data['remark'] ?? '',
      'region': data['region'],
      'source': data['source'],
      ContactRepo.tag: data[ContactRepo.tag] ?? '',
      ContactRepo.isFrom: 1,
      ContactRepo.isFriend: 1,
    };
    contactList.add(ContactModel.fromJson(json));
    repo.save(json);
  }
}
