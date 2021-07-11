import 'package:get/get.dart';

import 'chat_info_logic.dart';

class ChatInfoBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatInfoLogic());
  }
}
