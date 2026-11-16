import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/policy/event_filter_rules.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

/// A revoked lease stays cancelled even if an unmute arrives before a draft save ends.
class WebGroupSendScope extends InheritedWidget {
  const WebGroupSendScope({
    super.key,
    required this.allowed,
    required this.capture,
    required super.child,
  });
  final bool allowed;
  final bool Function() Function() capture;

  static bool allowedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WebGroupSendScope>()
          ?.allowed ??
      true;
  static bool Function() leaseOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WebGroupSendScope>()?.capture() ??
      () => true;
  @override
  bool updateShouldNotify(WebGroupSendScope oldWidget) =>
      allowed != oldWidget.allowed;
}

/// Local feedback and a revocable composer boundary; backend ACL remains final.
/// An absent local membership is not a removal verdict.
class WebGroupComposerGate extends StatefulWidget {
  const WebGroupComposerGate({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.child,
    this.sessionReader,
    this.memberLoader,
    this.groupLoader,
    this.clock,
  });
  final String groupId, currentUserId;
  final Widget child;
  final AuthSessionReader? sessionReader;
  final Future<GroupMemberModel?> Function(String, String)? memberLoader;
  final Future<GroupModel?> Function(String)? groupLoader;
  final int Function()? clock;
  @override
  State<WebGroupComposerGate> createState() => _WebGroupComposerGateState();
}

class _WebGroupComposerGateState extends State<WebGroupComposerGate> {
  late final _sessions = widget.sessionReader ?? authSessionReader;
  late AuthSessionScope _owner;
  late AccountLocalTaskOwner _resourceOwner;
  int _permissionRevision = 0;
  final _events = <StreamSubscription<dynamic>>[];
  GroupMemberModel? _member;
  GroupModel? _group;
  Timer? _expiry;
  int? _groupMute, _globalMute;
  int _request = 0, _eventRevision = 0;
  bool _loading = true, _failed = false, _left = false;
  int get _now => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  bool get _active =>
      mounted &&
      _sessions.isCurrent(_owner) &&
      _owner.uid == widget.currentUserId &&
      AccountLocalTaskOwner.capture(uid: _owner.uid) == _resourceOwner;
  bool _muted(int? until) => until != null && (until == 0 || until > _now);
  String get _conversationKey => ConversationUk3Generator.generateSmart(
    type: 'C2G',
    currentUserId: widget.currentUserId,
    peerId: widget.groupId,
  );

  @override
  void initState() {
    super.initState();
    _owner = _sessions.current;
    _resourceOwner = AccountLocalTaskOwner.capture(uid: _owner.uid);
    _sessions.addListener(_onAuth);
    _listen();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant WebGroupComposerGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.currentUserId != widget.currentUserId) {
      _owner = _sessions.current;
      _resourceOwner = AccountLocalTaskOwner.capture(uid: _owner.uid);
      _permissionRevision++;
      _expiry?.cancel();
      _groupMute = null;
      _globalMute = null;
      _left = false;
      _member = null;
      _group = null;
      _loading = true;
      _failed = false;
      unawaited(_refresh());
    }
  }

  void _onAuth() {
    if (!mounted || (_owner == _sessions.current && _active)) {
      return;
    }
    _request++;
    _permissionRevision++;
    _expiry?.cancel();
    setState(() {
      _member = null;
      _group = null;
      _left = true;
    });
  }

  void _listen() {
    _events.add(
      AppEventBus.on<GroupMemberMuteEvent>().listen((event) {
        if (!_active ||
            event.gid != widget.groupId ||
            event.userId != _owner.uid) {
          return;
        }
        _eventRevision++;
        _permissionRevision++;
        setState(
          () => _groupMute = event.muteUntilMs <= 0 ? 0 : event.muteUntilMs,
        );
        _scheduleExpiry();
      }),
    );
    _events.add(
      AppEventBus.on<GroupMemberUnmuteEvent>().listen((event) {
        if (!_active ||
            event.gid != widget.groupId ||
            event.userId != _owner.uid) {
          return;
        }
        _eventRevision++;
        _permissionRevision++;
        setState(() => _groupMute = null);
        _scheduleExpiry();
      }),
    );
    _listenAccountMute();
    _events.add(AppEventBus.on<ChatExtendEvent>().listen(_onMembership));
  }

  void _listenAccountMute() {
    _events.add(
      AppEventBus.on<UserMutedEvent>().listen((event) {
        if (!_active ||
            !muteEventMatchesConversation(
              eventConversationId: event.conversationId,
              currentConversationId: _conversationKey,
            )) {
          return;
        }
        _permissionRevision++;
        setState(
          () => _globalMute = event.muteUntilMs <= 0 ? 0 : event.muteUntilMs,
        );
        _scheduleExpiry();
      }),
    );
    _events.add(
      AppEventBus.on<UserUnmutedEvent>().listen((event) {
        if (!_active ||
            !muteEventMatchesConversation(
              eventConversationId: event.conversationId,
              currentConversationId: _conversationKey,
            )) {
          return;
        }
        _permissionRevision++;
        setState(() => _globalMute = null);
        _scheduleExpiry();
      }),
    );
  }

  void _onMembership(ChatExtendEvent event) {
    if (!_active ||
        event.payload['groupId']?.toString() != widget.groupId ||
        event.payload['userId']?.toString() != _owner.uid) {
      return;
    }
    if (event.type == 'leave_group') {
      _request++;
      _permissionRevision++;
      setState(() {
        _left = true;
        _loading = false;
        _failed = false;
        _member = null;
      });
    } else if (event.type == 'join_group') {
      setState(() => _left = false);
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    _permissionRevision++;
    _loading = true;
    final request = ++_request, revision = _eventRevision;
    final gid = widget.groupId, uid = widget.currentUserId;
    bool current() =>
        _active &&
        request == _request &&
        gid == widget.groupId &&
        uid == widget.currentUserId;
    try {
      final member =
          await (widget.memberLoader?.call(gid, uid) ??
              GroupMemberRepo().findByUserId(gid, uid));
      if (!current()) {
        return;
      }
      final group =
          await (widget.groupLoader?.call(gid) ?? GroupRepo().findById(gid));
      if (!current()) {
        return;
      }
      if ((member != null && (member.groupId != gid || member.userId != uid)) ||
          (group != null && group.groupId != gid)) {
        throw const FormatException('group identity changed');
      }
      setState(() {
        _member = member;
        _group = group;
        _loading = false;
        _failed = false;
        if (revision == _eventRevision) {
          _groupMute = member?.isMuted(nowMs: _now) == true
              ? member!.muteUntilMs
              : null;
        }
      });
      _scheduleExpiry();
    } on Object {
      if (!current()) {
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final ends = [
      _groupMute,
      _globalMute,
    ].whereType<int>().where((end) => end > _now).toList()..sort();
    if (ends.isEmpty) {
      return;
    }
    _expiry = Timer(Duration(milliseconds: ends.first - _now), () {
      if (!_active) {
        return;
      }
      setState(() {});
      _scheduleExpiry();
    });
  }

  @override
  void dispose() {
    _request++;
    _expiry?.cancel();
    _sessions.removeListener(_onAuth);
    for (final event in _events) {
      unawaited(event.cancel());
    }
    super.dispose();
  }

  bool get _denied =>
      _left ||
      (_member != null && _member!.status != 1) ||
      (_group != null && _group!.status != 1);
  bool get _mutedNow => _muted(_groupMute) || _muted(_globalMute);
  bool get _blocked => _loading || _failed || _denied || _mutedNow;
  bool Function() _captureSendLease() {
    final revision = _permissionRevision;
    return () => _active && !_blocked && revision == _permissionRevision;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return const SizedBox.shrink();
    }
    final denied = _denied;
    final muted = _mutedNow;
    final blocked = _blocked;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_loading) const CupertinoActivityIndicator(),
        if (_failed)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.common.operationFailedAgainLater),
              CupertinoButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _failed = false;
                  });
                  unawaited(_refresh());
                },
                child: Text(t.common.buttonRetry),
              ),
            ],
          )
        else if (denied)
          Text(t.common.noPermission)
        else if (muted)
          Text(t.chat.youAreMuted),
        Offstage(
          offstage: blocked,
          child: ExcludeFocus(
            excluding: blocked,
            child: IgnorePointer(
              ignoring: blocked,
              child: WebGroupSendScope(
                allowed: !blocked,
                capture: _captureSendLease,
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
