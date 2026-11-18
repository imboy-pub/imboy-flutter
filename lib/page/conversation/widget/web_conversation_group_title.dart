import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/events/ui_events.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/api/group_member_api.dart';

/// Only public display fields enter this projection; account is never a name.
String safeConversationGroupNames(List<Map<String, dynamic>> rows) {
  final names = <String>[];
  for (final row in rows) {
    for (final key in const ['alias', 'remark', 'nickname']) {
      final name = (row[key]?.toString() ?? '').trim();
      if (name.isNotEmpty) {
        names.add(name);
        break;
      }
    }
  }
  return names.join('、');
}

/// Read-only: never persists a derived name or imports the old conversation title.
Future<String> readSafeConversationGroupTitle(
  String gid,
  AccountLocalTaskOwner owner,
  bool Function() current,
) async {
  if (!current()) return '';
  final db = await SqliteService.to.db;
  if (!current()) return '';
  if (db == null) throw StateError('Group title database unavailable');
  final groups = await db.rawQuery(
    'SELECT title FROM "group" WHERE id = ? LIMIT 1',
    [gid],
  );
  if (!current()) return '';
  final explicit = groups.isEmpty
      ? ''
      : (groups.first['title']?.toString() ?? '').trim();
  if (explicit.isNotEmpty) return explicit;
  final rows = await db.rawQuery(
    'SELECT gm.alias, gm.nickname, c.remark FROM group_member gm '
    'LEFT JOIN contact c ON c.peer_id = gm.user_id AND c.user_id = ? AND c.is_friend = 1 '
    'WHERE gm.group_id = ? AND gm.user_id != ? AND gm.status = 1 LIMIT 3',
    [owner.uid, gid, owner.uid],
  );
  if (!current()) return '';
  final local = safeConversationGroupNames(rows);
  if (local.isNotEmpty) return local;
  final page = await GroupMemberApi().page(
    gid: gid,
    page: 1,
    size: 100,
    strict: true,
  );
  if (!current()) return '';
  final members = page?['list'];
  if (members is! List || page?['page'] != 1 || page?['size'] != 100) {
    throw const FormatException('Invalid group display page');
  }
  final safe = <Map<String, dynamic>>[];
  for (final value in members) {
    if (value is! Map || value['group_id']?.toString() != gid) {
      throw const FormatException('Group display identity changed');
    }
    if (value['user_id']?.toString() == owner.uid || value['status'] != 1) {
      continue;
    }
    final contacts = await db.rawQuery(
      'SELECT remark FROM contact WHERE user_id = ? AND peer_id = ? AND is_friend = 1 LIMIT 1',
      [owner.uid, value['user_id'].toString()],
    );
    if (!current()) return '';
    safe.add({
      'alias': value['alias'],
      'nickname': value['nickname'],
      'remark': contacts.isEmpty ? '' : contacts.first['remark'],
    });
    if (safe.length == 3) break;
  }
  return safeConversationGroupNames(safe);
}

typedef ConversationGroupTitleLoader = Future<String> Function(
  String gid,
  AccountLocalTaskOwner owner,
  bool Function() current,
);

/// One page-owned projection drives both filtering and rendered row names.
class WebConversationGroupTitles extends ChangeNotifier {
  WebConversationGroupTitles({
    AuthSessionReader? sessions,
    this.loader = readSafeConversationGroupTitle,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  }) : sessions = sessions ?? authSessionReader {
    this.sessions.addListener(invalidate);
    _subscriptions.add(
      AppEventBus.on<WebSocketStatusChangedEvent>().listen((event) {
        if (event.status.toLowerCase() == 'connected') {
          for (final gid in _failed.toList()) {
            invalidateGroup(gid);
          }
        }
      }),
    );
    _subscriptions.add(
      AppEventBus.on<GroupEditEvent>().listen(
        (event) => invalidateGroup(event.gid),
      ),
    );
    _subscriptions.add(
      AppEventBus.on<GroupMemberUpdateEvent>().listen(
        (event) => invalidateGroup(event.groupId),
      ),
    );
    _subscriptions.add(
      AppEventBus.on<ContactUpdatedEvent>().listen((event) {
        if (event.updateType == ContactUpdateType.remarkUpdated ||
            event.updatedFields?.any(
                  (key) => key == 'nickname' || key == 'remark',
                ) ==
                true) {
          invalidate();
        }
      }),
    );
    _subscriptions.add(
      AppEventBus.on<DataSyncCompleteEvent>().listen((event) {
        if (event.success &&
            (event.syncType == 'group' || event.syncType == 'contact')) {
          invalidate();
        }
      }),
    );
    _subscriptions.add(
      AppEventBus.on<DataWrapperEvent<dynamic>>().listen((event) {
        final data = event.data;
        if (data is GroupModel) invalidateGroup(data.groupId);
        if (data is ContactModel) invalidate();
      }),
    );
  }
  final AuthSessionReader sessions;
  final ConversationGroupTitleLoader loader;
  final List<Duration> retryDelays;
  final _retryTimers = <String, Timer>{};
  final _retryCounts = <String, int>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _groupRevisions = <String, int>{};
  final _titles = <String, String>{};
  final _pending = <String>{};
  final _failed = <String>{};
  AuthSessionScope? _scope;
  AccountLocalTaskOwner? _owner;
  int _revision = 0;
  bool _disposed = false;

  void _clearRetries() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryCounts.clear();
  }

  void invalidate() {
    if (_disposed) return;
    _clearRetries();
    _revision++;
    _titles.clear();
    _pending.clear();
    _failed.clear();
    _scope = null;
    _owner = null;
    notifyListeners();
  }

  void invalidateGroup(String gid) {
    if (_disposed) return;
    _retryTimers.remove(gid)?.cancel();
    _retryCounts.remove(gid);
    _groupRevisions[gid] = (_groupRevisions[gid] ?? 0) + 1;
    _failed.remove(gid);
    _titles.remove(gid);
    _pending.remove(gid);
    notifyListeners();
  }

  String title(String gid) {
    final scope = sessions.current;
    final owner = AccountLocalTaskOwner.capture(uid: scope.uid);
    if (_scope != scope || _owner != owner) {
      _clearRetries();
      _revision++;
      _titles.clear();
      _pending.clear();
      _failed.clear();
      _scope = scope;
      _owner = owner;
    }
    if (!sessions.isCurrent(scope) || _disposed) return '';
    if (!_titles.containsKey(gid) &&
        !_failed.contains(gid) &&
        _pending.add(gid)) {
      final revision = _revision;
      unawaited(_load(gid, scope, owner, revision, _groupRevisions[gid] ?? 0));
    }
    return _titles[gid] ?? '';
  }

  Future<void> _load(
    String gid,
    AuthSessionScope scope,
    AccountLocalTaskOwner owner,
    int revision,
    int groupRevision,
  ) async {
    bool current() =>
        !_disposed &&
        revision == _revision &&
        groupRevision == (_groupRevisions[gid] ?? 0) &&
        sessions.isCurrent(scope) &&
        AccountLocalTaskOwner.capture(uid: scope.uid) == owner;
    if (!current()) return;
    String value = '';
    var failed = false;
    try {
      value = await loader(gid, owner, current);
    } on Object {
      failed = true;
      // Retry through bounded timers/recovery events, never directly on rebuild.
    }
    if (!current()) return;
    if (failed) {
      _failed.add(gid);
      _scheduleRetry(gid, current);
    } else {
      _retryCounts.remove(gid);
      _titles[gid] = value.trim();
    }
    _pending.remove(gid);
    notifyListeners();
  }

  void _scheduleRetry(String gid, bool Function() current) {
    final attempt = _retryCounts[gid] ?? 0;
    if (attempt >= retryDelays.length || _retryTimers.containsKey(gid)) return;
    _retryCounts[gid] = attempt + 1;
    _retryTimers[gid] = Timer(retryDelays[attempt], () {
      _retryTimers.remove(gid);
      if (!current()) return;
      _failed.remove(gid);
      title(gid);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _clearRetries();
    _revision++;
    sessions.removeListener(invalidate);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

class WebConversationGroupTitle extends StatefulWidget {
  const WebConversationGroupTitle({
    super.key,
    required this.groupId,
    required this.builder,
    this.sessions,
    this.loader = readSafeConversationGroupTitle,
    this.titles,
  });
  final String groupId;
  final Widget Function(String rawTitle) builder;
  final AuthSessionReader? sessions;
  final ConversationGroupTitleLoader loader;
  final WebConversationGroupTitles? titles;
  @override
  State<WebConversationGroupTitle> createState() =>
      _WebConversationGroupTitleState();
}

class _WebConversationGroupTitleState extends State<WebConversationGroupTitle> {
  late WebConversationGroupTitles _titles;
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _titles =
        widget.titles ??
        WebConversationGroupTitles(
          sessions: widget.sessions,
          loader: widget.loader,
        );
    _titles.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant WebConversationGroupTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId && widget.titles == null) {
      _titles.invalidate();
    }
  }

  @override
  void dispose() {
    _titles.removeListener(_changed);
    if (widget.titles == null) _titles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_titles.title(widget.groupId));
}
