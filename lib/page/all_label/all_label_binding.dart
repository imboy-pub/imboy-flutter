import 'package:get/get.dart';

import 'all_label_logic.dart';

class AllLabelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AllLabelLogic());
  }
}
