import 'package:get/get.dart';

import 'friend_circle_logic.dart';

class FriendCircleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FriendCircleLogic());
  }
}
