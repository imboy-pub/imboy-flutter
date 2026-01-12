import 'package:get/get.dart';

import 'contact_logic.dart';

class ContactBinding extends Bindings {
  @override
  void dependencies() {
    // ContactLogic 已在 init.dart 中全局注册
    // 这里使用 find 确保实例存在
    if (!Get.isRegistered<ContactLogic>()) {
      Get.lazyPut(() => ContactLogic());
    }
  }
}
