import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';

typedef WebReadingAnchor = ({String id, double y});

/// Small session-only cache; it never retains messages, views or controllers.
class WebReadingAnchorStore {
  static const _limit = 24;
  final _anchors = <String, WebReadingAnchor>{};
  (AuthSessionScope, AccountLocalTaskOwner)? _scope;

  void _bind(AuthSessionScope session, AccountLocalTaskOwner owner) {
    final scope = (session, owner);
    if (_scope != scope) {
      _anchors.clear();
      _scope = scope;
    }
  }

  WebReadingAnchor? read(
    AuthSessionScope session,
    AccountLocalTaskOwner owner,
    String conversation,
  ) {
    _bind(session, owner);
    final value = _anchors.remove(conversation);
    if (value != null) _anchors[conversation] = value;
    return value;
  }

  void write(
    AuthSessionScope session,
    AccountLocalTaskOwner owner,
    String conversation,
    WebReadingAnchor? anchor,
  ) {
    _bind(session, owner);
    _anchors.remove(conversation);
    if (anchor == null) return;
    _anchors[conversation] = anchor;
    if (_anchors.length > _limit) _anchors.remove(_anchors.keys.first);
  }

  void clear() {
    _scope = null;
    _anchors.clear();
  }
}

final webReadingAnchorStoreProvider = Provider<WebReadingAnchorStore>((ref) {
  final store = WebReadingAnchorStore();
  var session = authSessionReader.current;
  void onSession() {
    final next = authSessionReader.current;
    if (next != session) store.clear();
    session = next;
  }

  authSessionReader.addListener(onSession);
  ref.onDispose(() {
    authSessionReader.removeListener(onSession);
    store.clear();
  });
  return store;
});
