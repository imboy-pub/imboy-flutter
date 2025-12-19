import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'contact_setting_tag_logic.dart';

// ignore: must_be_immutable
class ContactSettingTagPage extends StatelessWidget {
  final String peerId; // 用户ID
  final String peerAccount;
  final String peerAvatar;
  final String peerTitle;
  final String peerNickname;
  final int peerGender;
  final String peerSign;
  final String peerRegion;
  final String peerSource;
  String peerRemark;
  Rx<String> peerTag;

  ContactSettingTagPage({
    super.key,
    required this.peerId,
    required this.peerAccount,
    required this.peerAvatar,
    required this.peerNickname,
    required this.peerGender,
    required this.peerTitle,
    required this.peerSign,
    required this.peerRegion,
    required this.peerSource,
    required this.peerRemark,
    required this.peerTag,
  });

  final logic = Get.put(ContactSettingTagPageLogic());

  @override
  Widget build(BuildContext context) {
    // 初始化时设置按钮状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logic.valueOnChange(false);
    });

    logic.remarkTextController.text = (peerRemark == 'null') ? '' : peerRemark;

    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: Text('setParam'.trArgs(['remarksTags'.tr])),
          actions: [
            TextButton(
              onPressed: logic.valueChanged.isTrue
                  ? () async {
                      String trimmedText = logic.remarkTextController.text.trim();
                      if (trimmedText.isNotEmpty) {
                        bool res = await logic.changeRemark(peerId, trimmedText);
                        if (res) {
                          EasyLoading.showSuccess('tipSuccess'.tr);
                          peerRemark = trimmedText;
                          Get.back(result: trimmedText);
                        }
                      }
                    }
                  : null, // 如果 valueChanged 为 false，则禁用按钮
              child: Text('buttonAccomplish'.tr),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'remark'.tr,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              focusNode: logic.remarkFocusNode,
              controller: logic.remarkTextController,
              keyboardType: TextInputType.text,
              maxLength: 40,
              onChanged: (value) {
                logic.valueOnChange(value.trim().isNotEmpty && peerRemark != value);
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2.0, // 添加阴影效果
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0), // 增加圆角
              ),
              child: ListTile(
                title: Text('tags'.tr),
                subtitle: Text(peerTag.isEmpty ? 'addTag'.tr : peerTag.value),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Get.to(
                    () => UserTagRelationPage(
                      peerId: peerId,
                      peerTag: peerTag.value,
                      scene: 'friend',
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  )?.then((value) {
                    if (value != null && value is String) {
                      peerTag.value = value;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
