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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show Message, TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/init.dart' show appName;
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/channel_content/public.dart';
import 'package:imboy/modules/messaging/public.dart' show MessagingFacade;
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'web_chat_title_resolver.dart';
import 'web_message_actions.dart';
import 'web_shell.dart';

/// Web Shell 业务接线层（i18n + 业务 page 注入）
class WebShellBootstrap extends ConsumerWidget {
  const WebShellBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);

    return WebShellPage(
      // i18n labels — 复用 BottomNavigationPage 已用 key（零新增）
      tabMessageLabel: t.chat.titleMessage,
      tabContactLabel: t.common.titleContact,
      tabChannelLabel: t.channel.title,
      tabMineLabel: t.main.titleMine,
      welcomeTitle: appName.isEmpty ? 'ImBoy' : appName,
      // welcomeSubtitle 暂不传：避免新增 i18n key（Phase 4 桌面增强时再补）

      // Tab 中栏内容 — 与 BottomNavigationPage._buildPageList() 顺序对齐
      messageTab: const ConversationPage(),
      contactTab: ContactPage(),
      channelTab: const ChannelListPage(),
      mineTab: MinePage(),

      // 2.6 Chat selection → 真实 ChatPanel
      // Phase 2.1.b-4 + b-6: 抽 _WebChatPanel ConsumerStatefulWidget
      // - initState/didUpdateWidget 主动 initChatService + loadMoreMessages(isInitial)
      // - build 内 ref.watch chatProvider.messages 响应式更新
      // 真实 ChatInput 接入留待 Phase 2.1.c
      // 昵称解析（contact_repo）留待 2.1.d
      chatBuilder: (sel) => _WebChatPanel(
        // ValueKey 触发不同 peer/type 时 Flutter 重建 State（确保 initState 重跑）
        key: ValueKey('${sel.chatType}:${sel.peerId}'),
        selection: sel,
        currentUserId: UserRepoLocal.to.currentUid,
        closeTooltip: t.common.cancel,
        onClose: () => ref.read(webShellProvider.notifier).clearSelection(),
        // Phase 2.1.c: 真实可输入 + 可发送的简化 Web 输入区
        // 仅文本，不含 ExtraItems / 录音 / 相机（留待后续切片按需扩展）
        inputArea: _WebChatInput(
          selection: sel,
          currentUserId: UserRepoLocal.to.currentUid,
        ),
      ),
      // Phase 3.0: 真实联系人详情面板（avatar + title + sign + 发消息按钮）
      contactBuilder: (sel) => _WebContactInfoPanel(
        key: ValueKey('contact:${sel.uid}'),
        selection: sel,
        sendButtonLabel: t.chat.sendMessage,
        closeTooltip: t.common.cancel,
        onClose: () => ref.read(webShellProvider.notifier).clearSelection(),
        onSendMessage: () {
          // 派发 ChatSelection → chatBuilder 渲染 _WebChatPanel
          ref
              .read(webShellProvider.notifier)
              .selectItem(ChatSelection(peerId: sel.uid, chatType: 'C2C'));
        },
      ),
      channelBuilder: (sel) => _PlaceholderPanel('Channel: ${sel.channelId}'),
      // Phase 3.2-min: 最小可用 Mine 面板（用户简介 + 登出）
      // 真实 Mine 子页面（设置 / 个人信息 / 收藏 等）留待 Phase 3.2.b 渐进接入
      mineBuilder: (sel) => _WebMineMinPanel(
        section: sel.section,
        logoutLabel: t.common.buttonLogout,
      ),

      // mobile fallback — < 900px 时无缝复用移动端入口
      mobileFallback: const BottomNavigationPage(),

      // Badge counts — 暂不接入 provider（Phase 1.1.h.1.b 时再 ref.watch
      // unreadMessageCountProvider 等真实数据源）
    );
  }
}

/// Phase 2.1.b-6 — Web Shell 内嵌聊天面板（主动加载 + 响应式刷新）
///
/// initState / didUpdateWidget：
/// - chat_provider.notifier.initChatService(chatType) 创建/复用 SqliteChatService
/// - ConversationRepo.findByPeerId 查找对应会话；找到则 loadMoreMessages(isInitial:true)
/// - 找不到会话（如联系人长按未聊过）→ 不创建会话记录，messages 留空
///
/// build：
/// - ref.watch(chatProvider.select((s) => s.messages)) 响应式拿到消息
class _WebChatPanel extends ConsumerStatefulWidget {
  final ChatSelection selection;
  final String currentUserId;
  final String closeTooltip;
  final VoidCallback onClose;
  final Widget inputArea;

  const _WebChatPanel({
    super.key,
    required this.selection,
    required this.currentUserId,
    required this.closeTooltip,
    required this.onClose,
    required this.inputArea,
  });

  @override
  ConsumerState<_WebChatPanel> createState() => _WebChatPanelState();
}

class _WebChatPanelState extends ConsumerState<_WebChatPanel> {
  // Phase 2.1.d 异步解析的 peer 元数据（contact 或 group），决策标题用
  ContactModel? _resolvedContact;
  GroupModel? _resolvedGroup;

  @override
  void initState() {
    super.initState();
    _activate();
  }

  @override
  void didUpdateWidget(covariant _WebChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selChanged =
        oldWidget.selection.peerId != widget.selection.peerId ||
        oldWidget.selection.chatType != widget.selection.chatType;
    if (selChanged) {
      // 切 peer 时清空旧元数据，避免显示上一会话的标题
      setState(() {
        _resolvedContact = null;
        _resolvedGroup = null;
      });
      _activate();
    }
  }

  /// 主动激活：init service + 加载初始消息 + 解析 peer 标题元数据
  /// （推迟到 post-frame 避免 build 期 mutate）
  Future<void> _activate() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final notifier = ref.read(chatProvider.notifier);
    notifier.initChatService(widget.selection.chatType);

    // 并行：加载消息 + 解析 peer title
    final conv = await ConversationRepo().findByPeerId(
      widget.selection.chatType,
      widget.selection.peerId,
    );
    if (!mounted) return;
    if (conv != null) {
      await notifier.loadMoreMessages(conv, isInitial: true);
      if (!mounted) return;
    }

    // 解析 peer 标题元数据（按 chatType 分发）
    await _resolvePeerTitle();
  }

  Future<void> _resolvePeerTitle() async {
    switch (widget.selection.chatType) {
      case 'C2C':
        final c = await ContactRepo().findByUid(widget.selection.peerId);
        if (!mounted) return;
        setState(() => _resolvedContact = c);
      case 'C2G':
        final g = await GroupRepo().findById(widget.selection.peerId);
        if (!mounted) return;
        setState(() => _resolvedGroup = g);
      default:
        // 未知 chatType：保持 _resolvedContact/_resolvedGroup 为 null → fallback peerId
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider.select((s) => s.messages));
    final title = pickChatTitle(
      chatType: widget.selection.chatType,
      peerId: widget.selection.peerId,
      contactTitle: _resolvedContact?.title,
      groupTitle: _resolvedGroup?.title,
    );
    return ChatPanel(
      peerId: widget.selection.peerId,
      chatType: widget.selection.chatType,
      title: title,
      closeTooltip: widget.closeTooltip,
      onClose: widget.onClose,
      messages: messages,
      currentUserId: widget.currentUserId,
      onMessageLongPress: _handleLongPress,
      onMessageDoubleTap: (_) {
        // TODO Phase 2.1.b-5b 接双击放大（图片/视频）
      },
      inputArea: widget.inputArea,
    );
  }

  /// Phase 2.1.b-5a/c — 长按消息：弹底部菜单
  ///
  /// 当前菜单项（按可见性条件）：
  /// - 复制（resolveCopyableText 非 null 时）— 真实写入 Clipboard
  /// - 撤回（canShowRecallAction true 时，即自己发的 + 时间窗内）— TODO 调
  ///   MessageActionHandler.revokeMessage（本切片仅占位 toast，下次切片接 handler）
  /// - 取消
  ///
  /// 后续切片可扩展：转发 / 收藏 / 删除 / 引用回复。
  void _handleLongPress(Message message) {
    final copyable = resolveCopyableText(message);
    final canRecall = canShowRecallAction(
      message: message,
      currentUserId: widget.currentUserId,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );

    // 没有任何可操作项时不弹菜单（避免空白菜单困惑用户）
    if (copyable == null && !canRecall) return;

    final ctx = context;
    final t = Translations.of(ctx);
    showModalBottomSheet<void>(
      context: ctx,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (copyable != null)
                ListTile(
                  key: const ValueKey('web-msg-action-copy'),
                  leading: const Icon(Icons.copy),
                  title: Text(t.common.buttonCopy),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await Clipboard.setData(ClipboardData(text: copyable));
                    if (!mounted) return;
                    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                      SnackBar(
                        content: Text(t.main.copied),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              if (canRecall)
                ListTile(
                  key: const ValueKey('web-msg-action-recall'),
                  leading: const Icon(Icons.replay),
                  title: Text(t.chat.revoke),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _revokeMessage(message);
                  },
                ),
              ListTile(
                key: const ValueKey('web-msg-action-cancel'),
                leading: const Icon(Icons.close),
                title: Text(t.common.cancel),
                onTap: () => Navigator.of(sheetCtx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Phase 2.1.b-5d — 撤回消息（接 MessagingFacade.sendRevokeMessage）
  ///
  /// 决策已由 [canShowRecallAction] 在菜单显示前过滤；本方法假设入参可撤回。
  /// 失败时仅 SnackBar 提示，不抛异常给上层（避免 widget tree unhandled future）。
  Future<void> _revokeMessage(Message message) async {
    final ctx = context;
    final t = Translations.of(ctx);
    try {
      final ok = await MessagingFacade.instance.sendRevokeMessage(
        message.id,
        widget.selection.chatType,
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          content: Text(ok ? t.common.revokeSuccess : t.common.revokeFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          content: Text('${t.common.revokeFailed}: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Phase 2.1.c — Web 简化输入区（文本可输入 + 发送）
///
/// 与 mobile [ChatInput] 的差异：
/// - 仅文本输入，无 ExtraItems（图片/文件/录音/相机/地点等）
/// - 无 typing indicator / 无 quote / 无 mentions UI
/// - 无 composerHeightNotifier 联动（Web Shell 三栏布局不需要动态高度）
///
/// 沿用 mobile chat_page._addMessage 模式：
/// - chatProvider.notifier.addMessage(...) 写入会话 + 触发后端发送
/// - chatProvider.notifier.chatService?.insertMessage(...) 插入到内存消息列表
/// - 后续 syncMessagesToState 自动触发 ChatPanel 重建
class _WebChatInput extends ConsumerStatefulWidget {
  final ChatSelection selection;
  final String currentUserId;

  const _WebChatInput({required this.selection, required this.currentUserId});

  @override
  ConsumerState<_WebChatInput> createState() => _WebChatInputState();
}

class _WebChatInputState extends ConsumerState<_WebChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || widget.currentUserId.isEmpty) return;

    setState(() => _sending = true);
    try {
      final notifier = ref.read(chatProvider.notifier);
      final textMessage = TextMessage(
        authorId: widget.currentUserId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
        id: Xid().toString(),
        text: text,
        metadata: {'peer_id': widget.selection.peerId},
      );

      await notifier.addMessage(
        widget.currentUserId,
        widget.selection.peerId,
        '', // peerAvatar 暂空，TODO Phase 2.1.d 接 contact_repo 解析
        widget.selection.peerId, // peerTitle 暂用 peerId
        widget.selection.chatType,
        textMessage,
      );
      await notifier.chatService?.insertMessage(
        textMessage,
        index: notifier.chatService?.messages.length ?? 0,
        animated: true,
      );

      if (mounted) _controller.clear();
    } catch (e) {
      debugPrint('[web_shell_bootstrap] clear error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canSend = !_sending && widget.currentUserId.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('web-chat-input-field'),
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Send message',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('web-chat-input-send-btn'),
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            tooltip: 'Send',
            onPressed: canSend ? _send : null,
            color: canSend ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ],
      ),
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
class _WebContactInfoPanel extends ConsumerStatefulWidget {
  final ContactSelection selection;
  final String sendButtonLabel;
  final String closeTooltip;
  final VoidCallback onClose;
  final VoidCallback onSendMessage;

  const _WebContactInfoPanel({
    super.key,
    required this.selection,
    required this.sendButtonLabel,
    required this.closeTooltip,
    required this.onClose,
    required this.onSendMessage,
  });

  @override
  ConsumerState<_WebContactInfoPanel> createState() =>
      _WebContactInfoPanelState();
}

class _WebContactInfoPanelState extends ConsumerState<_WebContactInfoPanel> {
  ContactModel? _contact;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _WebContactInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection.uid != widget.selection.uid) {
      setState(() {
        _contact = null;
        _loading = true;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final c = await ContactRepo().findByUid(widget.selection.uid);
    if (!mounted) return;
    setState(() {
      _contact = c;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  icon: const Icon(Icons.close),
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
                ? const Center(child: CircularProgressIndicator())
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(widget.selection.uid, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              t.common.contactInfoNotSynced,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const ValueKey('web-contact-unsynced-send-msg-btn'),
              onPressed: widget.onSendMessage,
              icon: const Icon(Icons.message_outlined),
              label: Text(widget.sendButtonLabel),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 44)),
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
            child: Text(
              c.title.isNotEmpty ? c.title.characters.first : '?',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            c.title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (c.account.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              c.account,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (c.region.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              c.region,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (c.sign.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 32),
          // "发消息"按钮
          ElevatedButton.icon(
            key: const ValueKey('web-contact-send-msg-btn'),
            onPressed: widget.onSendMessage,
            icon: const Icon(Icons.message_outlined),
            label: Text(widget.sendButtonLabel),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 44)),
          ),
        ],
      ),
    );
  }
}

/// Phase 3.2-min — Web Shell Mine Tab 最小面板
///
/// 当前展示：当前用户 uid + 登出按钮。Phase 3.2.b 之后渐进接入：
/// - 头像 / 昵称 / 签名 / 二维码（接 UserRepoLocal.current）
/// - 设置子项（消息通知 / 主题 / 语言 / 安全 / 关于）→ section 路由分发
class _WebMineMinPanel extends ConsumerWidget {
  final String? section;
  final String logoutLabel;

  const _WebMineMinPanel({required this.section, required this.logoutLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final t = Translations.of(context);
    final uid = UserRepoLocal.to.currentUid;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            uid.isEmpty ? t.common.notLoggedIn : 'UID: $uid',
            style: theme.textTheme.titleMedium,
          ),
          if (section != null) ...[
            const SizedBox(height: 8),
            Text(
              'section: $section',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('web-mine-logout-btn'),
            onPressed: uid.isEmpty
                ? null
                : () async {
                    final ok = await UserRepoLocal.to.quitLogin();
                    if (!context.mounted) return;
                    if (ok) {
                      // 跳到登录页（路由守卫会在 isLoggedIn=false 时也会拦截，
                      // 但显式跳转更可靠）
                      context.go(AppRoutes.signIn);
                    } else {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text(t.common.logoutFailed),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.logout),
            label: Text(logoutLabel),
            style: OutlinedButton.styleFrom(minimumSize: const Size(180, 44)),
          ),
        ],
      ),
    );
  }
}

/// Phase 2/3 实施真实 panel 前的占位 widget
class _PlaceholderPanel extends StatelessWidget {
  final String label;

  const _PlaceholderPanel(this.label);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TODO Phase 2/3',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
