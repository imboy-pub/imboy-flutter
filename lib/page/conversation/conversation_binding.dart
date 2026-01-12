import 'package:get/get.dart';

import 'conversation_logic.dart';

class ConversationBinding extends Bindings {
  @override
  void dependencies() {
    // ConversationLogic 已在 init.dart 中全局注册
    // 这里使用 find 确保实例存在
    if (!Get.isRegistered<ConversationLogic>()) {
      Get.lazyPut(() => ConversationLogic(), fenix: true);
    }
  }
}
