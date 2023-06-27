
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactSettingTagPageLogic extends GetxController {
  // 用户名控制器

  FocusNode remarkFocusNode = FocusNode();
  TextEditingController remarkTextController = TextEditingController();

  RxBool valueChanged = false.obs;
  RxString val = "".obs;

  void valueOnChange(bool isChange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = isChange;
    update([valueChanged]);
  }

  void setVal(String value) {
    // 必须使用 .value 修饰具体的值
    val.value = value;
    update([val]);
  }

  Future<bool> changeRemark(String uid, String remark) async {
    debugPrint("contact_setting_changeRemark $remark");
    bool res = await ContactProvider().changeRemark(uid, remark);
    if (res) {
      await ContactRepo().update({
        ContactRepo.peerId: uid,
        ContactRepo.remark: remark,
      });
    }
    return res;
  }

}
