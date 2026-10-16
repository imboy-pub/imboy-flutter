import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart' show RoundedCupertinoButton;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/badge_widget.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_avatar_cache.dart'
    show defaultGroupAvatarLoader;
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart'
    show WorkspaceGroupsStandalonePage;
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_account_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_message_filter.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Only server-authorized workspace snapshots; no personal or warm-cache rows.
class WorkspaceConversationsPage extends ConsumerStatefulWidget {
  const WorkspaceConversationsPage({
    super.key,
    this.embedded = false,
    this.active = true,
    this.filter = WorkspaceMessageFilter.all,
  });
  final bool embedded;
  final bool active;

  /// 消息筛选（企业壳消息 tab 的下拉菜单，见 workspace_message_filter）。
  /// 快照无对应字段的筛选项按「无匹配」空态展示。
  final WorkspaceMessageFilter filter;
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
      _reload();
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
    bool matchesFilter(WorkspaceConversationModel row) =>
        switch (widget.filter) {
          WorkspaceMessageFilter.all => true,
          // 快照只有群维度行；快照无字段支撑的筛选项一律无匹配（空态展示，
          // 待服务端补 mention/内外部/标记/单聊字段后逐项点亮）。
          WorkspaceMessageFilter.unread => row.unreadCount > 0,
          WorkspaceMessageFilter.group => true,
          _ => false,
        };
    return rows
        .where(
          (row) =>
              matchesFilter(row) &&
              (row.group.displayTitle.toLowerCase().contains(query) ||
                  row.previewText.toLowerCase().contains(query)),
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
          itemBuilder: (_, index) {
            final brightness = Theme.of(context).brightness;
            return Column(
              children: [
                _MessageRow(row: visible[index]),
                // 分隔线：左 16(页面 padding) + 56(头像) + 12(间距) = 84，
                // 与文字左缘对齐（同 Personal 会话列表，DESIGN.md 8.3 A）；
                // 末行不画——多一条线会让列表看起来"还没到底"。
                if (index < visible.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 84),
                    child: Divider(
                      height: 0.5,
                      color: AppColors.getIosSeparator(brightness)
                          .withValues(alpha: 0.3),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _emptyMessages() {
    final searching = _search.text.trim().isNotEmpty;
    final filtered = widget.filter != WorkspaceMessageFilter.all;
    if (searching || filtered) {
      // 「未读」空态单独措辞：明确反馈筛选生效只是没有未读（2026-10-16
      // 用户反馈 R2c：通用空态让筛选显得不可用）。
      final unreadOnly =
          !searching && widget.filter == WorkspaceMessageFilter.unread;
      return WorkspaceEmptyView(
        icon: CupertinoIcons.chat_bubble,
        title: searching
            ? t.common.searchNoResults
            : unreadOnly
            ? t.workspace.filterUnreadEmptyTitle
            : t.workspace.filterEmptyTitle,
        subtitle: '',
      );
    }
    return WorkspaceEmptyView(
      icon: CupertinoIcons.chat_bubble,
      title: searching
          ? t.common.searchNoResults
          : t.workspace.groupsEmptyTitle,
      subtitle: searching ? '' : t.workspace.groupsEmptySubtitle,
      // 空态引导动作（企微/飞书惯例）：列表为空时给出下一步去向；
      // 搜索无结果时不需要。按钮走项目统一的 RoundedCupertinoButton
      // 次级样式（brand 描边），不用 Material tonal（DESIGN.md 8.4）。
      // 目标限定本工作区群组（T5 双体验：群 scope=workspace）——发现
      // 语义按模式分区：个人模式才暴露平台公开群发现页（/group/discover）。
      actions: searching
          ? const []
          : [
              RoundedCupertinoButton(
                text: t.workspace.navGroups,
                highlighted: false,
                icon: CupertinoIcons.person_2,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const WorkspaceGroupsStandalonePage(),
                  ),
                ),
              ),
            ],
    );
  }
}

class _MessageRow extends StatefulWidget {
  const _MessageRow({required this.row});
  final WorkspaceConversationModel row;

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

/// 视觉规格与 Personal 会话行 [ConversationItem] 逐项对齐（56 群拼图
/// 头像 + 未读徽标同位、标题 body w600 letterSpacing -0.4、时间戳
/// footnote tabularFigures、预览 subheadline 灰、按压 100ms 高光），
/// 但不与 Personal 模型/provider 耦合——见该文件头注释的取舍说明。
class _MessageRowState extends State<_MessageRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.row.group;
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = widget.row.previewText.isEmpty
        ? t.workspace.groupTileSubtitle(count: group.memberCount.toString())
        : widget.row.previewText;
    return GestureDetector(
      onTap: () => context.push(
        '/chat/${group.groupId}',
        extra: {
          'type': 'C2G',
          'title': group.displayTitle,
          'avatar': group.avatar,
        },
      ),
      // 不触发 HapticFeedback：iOS 系统列表按下不给触感（同 ConversationItem）。
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        // DESIGN.md 6.4：Cell 按压反馈 100ms
        duration: AppDuration.buttonPress,
        key: ValueKey('workspace-message-${group.groupId}'),
        color: _isPressed
            ? (isDark ? AppColors.overlayWhite10 : AppColors.overlayBlack5)
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 头像区域 + 未读角标（位置/字号/颜色与 ConversationItem 相同）
            BadgeWidget(
              key: ValueKey('workspace-unread-${group.groupId}'),
              showBadge: widget.row.unreadCount > 0,
              semanticLabel: t.common.unreadCount(
                count: '${widget.row.unreadCount}',
              ),
              content: Text(
                widget.row.unreadCount > 99
                    ? '99+'
                    : '${widget.row.unreadCount}',
                style: context
                    .textStyle(
                      FontSizeType.caption2,
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    )
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              color: AppColors.iosRed,
              padding: const EdgeInsets.all(5),
              top: -4,
              left: -4,
              right: null,
              child: SmartGroupAvatar(
                avatar: group.avatar,
                groupId: group.groupId.toString(),
                size: 56,
                avatarLoader: defaultGroupAvatarLoader,
                heroTag: 'avatar_${group.groupId}',
              ),
            ),
            // 12pt：分隔线按 16(左padding)+56(头像)+12 = 84 起画（列表层）
            AppSpacing.horizontalMedium,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          group.displayTitle,
                          style: context
                              .textStyle(
                                FontSizeType.body,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              )
                              .copyWith(letterSpacing: -0.4),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 不画 disclosure chevron：整行可点（同 ConversationItem /
                      // 微信 / Telegram 的会话列表）。
                      if (widget.row.serverTs > 0)
                        Text(
                          DateTimeHelper.lastTimeFmt(widget.row.serverTs),
                          style: context
                              .textStyle(
                                FontSizeType.footnote,
                                color: AppColors.iosGray,
                                fontWeight: FontWeight.w400,
                              )
                              .copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                    ],
                  ),
                  AppSpacing.verticalTiny,
                  Text(
                    preview,
                    style: context
                        .textStyle(
                          FontSizeType.subheadline,
                          color: AppColors.iosGray,
                        )
                        .copyWith(height: 1.3, letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
