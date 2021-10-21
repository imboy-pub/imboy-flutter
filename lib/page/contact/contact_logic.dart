import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/http/http_client.dart';
import 'package:imboy/helper/http/http_response.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/contact_detail/contact_detail_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';

import 'contact_state.dart';

class ContactLogic extends GetxController {
  final state = ContactState();

  final UserRepoSP current = Get.put(UserRepoSP.user);
  final HttpClient _dio = Get.put(HttpClient.client);

  listFriend() async {
    List<ContactModel> contact =
        await (ContactRepo()).findByCuid(current.currentUid);

    // Stream<ConversationEntity?> contact = db.conversationDao.findByCuid(cuid);

    if (contact.isNotEmpty) {
      return contact;
    }

    HttpResponse resp = await _dio.get(API.friendList,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
        ));

    if (!resp.ok) {
      return [];
    }
    List<dynamic> dataMap = resp.payload['friend'];
    int dLength = dataMap.length;
    var repo = ContactRepo();
    for (int i = 0; i < dLength; i++) {
      ContactModel model = ContactModel.fromMap(dataMap[i]);
      contact.insert(0, model);
      repo.insert(model);
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
    if (model.avatar != null && model.avatar!.isNotEmpty) {
      image = DecorationImage(
        image: model.avatar == 'assets/images/def_avatar.png'
            ? AssetImage(model.avatar!) as ImageProvider
            : CachedNetworkImageProvider(model.avatar!),
        fit: BoxFit.cover,
      );
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
      onTap: () {
        Get.to(ContactDetailPage(
          id: model.uid!,
          nickname: model.nickname,
          avatar: model.avatar!,
          account: model.account!,
        ));
        // Get.snackbar(
        //   "onItemClick : ${model.nickname}",
        //   'onItemClick : ${model}',
        // );
      },
      onLongPress: () {
        Get.to(
          ChatPage(
            id: model.uid!,
            title: model.nickname,
            avatar: model.avatar,
            type: 'C2C',
          ),
        );
      },
    );
  }

  Widget getSusItem(BuildContext context, String tag, {double susHeight = 40}) {
    if (tag == '★') {
      tag = '★ 热门城市';
    }
    return Container(
      height: susHeight,
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.only(left: 16.0),
      color: Color(0xFFF3F4F5),
      alignment: Alignment.centerLeft,
      child: Text(
        '$tag',
        softWrap: false,
        style: TextStyle(
          fontSize: 14.0,
          color: Color(0xFF666666),
        ),
      ),
    );
  }
}
