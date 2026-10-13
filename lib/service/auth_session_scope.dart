import 'package:flutter/foundation.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

typedef AuthSessionScope = ({String uid, int generation, bool transitioning});

/// Authentication identity only; no profile, tokens, storage or write methods.
abstract interface class AuthSessionReader implements Listenable {
  AuthSessionScope get current;
  bool isCurrent(AuthSessionScope captured);
}

final AuthSessionReader authSessionReader = _LocalAuthSessionReader();

class _LocalAuthSessionReader implements AuthSessionReader {
  UserRepoLocal get _source => UserRepoLocal.to;

  @override
  AuthSessionScope get current => (
    uid: _source.currentUid,
    generation: _source.sessionGeneration,
    transitioning: _source.isAuthTransitioning,
  );

  @override
  bool isCurrent(AuthSessionScope captured) {
    final now = current;
    return captured.uid.isNotEmpty &&
        !captured.transitioning &&
        !now.transitioning &&
        now.uid == captured.uid &&
        now.generation == captured.generation;
  }

  @override
  void addListener(VoidCallback listener) => _source.addAuthListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _source.removeAuthListener(listener);
}
