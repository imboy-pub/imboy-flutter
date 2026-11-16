import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/ui/avatar_group.dart';
import 'package:imboy/component/ui/avatar_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/group_collab/domain/value/group_role.dart';
import 'package:imboy/page/group/announcement/announcement_model.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WebGroupInfoSnapshot {
  WebGroupInfoSnapshot({
    required this.group,
    this.currentMember,
    required List<GroupMemberModel> members,
    required List<AnnouncementModel> announcements,
  }) : members = List.unmodifiable(members),
       announcements = List.unmodifiable(announcements);
  final GroupModel group;
  final GroupMemberModel? currentMember;
  final List<GroupMemberModel> members;
  final List<AnnouncementModel> announcements;
}

typedef WebGroupInfoLoader = Future<WebGroupInfoSnapshot> Function(
  String groupId,
  String currentUid,
  bool Function() current,
);

List<GroupMemberModel> _memberPreview(dynamic payload, String gid) {
  final rows = payload?['list'] ?? payload?['items'];
  if (rows is! List) {
    throw const FormatException('invalid group members');
  }
  return rows.map((row) {
    if (row is! Map) {
      throw const FormatException('invalid group member');
    }
    final member = GroupMemberModel.fromJson(Map<String, dynamic>.from(row));
    if (member.groupId != gid) {
      throw const FormatException('member group changed');
    }
    return member;
  }).toList();
}

/// The page endpoint scopes rows by request gid but omits group_id in its SELECT.
List<AnnouncementModel> parseWebGroupNoticePreview(
  dynamic payload,
  String gid,
) {
  final map = IMBoyHttpResponse.payloadAsMap(payload);
  final rows = map['items'] ?? map['list'];
  if (rows is! List) {
    throw const FormatException('invalid group notices');
  }
  final notices = <AnnouncementModel>[];
  for (final row in rows) {
    if (row is! Map) {
      throw const FormatException('invalid group notice');
    }
    final scoped = Map<String, dynamic>.from(row);
    if (!scoped.containsKey('group_id')) {
      scoped['group_id'] = gid;
    }
    final notice = AnnouncementModel.fromJson(scoped);
    if (notice.groupId != gid) {
      throw const FormatException('notice group changed');
    }
    // The management page also returns drafts; the read-only view shows published notices.
    if (parseModelInt(scoped['status']) == 1) {
      notices.add(notice);
    }
  }
  return notices;
}

Future<WebGroupInfoSnapshot> loadWebGroupInfo(
  String gid,
  String uid,
  bool Function() current,
) async {
  void check() {
    if (!current()) {
      throw CancelException();
    }
  }

  check();
  final cachedMember = await GroupMemberRepo().findByUserId(gid, uid);
  check();
  final raw = await GroupApi().detail(
    gid: gid,
    strict: true,
    syncEncryptionMode: false,
  );
  check();
  if (cachedMember != null &&
      (cachedMember.groupId != gid || cachedMember.userId != uid)) {
    throw const FormatException('self identity changed');
  }
  final groupJson = raw['group'];
  final group = GroupModel.fromJson(
    groupJson is Map ? Map<String, dynamic>.from(groupJson) : raw,
  );
  if (group.groupId != gid) {
    throw const FormatException('group identity changed');
  }
  final memberRows = await GroupMemberApi().page(
    gid: gid,
    size: 18,
    strict: true,
  );
  check();
  final members = _memberPreview(memberRows, gid);
  final response = await GroupApi.announcementsPage(gid: gid);
  check();
  if (!response.ok) {
    throw BadRequestException(message: response.msg, code: response.code);
  }
  var me = cachedMember;
  for (final member in members) {
    if (member.userId == uid) {
      me = member;
    }
  }
  return WebGroupInfoSnapshot(
    group: group,
    currentMember: me,
    members: members,
    announcements: parseWebGroupNoticePreview(response.payload, gid),
  );
}

bool canRestoreGroupDialogFocus({
  required FocusNode? focused,
  required FocusScopeNode currentScope,
  required FocusScopeNode rootScope,
}) =>
    focused == null ||
    identical(focused, rootScope) ||
    (identical(focused, currentScope) && currentScope.focusedChild == null);

class WebGroupInfoButton extends StatefulWidget {
  const WebGroupInfoButton({
    super.key,
    required this.groupId,
    this.sessionReader,
    this.panelBuilder,
  });
  final String groupId;
  final AuthSessionReader? sessionReader;
  final WidgetBuilder? panelBuilder;
  @override
  State<WebGroupInfoButton> createState() => _WebGroupInfoButtonState();
}

class _WebGroupInfoButtonState extends State<WebGroupInfoButton> {
  bool _opening = false;
  final FocusNode _buttonFocus = FocusNode();

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) {
      return;
    }
    final restoreFocus = _buttonFocus.hasFocus;
    setState(() => _opening = true);
    FocusManager.instance.primaryFocus?.unfocus();
    ModalRoute<void>? dialogRoute;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          dialogRoute = ModalRoute.of<void>(context);
          return Dialog(
            child: SizedBox(
              width: 560,
              height: MediaQuery.sizeOf(context).height * .75,
              child: Column(
                children: [
                  Padding(
                    padding: AppSpacing.allRegular,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(Translations.of(context).group.groupInfo),
                        ),
                        IconButton(
                          tooltip: Translations.of(context).common.cancel,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(CupertinoIcons.xmark),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        widget.panelBuilder?.call(context) ??
                        WebGroupInfoPanel(
                          groupId: widget.groupId,
                          sessionReader: widget.sessionReader,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      await dialogRoute?.completed;
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        if (restoreFocus && dialogRoute != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                _opening ||
                ModalRoute.of(context)?.isCurrent != true)
              return;
            final focused = FocusManager.instance.primaryFocus;
            if (canRestoreGroupDialogFocus(
              focused: focused,
              currentScope: FocusScope.of(context),
              rootScope: FocusManager.instance.rootScope,
            )) {
              _buttonFocus.requestFocus();
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('web-group-info'),
    focusNode: _buttonFocus,
    tooltip: Translations.of(context).group.groupInfo,
    onPressed: _opening ? null : _open,
    icon: const Icon(CupertinoIcons.info_circle),
  );
}

class WebGroupInfoPanel extends StatefulWidget {
  const WebGroupInfoPanel({
    super.key,
    required this.groupId,
    this.sessionReader,
    this.loader = loadWebGroupInfo,
  });
  final String groupId;
  final AuthSessionReader? sessionReader;
  final WebGroupInfoLoader loader;
  @override
  State<WebGroupInfoPanel> createState() => _WebGroupInfoPanelState();
}

class _WebGroupInfoPanelState extends State<WebGroupInfoPanel> {
  late final _sessions = widget.sessionReader ?? authSessionReader;
  WebGroupInfoSnapshot? _snapshot;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _sessions.addListener(_onAuth);
    _listen();
    unawaited(_load());
  }

  final _events = <StreamSubscription<dynamic>>[];
  void _listen() {
    _events.add(
      AppEventBus.on<ChatExtendEvent>().listen((event) {
        if (!_active) {
          return;
        }
        if (event.payload['groupId']?.toString() != widget.groupId) {
          return;
        }
        if (event.payload['userId']?.toString() != _sessions.current.uid) {
          return;
        }
        if (event.type == 'leave_group') {
          _request++;
          setState(() {
            _snapshot = null;
            _error = t.common.noPermission;
          });
        }
        if (event.type == 'join_group') {
          _retry();
        }
      }),
    );
    _events.add(
      AppEventBus.on<GroupMemberRoleEvent>().listen((event) {
        if (!_active) {
          return;
        }
        if (event.gid == widget.groupId &&
            event.userId == _sessions.current.uid) {
          _retry();
        }
      }),
    );
  }

  @override
  void didUpdateWidget(covariant WebGroupInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _retry();
    }
  }

  AuthSessionScope? _owner;
  AccountLocalTaskOwner? _resourceOwner;
  bool get _active =>
      mounted &&
      _owner != null &&
      _sessions.isCurrent(_owner!) &&
      AccountLocalTaskOwner.capture(uid: _owner!.uid) == _resourceOwner;
  void _onAuth() {
    if (!mounted || (_owner == _sessions.current && _active)) {
      return;
    }
    _request++;
    setState(() {
      _snapshot = null;
      _error = t.common.noPermission;
    });
    final route = ModalRoute.of(context), navigator = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route?.isCurrent == true && navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  void _retry() {
    if (!mounted || (_owner != null && !_active)) {
      return;
    }
    setState(() {
      _snapshot = null;
      _error = null;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request, gid = widget.groupId;
    final owner = _sessions.current;
    final resourceOwner = AccountLocalTaskOwner.capture(uid: owner.uid);
    _owner = owner;
    _resourceOwner = resourceOwner;
    bool current() =>
        mounted &&
        request == _request &&
        gid == widget.groupId &&
        _sessions.isCurrent(owner) &&
        AccountLocalTaskOwner.capture(uid: owner.uid) == resourceOwner;
    if (!current()) {
      setState(() => _error = t.common.noPermission);
      return;
    }
    try {
      final value = await widget.loader(gid, owner.uid, current);
      if (!current()) {
        return;
      }
      if (value.group.groupId != gid) {
        throw const FormatException('group identity changed');
      }
      setState(() {
        _snapshot = value;
        _error = null;
      });
    } catch (error) {
      if (!current()) {
        return;
      }
      final code = error is GroupMemberApiException
          ? error.code
          : error is BadRequestException
          ? error.code
          : null;
      final message = const {401, 403, 404}.contains(code)
          ? t.common.noPermission
          : error is GroupMemberApiException
          ? error.message
          : error is BadRequestException
          ? error.message
          : t.common.operationFailedAgainLater;
      setState(() {
        _snapshot = null;
        _error = message.isEmpty ? t.common.operationFailedAgainLater : message;
      });
    }
  }

  @override
  void dispose() {
    _request++;
    _sessions.removeListener(_onAuth);
    for (final event in _events) {
      unawaited(event.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_owner != null && !_active) {
      return Center(child: Text(t.common.noPermission));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            CupertinoButton(
              onPressed: _retry,
              child: Text(t.common.buttonRetry),
            ),
          ],
        ),
      );
    }
    final snapshot = _snapshot;
    return snapshot == null
        ? const Center(child: CupertinoActivityIndicator())
        : WebGroupInfoView(snapshot: snapshot);
  }
}

class WebGroupInfoView extends StatelessWidget {
  const WebGroupInfoView({super.key, required this.snapshot});
  final WebGroupInfoSnapshot snapshot;
  String? get _role {
    if (snapshot.currentMember?.status != 1) {
      return null;
    }
    return switch (snapshot.currentMember?.role) {
      GroupRole.member => t.group.groupMemberRoleLabel,
      GroupRole.guest => t.group.groupGuest,
      GroupRole.admin => t.group.groupAdmin,
      GroupRole.owner => t.group.groupOwner,
      GroupRole.viceOwner => t.enterpriseApp.groupRoleViceOwner,
      _ => null,
    };
  }

  Widget _identity(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          GroupAvatar(
            avatar: snapshot.group.avatar,
            memberAvatars: snapshot.members
                .map((m) => m.avatar)
                .where((a) => a.isNotEmpty)
                .take(9)
                .toList(),
          ),
          AppSpacing.horizontalMedium,
          Expanded(
            child: Text(
              snapshot.group.displayTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      AppSpacing.verticalRegular,
      Text('${snapshot.group.memberCount} ${t.group.groupMembers}'),
      if (_role != null) Text(_role!),
      if (snapshot.currentMember?.isMuted() == true) Text(t.chat.youAreMuted),
      if (snapshot.group.introduction.isNotEmpty)
        Text(snapshot.group.introduction),
    ],
  );
  Widget _members(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${t.group.groupMembers} (${snapshot.members.length}/${snapshot.group.memberCount})',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (snapshot.members.isEmpty) Text(t.common.noData),
      LayoutBuilder(
        builder: (_, constraints) => AvatarList(
          memberList: snapshot.members
              .map(
                (m) => PeopleModel(
                  id: m.userId,
                  account: '',
                  nickname: m.alias.isNotEmpty
                      ? m.alias
                      : m.nickname.isNotEmpty
                      ? m.nickname
                      : t.main.unnamed,
                  avatar: m.avatar,
                ),
              )
              .toList(),
          column: (constraints.maxWidth / 72).floor().clamp(1, 8).toInt(),
        ),
      ),
    ],
  );
  Widget _notices(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t.common.groupAnnouncement,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (snapshot.announcements.isEmpty) Text(t.common.noData),
      for (final notice in snapshot.announcements)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
          child: Text(notice.content),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.allRegular,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(context),
        AppSpacing.verticalRegular,
        _members(context),
        AppSpacing.verticalRegular,
        _notices(context),
      ],
    ),
  );
}
