part of 'web_shell_bootstrap.dart';

String webGroupMemberDisplayName(
  GroupMemberModel? member,
  ContactModel? contact, {
  required String groupId,
  required String authorId,
}) {
  if (member == null ||
      member.groupId != groupId ||
      member.userId != authorId ||
      member.status != 1)
    return '';
  final names = GroupListService.pickMemberNames([
    {
      'alias': member.alias,
      'remark': contact?.peerId == authorId && contact?.isFriend == 1
          ? contact!.remark
          : '',
      'nickname': member.nickname,
    },
  ]);
  return names.isEmpty ? '' : names.first;
}

/// One panel-owned, read-only cache; failed pages remain retryable.
class WebGroupMetadataReader {
  WebGroupMetadataReader({
    required this.groupId,
    required this.ownerUid,
    required this.current,
    required this.localMember,
    required this.localContact,
    required this.localTitle,
    required this.pageLoader,
  });
  final String groupId, ownerUid;
  final bool Function() current;
  final Future<GroupMemberModel?> Function(String) localMember;
  final Future<ContactModel?> Function(String) localContact;
  final Future<String> Function() localTitle;
  final Future<Map<String, dynamic>?> Function(int, int) pageLoader;
  final _pages = <int, Future<List<GroupMemberModel>>>{};
  int? _total;
  static const _size = 100, _maxPages = 20;

  Future<List<GroupMemberModel>> _page(int page) async {
    if (!current()) return [];
    final existing = _pages[page];
    if (existing != null) return existing;
    final future = _fetch(page);
    _pages[page] = future;
    try {
      return await future;
    } on Object {
      _pages.remove(page);
      rethrow;
    }
  }

  Future<List<GroupMemberModel>> _fetch(int page) async {
    final payload = await pageLoader(page, _size);
    if (!current()) return [];
    final rows = payload?['list'];
    final total = payload?['total'];
    if (rows is! List ||
        total is! int ||
        total < 0 ||
        payload?['page'] != page ||
        payload?['size'] != _size) {
      throw const FormatException('invalid group metadata page');
    }
    final members = rows.map((row) {
      if (row is! Map) throw const FormatException('invalid group member');
      final member = GroupMemberModel.fromJson({
        for (final key in [
          'group_id',
          'user_id',
          'alias',
          'nickname',
          'status',
        ])
          if (row.containsKey(key)) key: row[key],
      });
      if (member.groupId != groupId || member.userId == '0') {
        throw const FormatException('group metadata identity changed');
      }
      return member;
    }).toList();
    if (members.length > _size ||
        (members.isEmpty && total > (page - 1) * _size)) {
      throw const FormatException('incomplete group metadata page');
    }
    _total = total;
    return members;
  }

  Future<String> _name(GroupMemberModel member) async {
    if (!current()) return '';
    final contact = await localContact(member.userId);
    if (!current()) return '';
    return webGroupMemberDisplayName(
      member,
      contact,
      groupId: groupId,
      authorId: member.userId,
    );
  }

  Future<String> author(String uid) async {
    if (!current()) return '';
    final local = await localMember(uid);
    if (!current()) return '';
    if (local != null) return _nameForAuthor(local, uid);
    for (var page = 1; page <= _maxPages && current(); page++) {
      final members = await _page(page);
      if (!current()) return '';
      for (final member in members) {
        if (member.userId == uid) return _nameForAuthor(member, uid);
      }
      if (_total != null && page * _size >= _total!) return _friendRemark(uid);
    }
    if (!current()) return '';
    throw StateError('group metadata page limit reached');
  }

  Future<String> _friendRemark(String uid) async {
    if (!current()) return '';
    final contact = await localContact(uid);
    if (!current() || contact?.peerId != uid || contact?.isFriend != 1)
      return '';
    return contact!.remark.trim();
  }

  Future<String> _nameForAuthor(GroupMemberModel member, String uid) async {
    if (member.groupId != groupId || member.userId != uid || member.status != 1)
      return '';
    return _name(member);
  }

  Future<String> title() async {
    if (!current()) return '';
    final local = await localTitle();
    if (!current()) return '';
    if (local.trim().isNotEmpty) return local;
    final members = await _page(1);
    if (!current()) return '';
    final names = <String>[];
    for (final member
        in members
            .where((m) => m.userId != ownerUid && m.status == 1)
            .take(3)) {
      final name = await _name(member);
      if (!current()) return '';
      if (name.isNotEmpty) names.add(name);
    }
    return names.join('、');
  }
}

Future<String> _readWebGroupTitle(
  String groupId,
  AccountLocalTaskOwner account,
  bool Function() current,
) async {
  if (!current()) return '';
  final rows = await SqliteService.to.rawQuery(
    'SELECT gm.alias AS alias, gm.nickname AS nickname, '
    'c.remark AS remark FROM group_member gm LEFT JOIN contact c '
    'ON c.peer_id = gm.user_id AND c.user_id = ? AND c.is_friend = 1 '
    'WHERE gm.group_id = ? AND gm.user_id != ? AND gm.status = 1 LIMIT 3',
    [account.uid, groupId, account.uid],
    false,
  );
  if (!current()) return '';
  return GroupListService.pickMemberNames(rows).join('、');
}

class WebGroupMessageAuthor extends StatefulWidget {
  const WebGroupMessageAuthor({
    super.key,
    required this.groupId,
    required this.authorId,
    required this.currentUserId,
    required this.child,
    this.sessionReader,
    this.nameLoader,
  });
  final String groupId, authorId, currentUserId;
  final Widget child;
  final AuthSessionReader? sessionReader;
  final Future<String> Function(String, String)? nameLoader;
  @override
  State<WebGroupMessageAuthor> createState() => _WebGroupMessageAuthorState();
}

class _WebGroupMessageAuthorState extends State<WebGroupMessageAuthor> {
  late AuthSessionReader _sessions;
  late AuthSessionScope _owner;
  late AccountLocalTaskOwner _account;
  int _request = 0;
  String _name = '';
  bool _failed = false;
  bool get _active =>
      _sessions.isCurrent(_owner) &&
      _owner.uid == widget.currentUserId &&
      UserRepoLocal.to.currentUid == widget.currentUserId &&
      AccountLocalTaskOwner.capture(uid: _owner.uid) == _account;

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessionReader ?? authSessionReader;
    _sessions.addListener(_onAuth);
    _start();
  }

  void _start() {
    _request++;
    _name = '';
    _failed = false;
    _owner = _sessions.current;
    _account = AccountLocalTaskOwner.capture(uid: _owner.uid);
    if (_active) unawaited(_load(_request));
  }

  void _onAuth() {
    if (mounted) setState(_start);
  }

  @override
  void didUpdateWidget(covariant WebGroupMessageAuthor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionReader != widget.sessionReader) {
      _sessions.removeListener(_onAuth);
      _sessions = widget.sessionReader ?? authSessionReader;
      _sessions.addListener(_onAuth);
    }
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.authorId != widget.authorId ||
        oldWidget.currentUserId != widget.currentUserId ||
        oldWidget.sessionReader != widget.sessionReader ||
        oldWidget.nameLoader != widget.nameLoader)
      _start();
  }

  Future<void> _load(int request) async {
    final gid = widget.groupId, uid = widget.authorId;
    bool current() =>
        mounted &&
        request == _request &&
        _active &&
        gid == widget.groupId &&
        uid == widget.authorId;
    try {
      final value =
          await (widget.nameLoader?.call(gid, uid) ?? Future<String>.value(''));
      if (current()) setState(() => _name = value.trim());
    } on Object {
      if (current()) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _request++;
    _sessions.removeListener(_onAuth);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    final own = widget.authorId == widget.currentUserId;
    final name = _name.isEmpty ? context.t.common.unknown : _name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: own
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: own
                ? AppSpacing.regular
                : AppSpacing.regular +
                      AppSizes.avatarSizeSmall +
                      AppSpacing.small,
            end: AppSpacing.regular,
            bottom: AppSpacing.tiny,
          ),
          child: GestureDetector(
            onTap: _failed ? () => setState(_start) : null,
            child: Tooltip(
              message: _failed ? context.t.common.loadError : name,
              excludeFromSemantics: true,
              child: Semantics(
                label: name,
                excludeSemantics: true,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.getTextSecondary(
                      Theme.of(context).brightness,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

extension _WebGroupIdentity on WebChatPanelState {
  Future<String> _ownedGroupTitle(
    GroupModel? group,
    String gid,
    bool Function() current,
  ) async {
    final explicit = group?.title.trim() ?? '';
    if (explicit.isNotEmpty && explicit != gid) return explicit;
    // Old derived titles may contain a member's private account.
    final account = _resourceOwner;
    if (account == null) return '';
    try {
      return await _metadata(gid, account, current).title();
    } on Object {
      return '';
    }
  }

  WebGroupMetadataReader _metadata(
    String gid,
    AccountLocalTaskOwner account,
    bool Function() current,
  ) {
    return _groupMetadata ??= WebGroupMetadataReader(
      groupId: gid,
      ownerUid: account.uid,
      current: current,
      localMember: (uid) => GroupMemberRepo().findByUserId(gid, uid),
      localContact: (uid) =>
          ContactRepo().findByUid(uid, autoFetch: false, account: account.uid),
      localTitle: () => _readWebGroupTitle(gid, account, current),
      pageLoader: (page, size) =>
          widget.groupMemberPageLoader?.call(gid, page, size) ??
          GroupMemberApi().page(gid: gid, page: page, size: size, strict: true),
    );
  }

  Future<String> _groupAuthorName(String gid, String uid) {
    final owner = _owner, account = _resourceOwner;
    final selection = widget.selection;
    final request = _request;
    bool current() =>
        owner != null &&
        account != null &&
        _current(request, selection, owner) &&
        gid == selection.peerId &&
        AccountLocalTaskOwner.capture(uid: owner.uid) == account;
    if (!current()) return Future.value('');
    return _metadata(gid, account!, current).author(uid);
  }

  Widget _withGroupAuthor(Message message, Widget child) {
    if (widget.selection.chatType != 'C2G' ||
        message.authorId.isEmpty ||
        message.authorId == 'system')
      return child;
    return WebGroupMessageAuthor(
      key: ValueKey((
        _owner,
        _resourceOwner,
        widget.selection.peerId,
        message.authorId,
        message.id,
      )),
      groupId: widget.selection.peerId,
      authorId: message.authorId,
      currentUserId: widget.currentUserId,
      sessionReader: _sessions,
      nameLoader: _groupAuthorLoader,
      child: child,
    );
  }

  Widget _wrapWebMessage(
    BuildContext context,
    Message message,
    Widget child,
    ({bool enabled, double fraction, int delayMs})? readPolicy,
  ) {
    if (message.authorId == widget.currentUserId)
      return _withGroupAuthor(message, child);
    final owner = _owner;
    final resourceOwner = _resourceOwner;
    final selection = widget.selection;
    final notifier = _notifier;
    bool current() =>
        mounted &&
        _active &&
        owner == _owner &&
        resourceOwner != null &&
        AccountLocalTaskOwner.capture(uid: widget.currentUserId) ==
            resourceOwner &&
        selection == widget.selection &&
        identical(notifier, _notifier) &&
        ref.read(chatProvider).currentConversationId == _conversationKey &&
        readPolicy?.enabled == true &&
        _webReadPolicy(widget.currentUserId, UserRepoLocal.to.currentUser) ==
            readPolicy;
    return _withGroupAuthor(
      message,
      WebVisibleMessageRead(
        key: ValueKey((
          owner,
          resourceOwner,
          selection.chatType,
          selection.peerId,
          message.id,
        )),
        enabled: readPolicy?.enabled ?? false,
        fraction: readPolicy?.fraction ?? 0.6,
        delayMs: readPolicy?.delayMs ?? 400,
        isCurrent: current,
        onRead: () => _commitWrappedRead(message, notifier, selection, current),
        child: child,
      ),
    );
  }

  Future<bool> _commitWrappedRead(
    Message message,
    ChatNotifier? notifier,
    ChatSelection selection,
    bool Function() current,
  ) async {
    if (!current() || notifier == null) return false;
    final conversation = _conversation;
    final burn =
        ChatPageUtils.isBurnMessage(message) &&
        (message.metadata?['burn_read_at'] ?? 0) == 0;
    if (burn && conversation == null) return false;
    return commitWebVisibleMessageRead(
      isCurrent: current,
      markRead: () => notifier.markAsRead(
        selection.chatType,
        selection.peerId,
        [message.id],
        syncToServer: true,
      ),
      markBurnRead: !burn
          ? null
          : () => notifier.markBurnReadAt(
              conversation!,
              message.id,
              readAtMs: DateTimeHelper.millisecond(),
              isCurrent: current,
            ),
    );
  }
}
