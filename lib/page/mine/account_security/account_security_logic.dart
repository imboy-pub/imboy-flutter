import 'package:get/get.dart';
import 'package:imboy/store/provider/user_provider.dart';

import 'account_security_state.dart';

class AccountSecurityLogic extends GetxController {
  final AccountSecurityState state = AccountSecurityState();

  Future<bool> changeEmail({required String email, required String code}) async {
    bool res = await UserProvider().changeEmail(email: email, code: code);
    return res;
  }
}
