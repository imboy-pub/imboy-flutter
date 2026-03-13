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

CurrentIdentity readCurrentIdentity() => const CurrentIdentity();

Future<void> quitLoginIfPossible() async {}
