import 'package:get/get.dart';
import 'profile_logic.dart';

/// 增强版个人信息管理绑定
class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileLogic>(() => ProfileLogic());
  }
}
