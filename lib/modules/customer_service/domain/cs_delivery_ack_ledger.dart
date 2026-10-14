import 'package:imboy/service/auth_session_scope.dart';

/// Successful delivery ACKs only; no message bodies, credentials or read facts.
class CsDeliveryAckLedger {
  CsDeliveryAckLedger._(this._auth) : _observed = _auth.current {
    _auth.addListener(_authChanged);
  }

  static final _instances = Expando<CsDeliveryAckLedger>();
  static const _capacity = 2048;

  factory CsDeliveryAckLedger.forAuth(AuthSessionReader auth) {
    final existing = _instances[auth];
    if (existing != null && !existing._disposed) return existing;
    return _instances[auth] = CsDeliveryAckLedger._(auth);
  }

  final AuthSessionReader _auth;
  AuthSessionScope _observed;
  bool _disposed = false;
  final _entries = <(String, int, String, String)>{};

  void _authChanged() {
    final now = _auth.current;
    if (now != _observed || now.transitioning || now.uid.isEmpty) {
      _entries.clear();
    }
    _observed = now;
  }

  bool contains(AuthSessionScope auth, String scope, String messageId) {
    _authChanged();
    return !_disposed &&
        _auth.isCurrent(auth) &&
        _entries.contains((auth.uid, auth.generation, scope, messageId));
  }

  void record(AuthSessionScope auth, String scope, String messageId) {
    _authChanged();
    if (_disposed || !_auth.isCurrent(auth)) return;
    _entries.add((auth.uid, auth.generation, scope, messageId));
    if (_entries.length > _capacity) _entries.remove(_entries.first);
  }

  void invalidateScope(String scope) {
    _entries.removeWhere((entry) => entry.$3 == scope);
  }

  /// Owned shutdown/tests only; normal page disposal retains confirmed ACKs.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _auth.removeListener(_authChanged);
    _entries.clear();
  }
}
