import 'package:get/get.dart';

import 'scanner_logic.dart';

class ScannerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ScannerLogic());
  }
}
