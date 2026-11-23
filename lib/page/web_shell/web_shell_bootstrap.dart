/// Phase 1.1.h.1 — WebShellPage i18n + 业务接线层
///
/// 解析 slang i18n 文案 + 注入业务 page widget，得到完整可消费的 Web Shell。
/// 是 Phase 1.1.i 路由集成时的目标 widget。
///
/// 设计要点：
/// - **复用现有 i18n key**：`t.chat.titleMessage` / `t.common.titleContact` / `t.channel.title`
///   / `t.main.titleMine` 全部是 BottomNavigationPage 已用的 key；welcomeTitle 用
///   运行时全局 `appName`（packageInfo），无需新增 yaml entry，避免与并行
///   i18n 工作撞车
/// - **业务 page 直接复用**：4 个 Tab 中栏内容用现有 [ConversationPage] / [ContactPage]
///   / [ChannelListPage] / [MinePage]，与 BottomNavigationPage 实例化方式一致
/// - **mobile fallback 复用 BottomNavigationPage**：< 900px 时无缝降级到移动端入口
/// - **Selection builder 用占位 widget**：真实 chat panel / contact detail panel
///   等业务 widget 是 Phase 2/3 的工作，本切片用 [_PlaceholderPanel] 占位，
///   后续切片逐个替换
/// - **无单元测试**：本 widget 是简单接线层，关键逻辑全在 [WebShellPage]（已 15
///   widget 测覆盖），集成正确性由 1.1.i 后浏览器烟雾测试 + E2E 验证（避免对
///   ConversationPage 等 ProviderScope 重链路做无价值 mock）
library;

import 'dart:async';

import 'package:imboy/store/api/group_member_api.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:imboy/page/chat_shell/personal_navigation_layout.dart';

import 'package:imboy/component/chat/message_scroll_provider.dart';

import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/account_local_task_registry.dart'
    show AccountLocalTaskOwner;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/common_events.dart'
    show ConversationAuthoritySyncEvent;
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/page/chat/chat/mixin/chat_event_subscription_manager.dart';
import 'package:imboy/page/chat/chat/utils/chat_page_utils.dart';
import 'package:imboy/page/chat/widget/chat_input.dart' show ChatInputState;

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show ImageMessage, FileMessage, Message, ChatOperation;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/component/chat/message.dart' show confirmOpenFile;
import 'package:imboy/theme/default/config/chat_theme_config.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

import 'web_message_content.dart';
import 'web_visible_message_read.dart';

import 'package:imboy/component/ui/cupertino_modal_surface.dart';

import 'package:imboy/config/init.dart' show appName;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/router/generated_product_feature_routes.dart';
import 'package:imboy/modules/messaging/public.dart' show MessagingFacade;
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/chat/widget/chat_history_status.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart'
    show PersonalHistorySyncOutcome, PersonalHistorySyncOutcomeKind;
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/workspace_shell/space_switcher_button.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/web_personal_history_sync.dart';

import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoView;

import 'web_chat_input.dart';
import 'web_chat_selection_guard.dart';
import 'web_reading_anchor_store.dart';
import 'web_chat_title_resolver.dart';
import 'web_message_actions.dart';
import 'web_shell.dart';
import 'web_shell_helper_panels.dart';
import 'web_group_info_panel.dart';
import 'web_group_composer_gate.dart';

import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';

import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

part 'web_chat_panel.dart';
part 'web_group_message_author.dart';
part 'web_chat_reading_restore.dart';

({bool enabled, double fraction, int delayMs})? _webReadPolicy(
  String currentUserId,
  UserModel? user,
) {
  final repo = UserRepoLocal.to;
  if (user == null ||
      user.uid != currentUserId ||
      repo.currentUid != user.uid ||
      !repo.hasCurrentProfileSettings) {
    return null;
  }
  try {
    final setting = UserProfileService.parseWebSettings(user.setting);
    return (
      enabled: setting['enable_visibility_read'] as bool,
      fraction: setting['visibility_read_fraction'] as double,
      delayMs: setting['visibility_read_delay_ms'] as int,
    );
  } on FormatException {
    return null;
  }
}

/// Keep the existing mobile navigation UI, projected from the route state only.
class _CanonicalWebMobileFallback extends ConsumerWidget {
  const _CanonicalWebMobileFallback({this.content});
  final Widget? content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Legacy and Native entries keep their original navigation owner.
    if (!kIsWeb || GoRouterState.of(context).uri.path != '/web_shell') {
      return const BottomNavigationPage();
    }
    ref.watch(featureRevisionProvider);
    final shell = ref.watch(webShellProvider);
    final owner = authSessionReader.current;
    final channelAvailable = personalChannelTabAvailable();
    final index = mobileIndexForPersonalTab(
      PersonalNavigationTab.values[shell.currentTab],
      channelAvailable: channelAvailable,
    );
    final tab = personalTabFromMobileIndex(
      index,
      channelAvailable: channelAvailable,
    );
    if (tab.index != shell.currentTab) {
      final session = authSessionReader.current;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted ||
            !authSessionReader.isCurrent(session) ||
            GoRouter.of(context).routeInformationProvider.value.uri.path !=
                '/web_shell' ||
            ref.read(webShellProvider) != shell ||
            personalChannelTabAvailable() != channelAvailable) {
          return;
        }
        ref.read(webShellProvider.notifier).switchTab(tab.index);
      });
    }
    return BottomNavigationPage(
      restoredIndex: index,
      content: content,
      onDestinationSelected: (next) {
        if (!context.mounted ||
            !authSessionReader.isCurrent(owner) ||
            personalChannelTabAvailable() != channelAvailable ||
            GoRouter.of(context).routeInformationProvider.value.uri.path !=
                '/web_shell') {
          return;
        }
        final selected = personalTabFromMobileIndex(
          next,
          channelAvailable: channelAvailable,
        );
        ref.read(webShellProvider.notifier).switchTab(selected.index);
      },
    );
  }
}

/// Web Shell 业务接线层（i18n + 业务 page 注入）
class WebShellBootstrap extends ConsumerWidget {
  const WebShellBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureRevisionProvider);
    final t = Translations.of(context);

    return WebShellPage(
      // i18n labels — 复用 BottomNavigationPage 已用 key（零新增）
      tabMessageLabel: t.chat.titleMessage,
      tabContactLabel: t.organization.directory.title,
      tabChannelLabel: t.channel.title,
      tabMineLabel: t.common.me,
      welcomeTitle: appName.isEmpty ? 'ImBoy' : appName,
      navigationLeading: const SpaceSwitcherButton(
        key: ValueKey('web-shell-space-switcher'),
        inRail: true,
      ),
      // welcomeSubtitle 暂不传：避免新增 i18n key（Phase 4 桌面增强时再补）

      // Tab 中栏内容 — 与 BottomNavigationPage._buildPageList() 顺序对齐
      messageTab: ConversationPage(
        leading: MediaQuery.sizeOf(context).width < AppBreakpoints.mobile
            ? const PersonalShellDrawerAvatarButton()
            : null,
      ),
      contactTab: ContactPage(),
      channelTab: compiledChannelListPage() ?? const SizedBox.shrink(),
      mineTab: MinePage(),

      // 2.6 Chat selection → 真实 ChatPanel
      // Phase 2.1.b-4 + b-6: 抽 WebChatPanel ConsumerStatefulWidget
      // - initState/didUpdateWidget 主动 initChatService + loadMoreMessages(isInitial)
      // - build 内 ref.watch chatProvider.messages 响应式更新
      // 真实 ChatInput 接入留待 Phase 2.1.c
      // 昵称解析（contact_repo）留待 2.1.d
      chatBuilder: (sel) => WebChatPanel(
        // ValueKey 触发不同 peer/type 时 Flutter 重建 State（确保 initState 重跑）
        key: ValueKey('${sel.chatType}:${sel.peerId}'),
        selection: sel,
        currentUserId: UserRepoLocal.to.currentUid,
        closeTooltip: t.common.cancel,
        onClose: () => ref.read(webShellProvider.notifier).clearSelection(),
        // Phase 2.1.c: 真实可输入 + 可发送的简化 Web 输入区
        // 仅文本，不含 ExtraItems / 录音 / 相机（留待后续切片按需扩展）
        inputArea: WebChatInput(
          selection: sel,
          currentUserId: UserRepoLocal.to.currentUid,
        ),
      ),
      // Phase 3.0: 真实联系人详情面板（avatar + title + sign + 发消息按钮）
      contactBuilder: (sel) => WebContactInfoPanel(
        key: ValueKey('contact:${sel.uid}'),
        selection: sel,
        sendButtonLabel: t.chat.sendMessage,
        closeTooltip: t.common.cancel,
        onClose: () => ref.read(webShellProvider.notifier).clearSelection(),
        onSendMessage: () {
          // 派发 ChatSelection → chatBuilder 渲染 WebChatPanel
          ref
              .read(webShellProvider.notifier)
              .openChat(ChatSelection(peerId: sel.uid, chatType: 'C2C'));
        },
      ),
      // TODO 广州第一期交付后实现：频道详情面板。Phase 2/3 前的占位面板
      // （PlaceholderPanel）不展示，选中频道时右栏留空；恢复时用下行替换：
      // channelBuilder: (sel) => PlaceholderPanel('Channel: ${sel.channelId}'),
      channelBuilder: (sel) => const SizedBox.shrink(),
      // Phase 3.2-min: 最小可用 Mine 面板（用户简介 + 登出）
      // 真实 Mine 子页面（设置 / 个人信息 / 收藏 等）留待 Phase 3.2.b 渐进接入
      mineBuilder: (sel) => WebMineMinPanel(
        section: sel.section,
        logoutLabel: t.common.buttonLogout,
      ),

      // mobile fallback — < 900px 时无缝复用移动端入口
      mobileFallback: const _CanonicalWebMobileFallback(),
      mobileFallbackBuilder: (content) =>
          _CanonicalWebMobileFallback(content: content),

      messageBadgeCount: ref.watch(
        conversationProvider.select((state) => state.chatMsgRemindCounter),
      ),
      contactBadgeCount: ref.watch(
        newFriendRemindProvider.select((requests) => requests.length),
      ),
      channelBadgeCount: AppFeatureRegistry.isEnabled(FeatureKeys.channel)
          ? compiledChannelUnreadCount(ref)
          : 0,
      // LAY-06：channel-off（feature 关或频道页未编译）时 rail 不渲染频道死入口。
      // featureRevisionProvider 已 watch → 远程开关翻转随 rebuild。
      channelTabAvailable: personalChannelTabAvailable(),
    );
  }
}

/// Phase 3.0 — Web Shell 联系人详情面板
///
/// 异步加载 ContactRepo.findByUid → 渲染 avatar / title / account / sign / region
/// + "发消息"按钮派发 ChatSelection。
///
/// 与 mobile [PeopleInfoPage] 的差异：
/// - 仅展示基础字段，不接入备注编辑 / 加好友 / 加入黑名单 / 删除等管理操作
/// - 不接入朋友圈/标签等扩展信息
/// - 这些留待后续切片（contactBuilder 渐进式增强）
class WebContactInfoPanel extends ConsumerStatefulWidget {
  final ContactSelection selection;
  final String sendButtonLabel;
  final String closeTooltip;
  final VoidCallback onClose;
  final VoidCallback onSendMessage;
  final AuthSessionReader? sessionReader;
  final Future<ContactModel?> Function(String)? contactLoader;

  const WebContactInfoPanel({
    super.key,
    required this.selection,
    required this.sendButtonLabel,
    required this.closeTooltip,
    required this.onClose,
    required this.onSendMessage,
    this.sessionReader,
    this.contactLoader,
  });

  @override
  ConsumerState<WebContactInfoPanel> createState() =>
      WebContactInfoPanelState();
}

class WebContactInfoPanelState extends ConsumerState<WebContactInfoPanel> {
  ContactModel? _contact;
  bool _loading = true;
  bool _failed = false;
  int _request = 0;
  AuthSessionScope? _owner;
  late final AuthSessionReader _sessions;

  bool get _active => _owner != null && _sessions.isCurrent(_owner!);

  void _onAuthChanged() {
    if (!mounted || _owner == _sessions.current) return;
    _request++;
    final sameUser = _owner?.uid == _sessions.current.uid;
    setState(() {
      _contact = null;
      _loading = true;
      _failed = false;
    });
    if (sameUser && !_sessions.current.transitioning) unawaited(_load());
  }

  @override
  void dispose() {
    _request++;
    _sessions.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessionReader ?? authSessionReader;
    _sessions.addListener(_onAuthChanged);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant WebContactInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection.uid != widget.selection.uid) {
      setState(() {
        _contact = null;
        _loading = true;
        _failed = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final selection = widget.selection;
    final owner = _sessions.current;
    _owner = owner;
    bool current() =>
        mounted &&
        request == _request &&
        selection == widget.selection &&
        _sessions.isCurrent(owner);
    if (!current()) return;
    try {
      final value =
          await (widget.contactLoader?.call(selection.uid) ??
              ContactRepo().findByUid(selection.uid));
      if (!current()) return;
      setState(() {
        _contact = value;
        _loading = false;
        _failed = false;
      });
    } on Object {
      if (!current()) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final c = _contact;
    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header：close 按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark, size: 22),
                  tooltip: widget.closeTooltip,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: colorScheme.outlineVariant,
          ),
          // 主体
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Translations.of(context)
                              .common
                              .operationFailedAgainLater,
                        ),
                        CupertinoButton(
                          onPressed: () {
                            if (!_active) return;
                            setState(() {
                              _loading = true;
                              _failed = false;
                            });
                            unawaited(_load());
                          },
                          child: Text(
                            Translations.of(context).common.buttonRetry,
                          ),
                        ),
                      ],
                    ),
                  )
                : c == null
                ? _buildUnsyncedBody(theme, colorScheme)
                : _buildContactBody(theme, colorScheme, c),
          ),
        ],
      ),
    );
  }

  /// Phase 3.0a — 联系人未同步容错：显示提示 + 仍允许"发消息"
  ///
  /// ContactRepo.findByUid 返回 null 通常发生在：
  /// - 联系人列表已显示该 uid 但本地 sqlite 还未同步该联系人详情
  /// - 跨端同步延迟（mobile 加好友 → web 端 contact 表还未推送）
  /// 不阻塞用户聊天意图：仍然提供"发消息"按钮（用 selection.uid 直接进 chat）
  Widget _buildUnsyncedBody(ThemeData theme, ColorScheme colorScheme) {
    final t = Translations.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.allXLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.cloud,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            AppSpacing.verticalRegular,
            Text(widget.selection.uid, style: theme.textTheme.titleMedium),
            AppSpacing.verticalSmall,
            Text(
              t.common.contactInfoNotSynced,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalXLarge,
            CupertinoButton(
              key: const ValueKey('web-contact-unsynced-send-msg-btn'),
              onPressed: () {
                if (_active) widget.onSendMessage();
              },
              minimumSize: const Size(200, 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.chat_bubble),
                  const SizedBox(width: 8),
                  Text(widget.sendButtonLabel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactBody(
    ThemeData theme,
    ColorScheme colorScheme,
    ContactModel c,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar 占位（不直接 import Avatar widget 避免拉额外依赖；
          // 后续切片可换 Avatar(url: c.avatar)）
          CircleAvatar(
            radius: 48,
            backgroundColor: colorScheme.primaryContainer,
            child: AvatarFallbackContent(
              name: c.title,
              color: colorScheme.onPrimaryContainer,
              iconSize: 42,
              textStyle: theme.textTheme.headlineMedium,
            ),
          ),
          AppSpacing.verticalRegular,
          Text(
            c.title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (c.account.isNotEmpty) ...[
            AppSpacing.verticalTiny,
            Text(
              c.account,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (c.region.isNotEmpty) ...[
            AppSpacing.verticalTiny,
            Text(
              c.region,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (c.sign.isNotEmpty) ...[
            AppSpacing.verticalRegular,
            Container(
              padding: AppSpacing.allMedium,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c.sign,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          AppSpacing.verticalXXLarge,
          // "发消息"按钮
          CupertinoButton(
            key: const ValueKey('web-contact-send-msg-btn'),
            onPressed: () {
              if (_active) widget.onSendMessage();
            },
            minimumSize: const Size(200, 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.chat_bubble),
                const SizedBox(width: 8),
                Text(widget.sendButtonLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
