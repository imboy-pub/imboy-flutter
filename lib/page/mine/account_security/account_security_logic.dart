import 'package:get/get.dart';
import 'package:imboy/store/provider/user_provider.dart';

import 'account_security_state.dart';

class AccountSecurityLogic extends GetxController {
  final AccountSecurityState state = AccountSecurityState();

  Future<bool> changeEmail(email) async {
    bool res = await UserProvider().changeEmail(email);
    return res;
  }
}
