import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

class SampleForm extends StatelessWidget {
  final String title;
  final Future<bool> Function(String) callback;

  String value;
  final String field;
  // final EdgeInsetsGeometry? padding;

  SampleForm({
    this.title = "",
    required this.callback,
    this.value = "",
    this.field = "",
    // this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
  });

  final logic = Get.put(SampleFormLogic());

  @override
  Widget build(BuildContext context) {
    logic._textController.text = value;
    Widget body = SizedBox.shrink();
    if (this.field == "input") {
      logic.valueOnChange(false);
      body = this.inputField();
    } else if (this.field == "text") {
      logic.valueOnChange(true);
      body = this.textField();
    } else if (this.field == "radio") {
      logic.val.value = this.value;
      logic.valueOnChange(true);
      body = this.radioField();
    }
    return Container(
      color: AppColors.AppBarColor,
      width: Get.width,
      height: Get.height,
      child: Wrap(
        children: <Widget>[
          Container(
            color: AppColors.AppBarColor,
            height: 72,
            padding: const EdgeInsets.fromLTRB(0, 28, 16, 6),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    Get.back();
                  },
                  child: Text(
                    'button_cancel'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 中间用Expanded控件
                ),
                Obx(
                  () => ElevatedButton(
                    onPressed: () async {
                      if (this.field == "input") {
                        String trimmedText = logic._textController.text.trim();
                        if (trimmedText == '') {
                          logic.valueOnChange(false);
                        } else {
                          bool res = await callback(trimmedText);
                          if (res) {
                            Get.back();
                          }
                        }
                      } else if (this.field == "text") {
                        String trimmedText = logic._textController.text.trim();
                        bool res = await callback(trimmedText);
                        if (res) {
                          Get.back();
                        }
                      } else if (this.field == "radio") {
                        bool res = await callback(logic.val.value);
                        if (res) {
                          Get.back();
                        }
                      }
                    },
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
                                MaterialStateProperty.all(Size(60, 40)),
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
                                MaterialStateProperty.all(Size(60, 40)),
                            visualDensity: VisualDensity.compact,
                            padding: MaterialStateProperty.all(EdgeInsets.zero),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: body,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget inputField() {
    return TextFormField(
      autofocus: true,
      focusNode: logic._inputFocusNode,
      controller: logic._textController,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.none,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(14, 0, 8, 0),
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(width: 1.0, color: Colors.red),
          ),
          errorStyle: TextStyle(),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(width: 1.0, color: Colors.red),
          ),
          border: InputBorder.none),
      readOnly: false,
      onFieldSubmitted: (value) async {
        // FocusScope.of(context).requestFocus();
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
        if (value == '' || value == this.value) {
          logic.valueOnChange(false);
        } else {
          logic.valueOnChange(true);
        }
      },
      onSaved: (value) {
        debugPrint(
            ">>> on _inputFocusNode onSaved ${logic._inputFocusNode.hasFocus} ${logic._textController.text} == ${value}");
      },
      validator: (value) {},
    );
  }

  Widget textField() {
    return TextFormField(
      autofocus: true,
      focusNode: logic._inputFocusNode,
      controller: logic._textController,
      keyboardType: TextInputType.multiline,
      maxLines: 5,
      minLines: 3,
      maxLength: 56,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.newline,

      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(14, 16, 8, 0),
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                width: 1.0,
                color: AppColors.AppBarColor,
              )),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(width: 1.0, color: Colors.red),
          ),
          errorStyle: TextStyle(),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(width: 1.0, color: Colors.red),
          ),
          border: InputBorder.none),
      readOnly: false,
      onFieldSubmitted: (value) async {
        bool res = await callback(value);
        if (res) {
          Get.back();
        }
      },
      //style: ,
      onChanged: (value) {},
      onSaved: (value) {
        debugPrint(
            ">>> on _inputFocusNode onSaved ${logic._inputFocusNode.hasFocus} ${logic._textController.text} == ${value}");
      },
      validator: (value) {},
    );
  }

  Widget radioField() {
    return Obx(() => n.Column(
          [
            n.NikuRadioListTile<String>(
              "1",
              title: n.Text("男".tr),
              controlAffinity: ListTileControlAffinity.trailing,
              activeColor: AppColors.primaryElement,
              groupValue: logic.val.value,
              onChanged: (val) {
                logic.setVal(val!);
              },
            ),
            Container(
                width: Get.width * 0.92,
                height: 1,
                color: AppColors.AppBarColor),
            n.NikuRadioListTile<String>(
              "2",
              title: n.Text("女".tr),
              controlAffinity: ListTileControlAffinity.trailing,
              activeColor: AppColors.primaryElement,
              groupValue: logic.val.value,
              onChanged: (val) {
                // debugPrint(">>> on logic.setVal ${val}");
                logic.setVal(val!);
              },
            ),
            Container(
                width: Get.width * 0.92,
                height: 1,
                color: AppColors.AppBarColor),
            n.NikuRadioListTile<String>(
              "3",
              title: n.Text("保密".tr),
              controlAffinity: ListTileControlAffinity.trailing,
              activeColor: AppColors.primaryElement,
              groupValue: logic.val.value,
              onChanged: (val) {
                debugPrint(">>> on ");
                logic.setVal(val!);
              },
            ),
          ],
          mainAxisSize: MainAxisSize.min,
        )..useParent((v) => v..bg = Colors.white));
  }
}

class SampleFormLogic extends GetxController {
  // 用户名控制器

  FocusNode _inputFocusNode = new FocusNode();
  TextEditingController _textController = TextEditingController();
  RxBool valueChanged = false.obs;
  RxString val = "".obs;

  void valueOnChange(bool ischange) {
    // 必须使用 .value 修饰具体的值
    this.valueChanged.value = ischange;
    update([this.valueChanged]);
  }

  void setVal(String value) {
    // 必须使用 .value 修饰具体的值
    this.val.value = value;
    update([this.val]);
  }

  @override
  void onInit() {
    super.onInit();
    // print("渲染完成");
  }

  @override
  void onClose() {
    super.onClose();
    // print("close");
  }
}
