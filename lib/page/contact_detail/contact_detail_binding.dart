import 'package:get/get.dart';

import 'contact_detail_logic.dart';

class ContactDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ContactDetailLogic());
  }
}
