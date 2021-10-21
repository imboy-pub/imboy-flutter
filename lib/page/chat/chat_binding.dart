import 'package:get/get.dart';

import 'chat_logic.dart';
import 'chat_state.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatLogic());
    Get.lazyPut(() => ChatState());
  }
}
