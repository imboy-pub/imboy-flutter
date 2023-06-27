import 'package:get/get.dart';

import 'tag_add_state.dart';

class TagAddLogic extends GetxController {
  final TagAddState state = TagAddState();

  RxBool valueChanged = false.obs;

  void valueOnChange(bool isChange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = isChange;
    update([valueChanged]);
  }
}
