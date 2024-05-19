import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/theme.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:imboy/page/mine/user_device/user_device_logic.dart';

// ignore: must_be_immutable
class ChangeNamePage extends StatelessWidget {
  final String title;
  final Future<bool> Function(String) callback;

  String value;
  final String field;

  ChangeNamePage({
    super.key,
    this.title = "",
    required this.callback,
    this.value = "",
    this.field = "",
    // this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
  });

  final logic = Get.put(UserDeviceLogic());

  FocusNode inputFocusNode = FocusNode();
  TextEditingController textController = TextEditingController();
  RxBool valueChanged = false.obs;

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      // 设置提交按钮灰色
      // logic.valueOnChange(false);
    });
    textController.text = value;
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        titleWidget: n.Row([
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppStyle.navAppBarTitleStyle,
            ),
            // 中间用Expanded控件
          ),
          Obx(
            () => RoundedElevatedButton(
                text: 'button_accomplish'.tr,
                highlighted: valueChanged.isTrue,
                onPressed: () async {
                  if (field == "input") {
                    String trimmedText = textController.text.trim();
                    if (trimmedText == '') {
                      valueChanged.value = false;
                    } else {
                      bool res = await callback(trimmedText);
                      if (res) {
                        Get.back();
                      }
                    }
                  }
                }),
          ),
        ]),
      ),
      body: TextFormField(
        autofocus: true,
        focusNode: inputFocusNode,
        controller: textController,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
            filled: true,
            fillColor: Get.isDarkMode
                ? const Color.fromRGBO(70, 70, 70, 1.0)
                : Colors.white70,
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(
                  width: 0.2,
                  color: Theme.of(context).colorScheme.background,
                )),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(
                  width: 0.2,
                  color: Theme.of(context).colorScheme.background,
                )),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                  width: 1.0,
                  color: Theme.of(Get.context!).colorScheme.errorContainer),
            ),
            errorStyle: const TextStyle(),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                  width: 1.0,
                  color: Theme.of(Get.context!).colorScheme.errorContainer),
            ),
            border: InputBorder.none),
        readOnly: false,
        onFieldSubmitted: (val) async {
          // FocusScope.of(Get.context!).requestFocus();
          if (val == '') {
            valueChanged.value = false;
          } else {
            bool res = await callback(val);
            if (res) {
              Get.back();
            }
          }
        },
        //style: ,
        onChanged: (val) {
          iPrint("ChangeName_Page val $val, value $value;");
          if (value == val) {
            valueChanged.value = false;
          } else {
            valueChanged.value = true;
          }
        },
        onSaved: (value) {},
        validator: (value) {
          return null;
        },
      ),
    );
  }
}
