import 'package:imboy/store/repository/user_repo_local.dart';

class CurrentIdentity {
  final String account;
  final String email;
  final String mobile;
  final String lastLoginAccount;

  const CurrentIdentity({
    this.account = '',
    this.email = '',
    this.mobile = '',
    this.lastLoginAccount = '',
  });
}

CurrentIdentity readCurrentIdentity() {
  try {
    final user = UserRepoLocal.to.currentUser;
    return CurrentIdentity(
      account: user?.account.trim() ?? '',
      email: user?.email.trim() ?? '',
      mobile: user?.mobile.trim() ?? '',
      lastLoginAccount: UserRepoLocal.to.lastLoginAccount.trim(),
    );
  } catch (_) {
    return const CurrentIdentity();
  }
}

Future<void> quitLoginIfPossible() async {
  try {
    await UserRepoLocal.to.quitLogin();
  } catch (_) {}
}
