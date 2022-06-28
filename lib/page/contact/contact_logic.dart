import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/contact_detail/contact_detail_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

import 'contact_state.dart';

class ContactLogic extends GetxController {
  final state = ContactState();

  listFriend() async {
    List<ContactModel> contact = [];
    contact = await (ContactRepo()).findFriend();
    if (contact.isNotEmpty) {
      return contact;
    }
    return await (ContactProvider()).listFriend();
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
    if (model.avatar != null && model.avatar!.isNotEmpty) {
      image = dynamicAvatar(model.avatar);
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4.0),
          color: model.bgColor ?? defHeaderBgColor,
          image: image,
        ),
        child: model.iconData == null
            ? null
            : Icon(
                model.iconData,
                color: Colors.white,
                size: 20,
              ),
      ),
      title: Text(model.nickname),
      onTap: model.onPressed ??
          () {
            if (model.uid != null) {
              Get.to(ContactDetailPage(
                id: model.uid!,
                nickname: model.nickname,
                avatar: model.avatar!,
                account: model.account!,
                region: model.region,
              ));
            }
          },
      onLongPress: model.onLongPressed ??
          () {
            if (model.uid != null) {
              Get.to(
                ChatPage(
                  id: 0,
                  toId: model.uid!,
                  title: model.nickname,
                  avatar: model.avatar,
                  type: 'C2C',
                ),
              );
            }
          },
    );
  }

  Widget getSusItem(BuildContext context, String tag, {double susHeight = 24}) {
    return Container(
      height: susHeight,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 16.0),
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
}
