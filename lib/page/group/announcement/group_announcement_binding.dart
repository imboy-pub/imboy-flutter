import 'package:get/get.dart';
import 'group_announcement_logic.dart';

class GroupAnnouncementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GroupAnnouncementLogic>(() => GroupAnnouncementLogic());
  }
}
