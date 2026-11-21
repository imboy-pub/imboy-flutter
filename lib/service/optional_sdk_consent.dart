import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/auth_session_scope.dart';

enum OptionalSdkPurpose { push, maps }

typedef OptionalSdkScope = ({
  String environment,
  String endpoint,
  String uid,
  int generation,
});

class OptionalSdkConsent extends ChangeNotifier {
  OptionalSdkConsent({required this.readScope, required this.policyVersion});

  static final instance = OptionalSdkConsent(
    readScope: () {
      final auth = authSessionReader.current;
      return (
        environment: currentEnv,
        endpoint: Env().apiBaseUrl,
        uid:
            authSessionReader.isCurrent(auth) &&
                !authSessionReader.transitionFailed
            ? auth.uid
            : '',
        generation: auth.generation,
      );
    },
    policyVersion: const String.fromEnvironment(
      'IMBOY_OPTIONAL_SDK_POLICY_REVISION',
      defaultValue: '1',
    ),
  );

  final OptionalSdkScope Function() readScope;
  final String policyVersion;
  final _revisions = <String, Object>{};
  final _writing = <String>{};
  final _blocked = <String>{};

  String? _key(OptionalSdkPurpose purpose, OptionalSdkScope scope) {
    if (scope.uid.isEmpty ||
        scope.endpoint.isEmpty ||
        scope.environment.isEmpty ||
        policyVersion.isEmpty) {
      return null;
    }
    return 'optional_sdk:${jsonEncode([scope.environment, scope.endpoint, scope.uid, purpose.name, policyVersion])}';
  }

  /// A stable grant changes on account/environment/consent transition.
  Object? grant(OptionalSdkPurpose purpose) {
    try {
      final scope = readScope();
      final key = _key(purpose, scope);
      if (key == null ||
          _writing.contains(key) ||
          _blocked.contains(key) ||
          StorageService.to.getString(key) != 'granted') {
        return null;
      }
      return (scope, _revisions.putIfAbsent(key, Object.new));
    } on Object {
      return null;
    }
  }

  Future<void> setGranted(OptionalSdkPurpose purpose, bool value) async {
    final scope = readScope();
    final key = _key(purpose, scope);
    if (key == null || !_writing.add(key)) {
      throw StateError('Optional SDK consent is unavailable');
    }
    _revisions[key] = Object();
    _blocked.add(key);
    notifyListeners();
    try {
      final storage = StorageService.to;
      await storage.persistPreference(
        () => storage.setString(key, value ? 'granted' : 'denied'),
      );
      if (readScope() != scope) {
        throw StateError('Optional SDK consent scope changed');
      }
      _blocked.remove(key);
    } finally {
      _writing.remove(key);
      notifyListeners();
    }
  }
}
