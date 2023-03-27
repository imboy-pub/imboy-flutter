import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:niku/namespace.dart' as n;

import 'contact_detail_logic.dart';

// ignore: must_be_immutable
class ContactDetailMorePage extends StatelessWidget {
  final String id; // 用户ID

  ContactDetailMorePage({
    Key? key,
    required this.id,
  }) : super(key: key);

  RxString sign = "".obs;
  RxString sourcePrefix = "".obs;
  RxString source = "".obs;
  RxInt groupCount = 0.obs;
  final ContactDetailLogic logic = Get.find();

  Future<void> initData() async {
    ContactModel? model = await logic.findByID(id);
    if (model != null) {
      sign.value = model.sign;
      source.value = model.sourceTr;
      sourcePrefix.value = model.isFrom == 1 ? "" : "对方".tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    initData();
    // var currentUser = UserRepoLocal.to.current;
    // bool isSelf = currentUser.uid == id;
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '社交资料'.tr,
        // backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Obx(() => n.Column([
              LabelRow(
                label: '我和他的共同群聊'.tr,
                rValue: '$groupCount个'.tr,
                isLine: false,
                isRight: false,
                padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                margin: const EdgeInsets.only(bottom: 10.0),

                // onPressed: () => Get.to(() => const FriendCirclePage()),
              ),
              Visibility(
                visible: strNoEmpty(sign.value),
                child: LabelRow(
                  label: '个性签名'.tr,
                  // rValue: sign,
                  rightW: Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      sign.value,
                      style: TextStyle(
                          color: AppColors.MainTextColor.withOpacity(0.7),
                          fontWeight: FontWeight.w400),
                    ),
                  )),
                  isLine: true,
                  isRight: false,
                  isSpacer: false,
                  // onPressed: () => Get.to(() => const FriendCirclePage()),
                ),
              ),
              LabelRow(
                label: '来源'.tr,
                rValue: sourcePrefix.value + source.value,
                isLine: false,
                isRight: false,
                // onPressed: () => Get.to(() => const FriendCirclePage()),
              ),
            ])),
      ),
    );
  }
}
