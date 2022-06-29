import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class UpdatePageLogic extends GetxController {
  // 用户名控制器

  FocusNode inputFocusNode = FocusNode();
  TextEditingController textController = TextEditingController();

  RxBool valueChanged = false.obs;
  RxString val = "".obs;

  RxList regionList = [].obs;

  void valueOnChange(bool ischange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = ischange;
    update([valueChanged]);
  }

  void setVal(String value) {
    // 必须使用 .value 修饰具体的值
    val.value = value;
    update([val]);
  }

  void loadData() async {
    //加载城市列表
    await rootBundle.loadString('assets/data/region.json').then((value) {
      regionList.clear();
      regionList.value = json.decode(value);
      update([regionList]);
    });
  }
}
