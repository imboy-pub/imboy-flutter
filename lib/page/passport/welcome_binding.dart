import 'package:get/get.dart';

import 'passport_logic.dart';
import '../mine/language/language_logic.dart';

class WelcomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PassportLogic());
    Get.lazyPut(() => LanguageLogic());
  }
}
