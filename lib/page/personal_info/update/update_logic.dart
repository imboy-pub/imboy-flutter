import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class UpdatePageLogic extends GetxController {
  // 用户名控制器

  FocusNode inputFocusNode = FocusNode();
  TextEditingController textController = TextEditingController();

  RxBool valueChanged = false.obs;
  RxString val = "".obs;

  void valueOnChange(bool isChange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = isChange;
  }

  void setVal(String value) {
    // 必须使用 .value 修饰具体的值
    val.value = value;
    update([val]);
  }
}
