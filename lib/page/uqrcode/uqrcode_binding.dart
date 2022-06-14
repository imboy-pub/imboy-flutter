import 'package:get/get.dart';

import 'uqrcode_logic.dart';

class UqrcodeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => UqrcodeLogic());
  }
}
