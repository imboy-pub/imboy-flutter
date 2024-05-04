import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/theme.dart';

import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'package:niku/namespace.dart' as n;

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
        titleWidget: n.Row([
          Expanded(
            child: Text(
              'set_remarks_tags'.tr,
              textAlign: TextAlign.center,
              style: AppStyle.navAppBarTitleStyle,
            ),
            // 中间用Expanded控件
          ),
          Obx(
            () => ElevatedButton(
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
              // ignore: sort_child_properties_last
              child: n.Padding(
                  left: 10,
                  right: 10,
                  child: Text(
                    'button_accomplish'.tr,
                    textAlign: TextAlign.center,
                  )),
              style: logic.valueChanged.isTrue
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        // Theme.of(context).colorScheme.background,
                        Colors.green,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        Colors.white,
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    )
                  : ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        Colors.green.withOpacity(0.6),
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        Colors.white.withOpacity(0.6),
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
            ),
          ),
        ]),
      ),
      body: n.Padding(
        left: 12,
        top: 20,
        right: 12,
        child: n.Column([
          n.TextFormField(
            label: Text(
              'remark'.tr,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            autofocus: true,
            showCursor: true,
            // style: n.TextStyle(color: Colors.red),
            focusNode: logic.remarkFocusNode,
            controller: logic.remarkTextController,
            keyboardType: TextInputType.text,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            // textInputAction: TextInputAction.,
            readOnly: false,
            onFieldSubmitted: (value) async {
              FocusScope.of(Get.context!).requestFocus();
              if (value == '' || peerRemark == value) {
                logic.valueOnChange(false);
              } else {}
            },
            //style: ,
            onChanged: (value) {
              if (value == '' || peerRemark == value) {
                logic.valueOnChange(false);
              } else {
                logic.valueOnChange(true);
              }
            },
          )
          // ..usePrefixStyle(
          //   (v) => v..color = Theme.of(context).colorScheme.background,
          // )
          ,
          const SizedBox(height: 20),
          //
          Obx(() => n.TextFormField(
                // labelText: 'tags'.tr,
                label: Text(
                  'tags'.tr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                controller: TextEditingController()
                  ..text = peerTag.isEmpty ? 'add_tag'.tr : peerTag.value,
                // style: n.TextStyle(color: AppColors.ItemOnColor),
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
                    // () => TagAddPage(peerId:peerId, peerTag:'标签1, 标签1,标签1,标签1,标签1,标签1,标签1,标签1,标签1,标签1,ABCD'),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  )?.then((value) {
                    // iPrint(
                    //     "ContactSettingTagPage_TagAddPage_back then $value");
                    if (value != null && value is String) {
                      peerTag.value = value.toString();
                    }
                  });
                },
              )
                ..usePrefixStyle((v) => v..color = Colors.white)
                ..suffixIcon = const Icon(Icons.chevron_right)),
        ],
            // 内容文本左对齐
            crossAxisAlignment: CrossAxisAlignment.start),
      ),
    );
  }
}
