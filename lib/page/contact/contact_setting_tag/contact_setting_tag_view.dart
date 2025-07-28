import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';

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
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      // 设置提交按钮灰色
      logic.valueOnChange(false);
    });
    logic.remarkTextController.text = peerRemark;
    if (peerRemark == 'null') {
      logic.remarkTextController.text = '';
    }

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Row(
          children: [
            Expanded(
              child: Text(
                'set_param'.trArgs(['remarks_tags'.tr]),
                textAlign: TextAlign.center,
              ),
            ),
            Obx(
              () => RoundedElevatedButton(
                text: 'button_accomplish'.tr,
                highlighted: logic.valueChanged.isTrue,
                onPressed: () async {
                  String trimmedText = logic.remarkTextController.text.trim();
                  if (trimmedText == '') {
                    logic.valueOnChange(false);
                  } else if (logic.valueChanged.isTrue) {
                    bool res = await logic.changeRemark(peerId, trimmedText);
                    if (res) {
                      EasyLoading.showSuccess('tip_success'.tr);
                      peerRemark = trimmedText;
                      Get.back(result: trimmedText);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 12, top: 20, right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'remark'.tr,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              autofocus: true,
              showCursor: true,
              focusNode: logic.remarkFocusNode,
              controller: logic.remarkTextController,
              keyboardType: TextInputType.text,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              readOnly: false,
              onFieldSubmitted: (value) async {
                FocusScope.of(Get.context!).requestFocus();
                if (value == '' || peerRemark == value) {
                  logic.valueOnChange(false);
                }
              },
              onChanged: (value) {
                if (value == '' || peerRemark == value) {
                  logic.valueOnChange(false);
                } else {
                  logic.valueOnChange(true);
                }
              },
            ),
            const SizedBox(height: 20),
            Obx(
              () => TextFormField(
                decoration: InputDecoration(
                  labelText: 'tags'.tr,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Icon(Icons.chevron_right),
                  ),
                ),
                controller: TextEditingController()
                  ..text = peerTag.isEmpty ? 'add_tag'.tr : peerTag.value,
                readOnly: true,
                minLines: 1,
                maxLines: 8,
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
                      peerTag.value = value.toString();
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
