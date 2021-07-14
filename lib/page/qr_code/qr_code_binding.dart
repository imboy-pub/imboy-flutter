import 'package:get/get.dart';

import 'qr_code_logic.dart';

class QrCodeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => QrCodeLogic());
  }
}
