import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/mine/select_region/select_region_logic.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/radio_list_title.dart';

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
    logic.val.value = value;
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      // 设置提交按钮灰色
      logic.valueOnChange(false);
    });
    Widget body = const SizedBox.shrink();
    if (field == "input") {
      logic.textController.text = value;
      body = inputField(context);
    } else if (field == "text") {
      logic.textController.text = value;
      logic.valueOnChange(true);
      body = textField(context);
    } else if (field == "region") {
      // 选择如果是顶级地区,选中之
      regionLogic.regionSelectedTitle(value);
      // 加载地区数据
      logic.loadData();
      body = regionField(context);
    } else if (field == "gender") {
      logic.valueOnChange(true);
      body = genderField(context);
    }
    // double top = 0;
    // if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
    //   top = 22;
    // }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
              highlighted: logic.valueChanged.isTrue,
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
            ),
          ),
        ]),
      ),
      body: SingleChildScrollView(child: body),
    );
  }

  Widget inputField(BuildContext context) {
    return TextFormField(
      autofocus: true,
      focusNode: logic.inputFocusNode,
      controller: logic.textController,
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
                width: 1.0,
                color: Theme.of(context).colorScheme.background,
              )),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                width: 1.0,
                color: Theme.of(context).colorScheme.background,
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
        onChanged(value);
      },
      onSaved: (value) {},
      validator: (value) {
        return null;
      },
    );
  }

  onChanged(val) {
    iPrint("onChanged ${logic.val.value} = $val");
    if (val == '' || val == value) {
      logic.valueOnChange(false);
    } else {
      logic.valueOnChange(true);
    }
    logic.setVal(val);
  }

  Widget textField(BuildContext context) {
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
          fillColor: Get.isDarkMode
              ? const Color.fromRGBO(70, 70, 70, 1.0)
              : Colors.white70,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                width: 0.2,
                color: Theme.of(context).colorScheme.background,
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
        onChanged(value);
      },
      onSaved: (value) {},
      validator: (value) {
        return null;
      },
    );
  }

  Widget genderField(BuildContext context) {
    Widget secondary = const Text(
      '√',
      style: TextStyle(
        fontSize: 20,
        color: Colors.green,
      ),
    );
    return Obx(
      () => n.Column([
        IMBoyRadioListTile(
          value: '1',
          title: n.Text(
            'male'.tr,
            style: n.TextStyle(
              fontSize: logic.val.value == '1' ? 20 : 16,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          selected: false,
          secondary: logic.val.value == '1' ? secondary : null,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).colorScheme.primary,
          groupValue: logic.val.value,
          onChanged: (val) {
            onChanged(val);
          },
        ),
        n.Padding(
          left: 16,
          right: 16,
          child: HorizontalLine(
            height: Get.isDarkMode ? 0.5 : 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        IMBoyRadioListTile(
          value: '2',
          title: n.Text(
            'female'.tr,
            style: n.TextStyle(
              fontSize: logic.val.value == '2' ? 20 : 16,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          selected: false,
          secondary: logic.val.value == '2' ? secondary : null,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).colorScheme.primary,
          groupValue: logic.val.value,
          onChanged: (val) {
            onChanged(val);
          },
        ),
        n.Padding(
          left: 16,
          right: 16,
          child: HorizontalLine(
            height: Get.isDarkMode ? 0.5 : 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        IMBoyRadioListTile(
          value: '3',
          title: n.Text(
            'keep_secret'.tr,
            style: n.TextStyle(
              fontSize: logic.val.value == '3' ? 20 : 16,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          selected: false,
          secondary: logic.val.value == '3' ? secondary : null,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(0.0),
              topRight: Radius.circular(0.0),
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(Get.context!).colorScheme.primary,
          groupValue: logic.val.value,
          onChanged: (val) {
            onChanged(val);
          },
        ),
        n.Padding(
          left: 16,
          right: 16,
          child: HorizontalLine(
            height: Get.isDarkMode ? 0.5 : 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ])
        ..mainAxisSize = MainAxisSize.min
        ..useParent((v) => v
            // ..bg = Get.isDarkMode
            //     ? const Color.fromRGBO(70, 70, 70, 1.0)
            //     : Colors.white70
            ),
    );
  }

  Widget regionField(BuildContext context) {
    return Obx(() => n.Column([
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 16.0),
                width: Get.width,
                height: 40.0,
                child: Text("${'selected_region'.tr}： ${logic.val.value}"),
              ),
              n.Row([
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16, right: 16),
                    width: Get.width,
                    height: Get.height - 40,
                    // color: Theme.of(context).colorScheme.background,
                    child: ListView.builder(
                      itemBuilder: (BuildContext context, int index) {
                        return regionLogic.getListItem(
                            context: context,
                            parent: '',
                            model: logic.regionList[index],
                            callback: (String p, String t) async {
                              // logic.val.value = strEmpty(p) ? t : "$p $t";
                              // logic.valueOnChange(true);
                              onChanged(strEmpty(p) ? t : "$p $t");
                              return true;
                            },
                            outCallback: callback,
                            margin: const EdgeInsets.only(left: 0, right: 0));
                      },
                      itemCount: logic.regionList.length,
                    ),
                  ),
                ),
              ])
                ..mainAxisSize = MainAxisSize.min
                // 内容文本左对齐
                ..crossAxisAlignment = CrossAxisAlignment.start,
            ])
              ..mainAxisSize = MainAxisSize.min
        // ..useParent((v) => v..bg = Theme.of(context).colorScheme.background),
        );
  }
}
