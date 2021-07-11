import 'package:get/get.dart';

import 'chat_more_logic.dart';

class ChatMoreBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatMoreLogic());
  }
}
