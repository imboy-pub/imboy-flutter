import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/badge_widget.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_account_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Only server-authorized workspace snapshots; no personal or warm-cache rows.
class WorkspaceConversationsPage extends ConsumerStatefulWidget {
  const WorkspaceConversationsPage({
    super.key,
    this.embedded = false,
    this.active = true,
  });
  final bool embedded;
  final bool active;
  @override
  ConsumerState<WorkspaceConversationsPage> createState() =>
      _WorkspaceConversationsPageState();
}

class _WorkspaceConversationsPageState
    extends ConsumerState<WorkspaceConversationsPage> {
  final _search = TextEditingController();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _refreshTimer;
  Timer? _expiryTimer;
  Timer? _poll;
  int _expires = 0;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      AppEventBus.on<DataWrapperEvent<dynamic>>().listen((event) {
        if (event.data is ConversationModel &&
            (event.data as ConversationModel).type == 'C2G') {
          _scheduleRefresh();
        }
      }),
    );
    _subscriptions.add(
      AppEventBus.on<ChatExtendEvent>().listen((_) => _scheduleRefresh()),
    );
    _subscriptions.add(
      AppEventBus.on<WebSocketStatusChangedEvent>().listen((event) {
        if (event.status.toLowerCase() == 'connected') {
          _scheduleRefresh();
        }
      }),
    );
    // ponytail: 30s active-page reconciliation covers worker lag/missed events;
    // replace with a scoped authority event once that server contract exists.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ref.read(workspaceShellProvider).destination ==
          WorkspaceShellDestination.conversations) {
        _reload();
      }
    });
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 500), _reload);
  }

  void _reload() {
    if (!mounted || !widget.active) return;
    final id = ref.read(currentWorkspaceProvider)?.id ?? '';
    if (id.isNotEmpty) {
      ref.invalidate(workspaceConversationsProvider(id));
    }
  }

  void _scheduleExpiry(List<WorkspaceConversationModel> list) {
    final now = DateTimeHelper.millisecond();
    final deadlines = list
        .map((row) => row.expiresAt)
        .where((time) => time > now);
    final next = deadlines.isEmpty
        ? 0
        : deadlines.reduce((a, b) => a < b ? a : b);
    if (_expires == next) return;
    _expiryTimer?.cancel();
    _expires = next;
    if (next > 0) {
      _expiryTimer = Timer(Duration(milliseconds: next - now + 1), _reload);
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(currentWorkspaceProvider);
    ref.listen(currentWorkspaceProvider, (before, after) {
      if (before?.id != after?.id) {
        setState(_search.clear);
      }
    });
    ref.listen(currentUserProvider.select((user) => user?.uid), (
      before,
      after,
    ) {
      if (before != after) {
        setState(_search.clear);
      }
    });
    final id = ws?.id ?? '';
    final body = id.isEmpty
        ? WorkspaceEmptyView(
            icon: CupertinoIcons.chat_bubble,
            title: t.chat.groupChat,
            subtitle: t.workspace.emptyNoWorkspace,
          )
        : _body(id);
    if (widget.embedded) return body;
    return IosPageTemplate(
      title: t.chat.groupChat,
      leading: const WorkspaceSwitcherChip(),
      actions: const [WorkspaceAccountButton()],
      body: body,
    );
  }

  @override
  void didUpdateWidget(covariant WorkspaceConversationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
  }

  Widget _body(String id) {
    ref.listen(workspaceShellProvider.select((state) => state.destination), (
      before,
      after,
    ) {
      if (before != after && after == WorkspaceShellDestination.conversations) {
        _reload();
      }
    });
    return ref
        .watch(workspaceConversationsProvider(id))
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const WorkspaceLoadingView(),
          error: (error, _) => WorkspaceErrorView(
            message: workspaceErrorMessage(error),
            onRetry: _reload,
          ),
          data: (rows) => _messageList(id, rows),
        );
  }

  List<WorkspaceConversationModel> _visibleRows(
    List<WorkspaceConversationModel> rows,
  ) {
    final query = _search.text.trim().toLowerCase();
    return rows
        .where(
          (row) =>
              row.group.displayTitle.toLowerCase().contains(query) ||
              row.previewText.toLowerCase().contains(query),
        )
        .toList()
      ..sort((a, b) {
        final time = b.serverTs.compareTo(a.serverTs);
        return time != 0 ? time : a.group.groupId.compareTo(b.group.groupId);
      });
  }

  Future<void> _refresh(String id) async {
    ref.invalidate(workspaceConversationsProvider(id));
    try {
      await ref.read(workspaceConversationsProvider(id).future);
    } catch (_) {
      /* The watched provider exposes the failure above. */
    }
  }

  Widget _messageList(String id, List<WorkspaceConversationModel> rows) {
    _scheduleExpiry(rows);
    final visible = _visibleRows(rows);
    return CustomScrollView(
      key: ValueKey('workspace-messages-$id'),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _refresh(id)),
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.allRegular,
            child: CupertinoSearchTextField(
              controller: _search,
              placeholder: t.common.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _emptyMessages()),
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (_, index) => _MessageRow(row: visible[index]),
        ),
      ],
    );
  }

  Widget _emptyMessages() => WorkspaceEmptyView(
    icon: CupertinoIcons.chat_bubble,
    title: _search.text.trim().isEmpty
        ? t.workspace.groupsEmptyTitle
        : t.common.searchNoResults,
    subtitle: _search.text.trim().isEmpty
        ? t.workspace.groupsEmptySubtitle
        : '',
  );
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.row});
  final WorkspaceConversationModel row;

  @override
  Widget build(BuildContext context) {
    final group = row.group;
    final preview = row.previewText;
    return CupertinoListTile.notched(
      key: ValueKey('workspace-message-${group.groupId}'),
      title: Text(
        group.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        preview.isEmpty
            ? t.workspace.groupTileSubtitle(count: group.memberCount.toString())
            : preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: BadgeWidget(
        key: ValueKey('workspace-unread-${group.groupId}'),
        showBadge: row.unreadCount > 0,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.iosRedDark
            : AppColors.iosRed,
        semanticLabel: context.t.common.unreadCount(
          count: '${row.unreadCount}',
        ),
        content: Text(
          row.unreadCount > 99 ? '99+' : '${row.unreadCount}',
          style: context.textStyle(
            FontSizeType.tiny,
            color: AppColors.onPrimary,
          ),
        ),
        child: CircleAvatar(
          backgroundImage: group.avatar.isEmpty
              ? null
              : avatarImageProvider(group.avatar),
          child: group.avatar.isEmpty
              ? const Icon(CupertinoIcons.person_2)
              : null,
        ),
      ),
      additionalInfo: row.serverTs > 0
          ? Text(DateTimeHelper.lastTimeFmt(row.serverTs))
          : null,
      onTap: () => context.push(
        '/chat/${group.groupId}',
        extra: {
          'type': 'C2G',
          'title': group.displayTitle,
          'avatar': group.avatar,
        },
      ),
    );
  }
}
