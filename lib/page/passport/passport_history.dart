part of 'passport_notifier.dart';

// History persistence and projection are independent of the provider lifecycle.
// The notifier owns state access and checks ref.mounted after asynchronous work.
PassportState _readPassportLoginHistory(PassportState previous) {
  final history = LoginAccountHistoryService();
  List<String> readHistory(String key) => history.visibleHistory(
    history.readHistory(key),
    environment: currentEnv.isEmpty ? 'pro' : currentEnv,
    endpoint: Env().apiBaseUrl,
  );
  return previous.copyWith(
    loginHistory: readHistory(Keys.loginHistory),
    accountHistory: readHistory(Keys.loginHistoryAccount),
    mobileHistory: readHistory(Keys.loginHistoryMobile),
    emailHistory: readHistory(Keys.loginHistoryEmail),
  );
}

Future<List<String>> _savePassportLoginHistory(String key, String value) async {
  final history = LoginAccountHistoryService();
  final stored = history.readHistory(key);
  final visible = history.visibleHistory(
    stored,
    environment: currentEnv.isEmpty ? 'pro' : currentEnv,
    endpoint: Env().apiBaseUrl,
  );
  final list = List<String>.from(visible);
  list.remove(value);
  list.insert(0, value);
  final trimmed = list.length > 5 ? list.sublist(0, 5) : list;

  await StorageService.to.persistPreference(
    () => StorageService.to.setList(key, [
      ...trimmed,
      ...stored.where((entry) => !visible.contains(entry)),
    ]),
  );
  return trimmed;
}
