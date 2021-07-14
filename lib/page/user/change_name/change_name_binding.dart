import 'package:get/get.dart';

import 'change_name_logic.dart';

class ChangeNameBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChangeNameLogic());
  }
}
