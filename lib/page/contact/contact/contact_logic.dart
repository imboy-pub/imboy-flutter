import 'package:azlistview/azlistview.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/widget/user_online_status_widget.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_logic.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/contact/new_friend/new_friend_view.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_view.dart';
import 'package:imboy/page/group/group_list/group_list_view.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:lpinyin/lpinyin.dart';

class ContactLogic extends GetxController {
  RxList<ContactModel> contactList = <ContactModel>[].obs;

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
        nickname: 'findNearbyPeople'.tr,
        nameIndex: '↑',
        bgColor: Colors.orange,
        iconData: const Center(
          child: Icon(Icons.person_pin_circle, size: 24, color: Colors.white),
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
        nickname: 'newFriend'.tr,
        nameIndex: '↑',
        bgColor: Colors.orange,
        iconData: Obx(
          () => badges.Badge(
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
                Get.find<BottomNavigationLogic>().newFriendRemindCounter.length
                    .toString(),
                style: const TextStyle(color: Colors.white, fontSize: 8),
              ),
            ),
            child: const Center(child: Icon(Icons.person_add, size: 24)),
          ),
        ),
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
        nickname: 'groupChat'.tr,
        nameIndex: '↑',
        bgColor: Colors.green,
        iconData: const Icon(Icons.people, size: 24, color: Colors.white),
        onPressed: () {
          Get.to(
            () => GroupListPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      ContactModel(
        peerId: 'tag',
        nickname: 'tags'.tr,
        nameIndex: '↑',
        bgColor: Colors.blue,
        iconData: const Icon(
          Icons.local_offer,
          size: 24,
          color: Colors.white,
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

  Future<List<ContactModel>> listFriend(bool onRefresh) async {
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
      // debugPrint("> on findFriend2 item ${json.toString()} ");
      await repo.save(json);
    }
    contact = await (ContactRepo()).findFriend();
    return contact;
  }

  Future<bool> isFriend(String peerId) async {
    for (var ct in contactList.value) {
      if (ct.peerId == peerId) {
        return ct.isFriend == 1 ? true : false;
      }
    }
    ContactModel? ct = await ContactRepo().findByUid(peerId);
    return ct?.isFriend == 1 ? true : false;
  }

  Widget getChatListItem(
    BuildContext context,
    ContactModel model, {
    double susHeight = 40,
    Color? defHeaderBgColor,
  }) {
    return InkWell(
      onTap:
          model.onPressed ??
          () {
            Get.to(
              () => PeopleInfoPage(id: model.peerId, scene: 'contact_page'),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
      onLongPress:
          model.onLongPressed ??
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

    // 判断是否为特殊联系人（功能入口）
    bool isSpecialContact = model.iconData != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ), // Card margins
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04), // Soft shadow
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          width: 0.5,
        ),
      ),
      child: Padding(
        // Internal padding
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 头像部分
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: model.iconData == null
                      ? Avatar(imgUri: model.avatar, width: 48, height: 48)
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(12.0),
                            color: model.bgColor ?? defHeaderBgColor,
                            image: avatar,
                          ),
                          child: model.iconData,
                        ),
                ),
                // 在线状态指示器（仅对真实联系人显示）
                if (!isSpecialContact)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _getOnlineStatusColor(model),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            // 信息部分
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 姓名
                    Text(
                      model.title,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 在线状态（仅对真实联系人显示）
                    if (!isSpecialContact && model.lastSeenAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: UserOnlineStatusWidget(
                          isOnline: model.status == 'online',
                          lastSeenTimestamp: model.lastSeenAt,
                          hideOnlineStatus: false,
                          textStyle: TextStyle(
                            fontSize: 12.0,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          indicatorSize: 0, // Indicated by avatar dot
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 获取在线状态颜色
  Color _getOnlineStatusColor(ContactModel model) {
    if (model.status == 'online') {
      return Colors.green;
    } else if (model.lastSeenAt != null) {
      // 如果有最后在线时间，根据时间长短返回不同颜色
      final nowMs = DateTimeHelper.millisecond();
      final lastSeenMs = model.lastSeenAt!;
      final diffMs = nowMs - lastSeenMs;

      if (diffMs <= 1 * 3600 * 1000) {
        return Colors.orange; // 1小时内
      } else if (diffMs <= 24 * 3600 * 1000) {
        return Colors.blue; // 1天内
      } else if (diffMs <= 7 * 24 * 3600 * 1000) {
        return Colors.purple; // 1周内
      } else {
        return Colors.grey; // 超过1周
      }
    } else {
      return Colors.grey.withValues(alpha: 0.5); // 无在线信息
    }
  }

  Widget getSusItem(BuildContext context, String tag, {double susHeight = 32}) {
    // 现代风格的索引头
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: susHeight,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 20.0),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Background blends
        // Optional: Add a subtle gradient or line
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          tag,
          softWrap: false,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
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
    contactList.value.add(ContactModel.fromMap(json));
    repo.save(json);
  }
}
