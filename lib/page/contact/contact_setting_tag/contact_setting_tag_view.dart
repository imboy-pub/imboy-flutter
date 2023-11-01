import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
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
  final String peerRemark;
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
      appBar: PageAppBar(
        titleWidget: n.Row([
          Expanded(
            child: Text(
              '设置备注和标签'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
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
                    EasyLoading.showSuccess('操作成功'.tr);
                    Get.back(result: trimmedText);
                  }
                }
              },
              // ignore: sort_child_properties_last
              child: Text(
                'button_accomplish'.tr,
                textAlign: TextAlign.center,
              ),
              style: logic.valueChanged.isTrue
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        AppColors.primaryElement,
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
                        AppColors.AppBarColor,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        AppColors.LineColor,
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
            labelText: '备注'.tr,
            autofocus: true,
            showCursor: true,
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
          )..usePrefixStyle((v) => v..color = Colors.white),

          const SizedBox(height: 20),
          //
          Obx(() => n.TextFormField(
                labelText: '标签'.tr,
                controller: TextEditingController()
                  ..text = peerTag.isEmpty ? '添加标签'.tr : peerTag.value,
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
