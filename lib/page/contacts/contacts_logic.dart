import 'package:get/get.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/dio.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/store/model/contact_model.dart';

import 'contacts_state.dart';

class ContactsLogic extends GetxController {
  final state = ContactsState();

  listFriend() async {
    List<ContactModel> contacts = [];
    String identifier; // 用户ID
    String avatar; // 用户头像
    String account; // 账号
    String name; // 备注 or 昵称
    String nameIndex; // 备注 or 昵称 索引
    String sign;
    String status;

    // final contactsData = await SharedUtil.instance.getString(Keys.contacts);
    final contactsData = "[]";
    Map result = await DioUtil().get(API.friendList);

    getMethod(result) async {
      if (result['code'] != 0) {
        return contacts;
      }
      List<dynamic> dataMap = result['payload']['friend'];
      int dLength = dataMap.length;
      for (int i = 0; i < dLength; i++) {
        ContactModel model = ContactModel.fromJson(dataMap[i]);

        contacts.insert(0, model);
      }
      return contacts;
    }

    if (strNoEmpty(contactsData) || contactsData != '[]') {
      if (result != contactsData) {
        // await SharedUtil.instance.saveString(Keys.contacts, result.toString());
        return await getMethod(result);
      } else {
        return await getMethod(contactsData);
      }
    } else {
      // await SharedUtil.instance.saveString(Keys.contacts, result.toString());
      return await getMethod(result);
    }
  }
}
