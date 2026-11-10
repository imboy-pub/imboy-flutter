import 'dart:convert';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

/// String-only legacy history cannot authorize deleting a user's local data.
class LoginAccountIdentityUnavailableException implements Exception {
  const LoginAccountIdentityUnavailableException();
}

class LoginAccountCleanupBusyException implements Exception {
  const LoginAccountCleanupBusyException();
}

class LoginAccountSharedDataException implements Exception {
  const LoginAccountSharedDataException();
}

/// Legacy shared files cannot authorize deleting another account's data.
class AccountLocalDataOwnershipException implements Exception {
  const AccountLocalDataOwnershipException();
}

/// Recorded from successful authentication, never inferred from login text.
/// Contains identifiers only, no credentials.
class LoginAccountIdentity {
  const LoginAccountIdentity({
    required this.uid,
    required this.environment,
    required this.endpoint,
    required this.aliases,
  });

  final String uid;
  final String environment;
  final String endpoint;
  final Set<String> aliases;

  bool sameAccount(LoginAccountIdentity other) =>
      uid == other.uid &&
      environment == other.environment &&
      endpoint == other.endpoint;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'environment': environment,
    'endpoint': endpoint,
    'aliases': aliases.toList(),
  };

  static LoginAccountIdentity? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final uid = raw['uid'];
    final environment = raw['environment'];
    final endpoint = raw['endpoint'];
    final aliases = raw['aliases'];
    if (uid is! String ||
        uid.isEmpty ||
        environment is! String ||
        environment.isEmpty ||
        endpoint is! String ||
        endpoint.isEmpty ||
        aliases is! List ||
        aliases.any((a) => a is! String)) {
      return null;
    }
    return LoginAccountIdentity(
      uid: uid,
      environment: environment,
      endpoint: endpoint,
      aliases: aliases.cast<String>().where((a) => a.isNotEmpty).toSet(),
    );
  }
}

/// Ownership registry for the existing login history lists. Persisted as one
/// value and retained throughout failed cleanup so the same account is retryable.
class LoginAccountHistoryService {
  static const storageKey = 'login_account_identities_v1';
  static const localProfileKey = '_login_account_identity_v1';
  static const _ownershipIncompleteKey = 'ownershipIncomplete';

  Map<String, dynamic> _read() {
    String raw;
    try {
      raw = StorageService.to.getString(storageKey);
    } on TypeError {
      throw const FormatException('Invalid login account history value');
    }
    if (raw.isEmpty) {
      if (StorageService.to.containsKey(storageKey)) {
        throw const FormatException('Empty login account history value');
      }
      return {'accounts': <dynamic>[]};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['accounts'] is! List ||
        (decoded.containsKey(_ownershipIncompleteKey) &&
            decoded[_ownershipIncompleteKey] is! bool)) {
      throw const FormatException('Invalid login account history');
    }
    return decoded;
  }

  List<LoginAccountIdentity> _accounts(Map<String, dynamic> document) {
    final accounts = <LoginAccountIdentity>[];
    for (final raw in document['accounts'] as List) {
      final account = LoginAccountIdentity.fromJson(raw);
      if (account == null) {
        throw const FormatException('Invalid login account identity');
      }
      accounts.add(account);
    }
    return accounts;
  }

  Future<void> _write(Map<String, dynamic> document) =>
      StorageService.to.persistPreference(
        () => StorageService.to.setString(
          storageKey,
          jsonEncode({'version': 1, ...document}),
        ),
      );

  Future<LoginAccountIdentity> rememberLogin({
    required String account,
    required Map<String, dynamic> profile,
    required String environment,
    required String endpoint,
  }) async {
    final uid = (profile['user_id'] ?? profile['uid'])?.toString() ?? '';
    if (uid.isEmpty || environment.isEmpty || endpoint.isEmpty) {
      throw const LoginAccountIdentityUnavailableException();
    }
    Map<String, dynamic> document;
    List<LoginAccountIdentity> accounts;
    try {
      document = _read();
      accounts = _accounts(document);
    } on FormatException {
      // Authentication can restore a login hint, not prove exclusive ownership
      // of existing UID-scoped files or keys. Persist this uncertainty together
      // with the repaired registry; later login/forget writes must retain it.
      accounts = [];
      document = {_ownershipIncompleteKey: true};
    }
    final aliases = <String>{
      if (account.trim().isNotEmpty) account,
      if (account.trim().isNotEmpty) account.trim(),
      for (final key in ['account', 'email', 'mobile'])
        if (profile[key] is String &&
            (profile[key] as String).trim().isNotEmpty)
          (profile[key] as String).trim(),
    };
    final identity = LoginAccountIdentity(
      uid: uid,
      environment: environment,
      endpoint: endpoint,
      aliases: aliases,
    );
    final updated = <LoginAccountIdentity>[];
    for (final previous in accounts) {
      if (previous.sameAccount(identity)) {
        aliases.addAll(previous.aliases);
      } else {
        updated.add(previous);
      }
    }
    // Renamed/reassigned aliases follow the latest authenticated owner, only
    // within the same deployment.
    final result = <LoginAccountIdentity>[identity];
    for (final previous in updated) {
      final retainedAliases =
          previous.environment == environment && previous.endpoint == endpoint
          ? previous.aliases.difference(aliases)
          : previous.aliases;
      // Display aliases may move to a new UID without deleting the old data.
      // Keep the storage owner even when it has no selectable login alias.
      result.add(
        LoginAccountIdentity(
          uid: previous.uid,
          environment: previous.environment,
          endpoint: previous.endpoint,
          aliases: retainedAliases,
        ),
      );
    }
    await _write({
      ...document,
      'accounts': result.map((a) => a.toJson()).toList(),
    });
    return identity;
  }

  LoginAccountIdentity resolve({
    required String value,
    required String environment,
    required String endpoint,
  }) {
    List<LoginAccountIdentity> accounts;
    try {
      accounts = _accounts(_read());
    } on FormatException {
      throw const LoginAccountIdentityUnavailableException();
    }
    final matches = accounts
        .where(
          (account) =>
              account.environment == environment &&
              account.endpoint == endpoint &&
              account.aliases.contains(value),
        )
        .toList();
    if (matches.length != 1) {
      throw const LoginAccountIdentityUnavailableException();
    }
    return matches.single;
  }

  bool ownsLastSession(LoginAccountIdentity identity) {
    // Written atomically with the actual local profile, after token storage.
    // Preparing a history entry alone must never transfer session ownership.
    final last = LoginAccountIdentity.fromJson(
      StorageService.getMap(Keys.currentUser)[localProfileKey],
    );
    return last != null && last.sameAccount(identity);
  }

  /// Several legacy stores use uid alone. Do not delete their shared namespace
  /// while another deployment's identity still references the same local uid.
  void requireIndependentStorage(LoginAccountIdentity identity) {
    final document = _read();
    final accounts = _accounts(document);
    if (document[_ownershipIncompleteKey] == true) {
      throw const AccountLocalDataOwnershipException();
    }
    if (!accounts.any((account) => account.sameAccount(identity))) {
      throw const LoginAccountIdentityUnavailableException();
    }
    if (accounts.any(
      (account) =>
          account.uid == identity.uid && !account.sameAccount(identity),
    )) {
      throw const LoginAccountSharedDataException();
    }
  }

  /// Preserve the selection across process restarts if native preference
  /// writes fail part way through removing history lists.
  List<String> readHistory(String key) {
    final values = StorageService.to.getStringList(key) ?? [];
    try {
      final retryHistory = _read()['retryHistory'];
      final retry = retryHistory is Map ? retryHistory[key] : null;
      return {
        ...values,
        if (retry is List) ...retry.whereType<String>(),
      }.toList();
    } on FormatException {
      return values.toSet().toList();
    }
  }

  /// Legacy hints stay visible but require a successful login before cleanup.
  List<String> visibleHistory(
    List<String> history, {
    required String environment,
    required String endpoint,
  }) {
    List<LoginAccountIdentity> accounts;
    try {
      accounts = _accounts(_read());
    } on FormatException {
      return List.of(history);
    }
    return history.where((value) {
      final owners = accounts.where((a) => a.aliases.contains(value));
      return owners.isEmpty ||
          owners.any(
            (a) => a.environment == environment && a.endpoint == endpoint,
          );
    }).toList();
  }

  /// Only after every data store was cleared. Keep ownership until every
  /// history write succeeds, including after partial storage failures.
  Future<void> forget(LoginAccountIdentity identity) async {
    final document = _read();
    final remaining = _accounts(document)
        .where((a) => !a.sameAccount(identity))
        .toList();
    final retainedAliases = remaining.expand((a) => a.aliases).toSet();
    final removedAliases = identity.aliases.difference(retainedAliases);
    final histories = <String, List<String>>{
      for (final key in [
        Keys.loginHistory,
        Keys.loginHistoryAccount,
        Keys.loginHistoryEmail,
        Keys.loginHistoryMobile,
      ])
        key: readHistory(key),
    };
    // This journal contains identifiers only. Publish it before the first
    // destructive preference write; drop it atomically with the identity.
    await _write({...document, 'retryHistory': histories});
    for (final entry in histories.entries) {
      await StorageService.to.persistPreference(
        () => StorageService.to.setList(
          entry.key,
          entry.value
              .where((value) => !removedAliases.contains(value))
              .toList(),
        ),
      );
    }
    if (removedAliases.contains(
      StorageService.to.getString(Keys.lastLoginAccount),
    )) {
      await StorageService.to.persistPreference(
        () => StorageService.to.remove(Keys.lastLoginAccount),
      );
    }
    // Completing one identity's history removal cannot certify other storage.
    final completed = Map<String, dynamic>.of(document)
      ..remove('retryHistory')
      ..['accounts'] = remaining.map((a) => a.toJson()).toList();
    await _write(completed);
  }
}
