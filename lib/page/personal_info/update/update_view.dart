import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/radio_list_title.dart';
import 'package:imboy/component/ui/select_region_view.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

import 'update_logic.dart';

// ignore: must_be_immutable
class UpdatePage extends StatelessWidget {
  final String title;
  final Future<bool> Function(String) callback;

  String value;
  final String field;
  final int maxLength;

  // final EdgeInsetsGeometry? padding;

  UpdatePage({
    super.key,
    this.title = "",
    required this.callback,
    this.value = "",
    this.field = "",
    this.maxLength = 56,
    // this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
  });

  final logic = Get.put(UpdatePageLogic());
  final regionLogic = Get.put(SelectRegionLogic(), tag: "UpdatePage");

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      // 设置提交按钮灰色
      logic.valueOnChange(false);
    });
    Widget body = const SizedBox.shrink();
    if (field == "input") {
      logic.textController.text = value;
      body = inputField();
    } else if (field == "text") {
      logic.textController.text = value;
      logic.valueOnChange(true);
      body = textField();
    } else if (field == "region") {
      logic.val.value = value;
      // 选择如果是顶级地区,选中之
      regionLogic.regionSelectedTitle(logic.val.value);
      // 加载地区数据
      logic.loadData();
      body = regionField();
    } else if (field == "gender") {
      logic.val.value = value;
      logic.valueOnChange(true);
      body = genderField();
    }
    double top = 0;
    if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
      top = 22;
    }
    return Container(
      padding: EdgeInsets.only(top: top),
      color: AppColors.AppBarColor,
      width: Get.width,
      height: Get.height,
      child: Wrap(
        children: <Widget>[
          PageAppBar(
            titleWidget: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
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
                      if (field == "input") {
                        String trimmedText = logic.textController.text.trim();
                        if (trimmedText == '') {
                          logic.valueOnChange(false);
                        } else {
                          bool res = await callback(trimmedText);
                          if (res) {
                            Get.back();
                          }
                        }
                      } else if (field == "text") {
                        String trimmedText = logic.textController.text.trim();
                        bool res = await callback(trimmedText);
                        if (res) {
                          Get.back();
                        }
                      } else if (field == "region" || field == "gender") {
                        bool res = await callback(logic.val.value);
                        if (res) {
                          Get.back();
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
              ],
            ),
          ),
          n.Row([
            Expanded(
              child: body,
            ),
          ]),
        ],
      ),
    );
  }

  Widget inputField() {
    return TextFormField(
      autofocus: true,
      focusNode: logic.inputFocusNode,
      controller: logic.textController,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(width: 1.0, color: Colors.red),
          ),
          errorStyle: const TextStyle(),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(width: 1.0, color: Colors.red),
          ),
          border: InputBorder.none),
      readOnly: false,
      onFieldSubmitted: (value) async {
        // FocusScope.of(Get.context!).requestFocus();
        if (value == '') {
          logic.valueOnChange(false);
        } else {
          bool res = await callback(value);
          if (res) {
            Get.back();
          }
        }
      },
      //style: ,
      onChanged: (value) {
        if (value == '' || value == logic.val.value) {
          logic.valueOnChange(false);
        } else {
          logic.valueOnChange(true);
        }
      },
      onSaved: (value) {},
      validator: (value) {
        return null;
      },
    );
  }

  Widget textField() {
    return TextFormField(
      autofocus: true,
      focusNode: logic.inputFocusNode,
      controller: logic.textController,
      keyboardType: TextInputType.multiline,
      maxLines: 5,
      minLines: 3,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(14, 16, 8, 0),
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(width: 1.0, color: Colors.red),
          ),
          errorStyle: const TextStyle(),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(width: 1.0, color: Colors.red),
          ),
          border: InputBorder.none),
      readOnly: false,
      onFieldSubmitted: (value) async {
        bool res = await callback(value);
        if (res) {
          Get.back();
        }
      },
      onChanged: (value) {
        if (value == '' || value == logic.val.value) {
          logic.valueOnChange(false);
        } else {
          logic.valueOnChange(true);
        }
      },
      onSaved: (value) {},
      validator: (value) {
        return null;
      },
    );
  }

  Widget genderField() {
    Widget secondary = const Text(
      "√",
      style: TextStyle(
        fontSize: 20,
        color: AppColors.primaryElement,
      ),
    );
    return Obx(
      () => n.Column(
        [
          IMBoyRadioListTile(
            value: "1",
            title: n.Text('male'.tr),
            selected: false,
            secondary: logic.val.value == "1" ? secondary : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryElement,
            groupValue: logic.val.value,
            onChanged: (val) {
              logic.valueOnChange(true);
              logic.setVal(val.toString());
            },
          ),
          Container(
            width: Get.width * 0.92,
            height: 1,
            color: AppColors.AppBarColor,
          ),
          IMBoyRadioListTile(
            value: "2",
            title: n.Text('female'.tr),
            selected: false,
            secondary: logic.val.value == "2" ? secondary : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryElement,
            groupValue: logic.val.value,
            onChanged: (val) {
              logic.valueOnChange(true);
              logic.setVal(val.toString());
            },
          ),
          Container(
            width: Get.width * 0.92,
            height: 1,
            color: AppColors.AppBarColor,
          ),
          IMBoyRadioListTile(
            value: '3',
            title: n.Text('keep_secret'.tr),
            selected: false,
            secondary: logic.val.value == '3' ? secondary : null,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0.0),
                topRight: Radius.circular(0.0),
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryElement,
            groupValue: logic.val.value,
            onChanged: (val) {
              logic.valueOnChange(true);
              logic.setVal(val.toString());
            },
          ),
        ],
        mainAxisSize: MainAxisSize.min,
      )..useParent((v) => v..bg = Colors.white),
    );
  }

  Widget regionField() {
    return Obx(
      () => n.Column(
        [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 15.0),
            width: Get.width,
            height: 40.0,
            child: Text("${'selected_region'.tr}： ${logic.val.value}"),
          ),
          n.Row([
            Expanded(
              child: SizedBox(
                height: Get.height - 40,
                child: ListView.builder(
                  itemBuilder: (BuildContext context, int index) {
                    return regionLogic
                        .getListItem(context, "", logic.regionList[index],
                            (String p, String t) async {
                      logic.val.value = strEmpty(p) ? t : "$p $t";
                      logic.valueOnChange(true);
                      return true;
                    }, callback);
                  },
                  itemCount: logic.regionList.length,
                ),
              ),
            ),
          ])
            ..mainAxisSize = MainAxisSize.max,
        ],
        mainAxisSize: MainAxisSize.min,
      )..useParent((v) => v..bg = Colors.white),
    );
  }
}
