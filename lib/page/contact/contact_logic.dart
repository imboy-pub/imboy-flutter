import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/contact/contact_detail_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactLogic extends GetxController {
  RxList<ContactModel> contactList = RxList<ContactModel>();

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
      json["isfriend"] = 1;
      ContactModel model = ContactModel.fromJson(json);
      contact.insert(0, model);
      repo.save(json);
    }
    return contact;
  }

  Widget getChatListItem(
    BuildContext context,
    ContactModel model, {
    double susHeight = 40,
    Color? defHeaderBgColor,
  }) {
    return getChatItem(context, model, defHeaderBgColor: defHeaderBgColor);
  }

  Widget getChatItem(
    BuildContext context,
    ContactModel model, {
    Color? defHeaderBgColor,
  }) {
    DecorationImage? image;
    if (model.avatar.isNotEmpty) {
      image = dynamicAvatar(model.avatar);
    }

    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10),
      width: Get.width,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.LineColor, width: 0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 49,
          height: 49,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4.0),
            color: model.bgColor ?? defHeaderBgColor,
            image: image,
          ),
          child: model.iconData,
        ),
        contentPadding: const EdgeInsets.only(left: 0),
        title: Text(model.title),
        onTap: model.onPressed ??
            () {
              if (model.uid != null) {
                Get.to(() => ContactDetailPage(id: model.uid!));
              }
            },
        onLongPress: model.onLongPressed ??
            () {
              if (model.uid != null) {
                Get.to(
                  () => ChatPage(
                    toId: model.uid!,
                    title: model.title,
                    avatar: model.avatar,
                    type: 'C2C',
                  ),
                );
              }
            },
      ),
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
  void receivedConfirFriend(Map data) {
    var repo = ContactRepo();
    Map<String, dynamic> json = {
      // From 的个人信息
      'uid': data['id'],
      'account': data['account'],
      'nickname': data['nickname'],
      'avatar': data['avatar'],
      'gender': data['gender'],
      'status': data['status'],
      'remark': data['remark'] ?? '',
      'region': data['region'],
      'source': data['source'] ?? "",
      'isfrom': data['isfrom'] ?? 0,
      'sign': data['sign'],
      'isfriend': 1,
    };
    contactList.add(ContactModel.fromJson(json));
    repo.save(json);
  }
}
