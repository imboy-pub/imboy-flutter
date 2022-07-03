import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/contact/contact_setting_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

import 'contact_detail_logic.dart';
import 'contact_detail_more_view.dart';

// ignore: must_be_immutable
class ContactDetailPage extends StatelessWidget {
  final String id; // 用户ID
  RxString nickname = "".obs;
  RxString avatar = "".obs;
  RxString account = "".obs;
  RxString region = "".obs;
  RxString sign = "".obs;
  RxString source = "".obs;
  RxInt gender = 0.obs;
  RxString remark = "".obs;

  ContactDetailPage({
    Key? key,
    required this.id,
  }) : super(key: key);

  final logic = Get.put(ContactDetailLogic());
  Future<void> initData() async {
    ContactModel? model = await logic.findByID(id);
    debugPrint(">>> on cdv initData $id");
    debugPrint(">>> on cdv initData ${model!.toJson().toString()}");
    nickname.value = model.nickname;
    avatar.value = model.avatar;
    account.value = model.account;
    region.value = model.region;
    sign.value = model.sign;
    source.value = model.sourceTr;
    gender.value = model.gender;
    remark.value = model.remark;
  }

  @override
  Widget build(BuildContext context) {
    initData();
    var currentUser = UserRepoLocal.to.currentUser;
    bool isSelf = currentUser.uid == id;
    var rWidget = [
      SizedBox(
        width: 60,
        child: TextButton(
          onPressed: () {
            Get.to(ContactSettingPage(
              id: id,
              remark: remark.value,
            ));
          },
          child: const Image(
            image: AssetImage(contactAssets + 'ic_contacts_details.png'),
          ),
        ),
      )
    ];

    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '',
        backgroundColor: Colors.white,
        rightDMActions: isSelf ? [] : rWidget,
      ),
      body: SingleChildScrollView(
        child: Obx(
          () => n.Column(
            [
              ContactCard(
                id: id,
                remark: remark.value,
                nickname: nickname.value,
                account: account.value,
                avatar: avatar.value,
                gender: gender.value,
                region: region.value,
                isBorder: true,
                padding: const EdgeInsets.only(
                  top: 8,
                  right: 15.0,
                  left: 15.0,
                  bottom: 16.0,
                ),
              ),
              Visibility(
                visible: !isSelf,
                child: LabelRow(
                  label: '设置备注和标签'.tr,
                  isLine: true,
                  onPressed: () => EasyLoading.showToast('敬请期待'),
                ),
              ),
              Visibility(
                visible: !isSelf,
                child: LabelRow(
                  label: '朋友权限'.tr,
                  onPressed: () => EasyLoading.showToast('敬请期待'),
                ),
              ),
              const Space(),
              LabelRow(
                label: '朋友圈'.tr,
                isLine: true,
                onPressed: () => EasyLoading.showToast('敬请期待'),
                // onPressed: () => Get.to(() => const FriendCirclePage()),
              ),
              LabelRow(
                label: '更多信息'.tr,
                isLine: false,
                onPressed: () => Get.to(
                  () => ContactDetailMorePage(
                    id: id,
                  ),
                ),
              ),
              ButtonRow(
                margin: const EdgeInsets.only(top: 10.0),
                text: '发消息'.tr,
                isBorder: true,
                onPressed: () => Get.to(
                  () => ChatPage(
                    toId: id,
                    title: nickname.value,
                    avatar: avatar.value,
                    type: 'C2C',
                  ),
                ),
              ),
              Visibility(
                visible: !isSelf,
                child: ButtonRow(
                  text: '音视频通话'.tr,
                  onPressed: () => EasyLoading.showToast('敬请期待'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
