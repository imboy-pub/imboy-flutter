import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';

class SampleForm extends StatelessWidget {
  final String title;
  final Future<bool> Function(String) callback;

  final String value;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  SampleForm({
    this.title = "",
    required this.callback,
    this.value = "",
    this.margin,
    this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
  });

  final logic = Get.put(SampleFormLogic());

  @override
  Widget build(BuildContext context) {
    logic.setValue(false);
    logic._textController.text = value;

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
                      String trimmedText = logic._textController.text.trim();
                      if (trimmedText == '') {
                        logic.setValue(false);
                      } else {
                        bool res = await callback(trimmedText);
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
                child: TextFormField(
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
                      logic.setValue(false);
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
                      logic.setValue(false);
                    } else {
                      logic.setValue(true);
                    }
                  },
                  onSaved: (value) {
                    debugPrint(
                        ">>> on _inputFocusNode onSaved ${logic._inputFocusNode.hasFocus} ${logic._textController.text} == ${value}");
                  },
                  validator: (value) {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SampleFormLogic extends GetxController {
  // 用户名控制器

  FocusNode _inputFocusNode = new FocusNode();
  TextEditingController _textController = TextEditingController();
  RxBool valueChanged = false.obs;

  void setValue(bool ischange) {
    // 必须使用 .value 修饰具体的值
    this.valueChanged.value = ischange;
    update([this.valueChanged]);
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
