import 'package:get/get.dart';
import 'package:imboy/store/provider/user_provider.dart';

import 'logout_account_state.dart';

class LogoutAccountLogic extends GetxController {
  final LogoutAccountState state = LogoutAccountState();

  changeValue(String val) {
    state.selectedValue.value = val == 'read_and_agree' ? '' : 'read_and_agree';
  }

  Future<bool> applyLogout() async {
    return await UserProvider().applyLogout();
  }
}
