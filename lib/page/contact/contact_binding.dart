import 'package:get/get.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'contact_logic.dart';

class ContactBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => UserRepoLocal());
    Get.lazyPut(() => ContactLogic());
  }
}
