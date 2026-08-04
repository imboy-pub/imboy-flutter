import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/conversation/conversation_tap_dispatcher.dart';
import 'package:imboy/page/conversation/widget/subscribed_channel_strip.dart';
import 'package:imboy/page/conversation/widget/right_button.dart'
    show RightButton;
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/websocket_events.dart'
    show WebSocketStatusChangedEvent;
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'conversation_provider.dart';
import 'widget/conversation_item.dart';

/// 会话点击是否应派发到 Web Shell 右栏：仅当当前页面挂载于 `/web_shell`
/// 路由下时，[webShellProvider] 才有消费者（[WebShellPage] 三栏布局会
/// `ref.watch` 它）。挂载于 `/bottom_navigation` 等其它宿主时该 provider
/// 无人消费，派发 [WebSelectChat] 会导致点击后"什么都不发生"，必须走
/// Mobile push 兜底。
bool _isWebShellHosted(BuildContext context) {
  try {
    return GoRouterState.of(context).matchedLocation.startsWith('/web_shell');
  } on GoError {
    return false;
  }
}

/// 会话列表页面 - iOS 17 Premium 风格
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  StreamSubscription<dynamic>? ssMsg;
  StreamSubscription<dynamic>? ssExtend;

  StreamSubscription<dynamic>? _localeSubscription;
  StreamSubscription<dynamic>? _connectivitySubscription;
  StreamSubscription<dynamic>? _websocketStatusSubscription;
  StreamSubscription<dynamic>? _authoritySyncSub;

  /// 是否需在列表顶部常驻显示 E2EE 密钥恢复横幅（换设备/重装后未完成恢复）。
  bool _e2eeRecoveryNeeded = false;

  /// 会话搜索控制器与当前 query（已 trim + 小写）。空串表示未过滤。
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  void _onSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() => _searchQuery = q);
  }

  @override
  void initState() {
    super.initState();
    _e2eeRecoveryNeeded =
        StorageService.to.getBool(kE2eeRecoveryNeededKey) ?? false;
    unawaited(initData());

    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) async {
      if (!mounted) return;
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        ref
            .read(conversationProvider.notifier)
            .setConnectDesc(
              t.common.tipConnectDescWithParen(param: t.common.tipConnectDesc),
            );
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    ssMsg?.cancel();
    ssExtend?.cancel();
    _localeSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _websocketStatusSubscription?.cancel();
    _authoritySyncSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> initData() async {
    final notifier = ref.read(conversationProvider.notifier);
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      notifier.setConnectDesc(
        t.common.tipConnectDescWithParen(param: t.common.tipConnectDesc),
      );
    } else {
      notifier.setConnectDesc('');
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> r,
    ) {
      if (!mounted) return;
      if (r.contains(ConnectivityResult.none)) {
        notifier.setConnectDesc(
          t.common.tipConnectDescWithParen(param: t.common.tipConnectDesc),
        );
      } else {
        notifier.setConnectDesc('');
      }
    });

    _websocketStatusSubscription = AppEventBus.on<WebSocketStatusChangedEvent>()
        .listen((event) {
          if (!mounted) return;
          if (event.status.toLowerCase() != 'connected') return;
          unawaited(
            notifier.syncAuthoritativeConversationList(
              trigger: 'websocket_connected',
            ),
          );
        });

    // 下拉刷新等服务端权威拉取失败时给出可见反馈（仅 pull_to_refresh 触发，
    // page_init / websocket_connected 的失败不弹 toast，避免应用启动期噪音）。
    _authoritySyncSub = AppEventBus.on<ConversationAuthoritySyncEvent>().listen(
      (event) {
        if (!mounted) return;
        if (!event.success && event.trigger == 'pull_to_refresh') {
          AppLoading.showError(t.common.errorNetwork);
        }
      },
    );

    ssMsg = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((event) async {
      if (!mounted) return;
      if (event.data is ConversationModel) {
        final obj = event.data as ConversationModel;
        obj.title = await notifier.computeTitle(obj);
        await notifier.replace(obj);
      }
    });

    ssExtend = AppEventBus.on<ChatExtendEvent>().listen((event) async {
      if (!mounted) return;
      if (event.type == 'refresh_conversations' || event.type == 'clean_msg') {
        if (event.payload['conversation'] is ConversationModel) {
          final updatedConv =
              event.payload['conversation'] as ConversationModel;
          if (updatedConv.id > 0) {
            await notifier.replace(updatedConv);
            return;
          }
        }
        final uk3 = event.payload['uk3'] as String?;
        if (uk3 != null && uk3.isNotEmpty) {
          final parts = uk3.split('_');
          if (parts.length >= 3) {
            final updatedConv = await ConversationRepo().findByPeerId(
              parts[0],
              parts.sublist(1).join('_'),
            );
            if (updatedConv != null && updatedConv.id > 0) {
              await notifier.replace(updatedConv);
            }
          }
        }
      }
    });

    final state = ref.read(conversationProvider);
    if (state.conversationMap.isEmpty) {
      await notifier.syncAuthoritativeConversationList(trigger: 'page_init');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider);
    final notifier = ref.read(conversationProvider.notifier);
    final t = context.t;
    final brightness = Theme.of(context).brightness;

    // 本地过滤已加载会话（标题 + 预览文本）；不触网、不另造数据源。
    final all = state.conversations;
    final filtered = _searchQuery.isEmpty
        ? all
        : all
              .where(
                // 按 displayTitle 搜而非 raw title：raw title 里可能存着
                // 存量脏值（peerId 本身），那样「搜屏幕上看得见的名字搜不到、
                // 搜一串谁也不会输入的 TSID 反而能搜到」。
                (c) =>
                    c.displayTitle.toLowerCase().contains(_searchQuery) ||
                    c.subtitle.toLowerCase().contains(_searchQuery),
              )
              .toList();

    return IosPageTemplate(
      title: t.chat.titleMessage,
      actions: [
        Padding(
          padding: EdgeInsets.only(right: AppSpacing.small),
          child: RightButton(),
        ),
      ],
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => notifier.syncAuthoritativeConversationList(
            trigger: 'pull_to_refresh',
          ),
        ),
        // 搜索框 - 嵌入 List 顶部
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.small,
              AppSpacing.regular,
              AppSpacing.medium,
            ),
            child: CupertinoSearchTextField(
              key: const Key('conversation_search_input'),
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              placeholder: t.common.search,
              backgroundColor: AppColors.getSurfaceGrouped(
                brightness,
                isOLEDMode: true,
              ),
            ),
          ),
        ),

        if (_e2eeRecoveryNeeded)
          SliverToBoxAdapter(
            child: E2EERecoveryBanner(
              onDismiss: () {
                unawaited(
                  StorageService.to.setBool(kE2eeRecoveryNeededKey, false),
                );
                setState(() => _e2eeRecoveryNeeded = false);
              },
            ),
          ),

        if (state.connectDesc.isNotEmpty)
          SliverToBoxAdapter(child: NetworkFailureTips()),

        if (AppFeatureRegistry.isEnabled(FeatureKeys.channel))
          const SliverToBoxAdapter(child: SubscribedChannelStrip()),

        if (state.isLoading)
          const SliverFillRemaining(child: ShimmerList())
        else if (all.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: NoDataView(text: t.common.noConversationMessages),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: NoDataView(text: t.common.searchNoResults),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.large),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final model = filtered[index];
                // 侧滑三个操作抽成闭包：既给 SlidableAction 用，也挂到
                // Semantics.customSemanticsActions 上。读屏用户做不出侧滑手势，
                // 不挂的话「已读 / 置顶 / 删除」对他们完全不可达。
                final markReadLabel = model.unreadNum > 0
                    ? t.chat.markRead
                    : t.chat.markUnread;
                final pinLabel = model.isPinned ? t.chat.unpin : t.chat.pin;

                Future<void> onToggleRead() async {
                  final target = model.unreadNum > 0 ? 0 : 1;
                  if (model.unreadNum > 0) {
                    try {
                      final db = await SqliteService.to.db;
                      if (db != null) {
                        final tb = MessageRepo.getTableName(model.type);
                        await db.update(
                          tb,
                          {MessageRepo.status: IMBoyMessageStatus.seen},
                          where:
                              "${MessageRepo.conversationUk3} = ? and ${MessageRepo.status} = ? and ${MessageRepo.isAuthor} = ?",
                          whereArgs: [
                            model.uk3,
                            IMBoyMessageStatus.delivered,
                            0,
                          ],
                        );
                      }
                    } catch (_) {}
                    await notifier.advanceWatermarkToLatest(model);
                    await notifier.setConversationRemind(model, 0);
                  } else {
                    await notifier.setConversationRemind(model, 1);
                  }
                  notifier.applyConversationSnapshot(
                    model.copyWith(unreadNum: target),
                  );
                }

                Future<void> onTogglePin(BuildContext ctx) async {
                  // 补反馈：原来忽略返回值、成功失败都无提示（QA#30）
                  final willPin = !model.isPinned;
                  final ok = await notifier.setConversationPinned(
                    model,
                    willPin,
                  );
                  if (!ctx.mounted) return;
                  if (ok) {
                    AppLoading.showToast(
                      willPin
                          ? t.common.chatSettingPinnedSuccess
                          : t.common.chatSettingUnpinnedSuccess,
                    );
                  } else {
                    AppLoading.showError(t.common.errorNetwork);
                  }
                }

                Future<void> onDelete() =>
                    notifier.deleteConversationRemote(model);

                return Column(
                  children: [
                    Slidable(
                      key: ValueKey(model.id),
                      groupTag: '0',
                      endActionPane: ActionPane(
                        extentRatio: 0.65,
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => onToggleRead(),
                            backgroundColor: AppColors.getIosBlue(brightness),
                            foregroundColor: AppColors.onPrimary,
                            label: markReadLabel,
                            icon: model.unreadNum > 0
                                ? CupertinoIcons.chat_bubble
                                : CupertinoIcons.chat_bubble_fill,
                          ),
                          SlidableAction(
                            onPressed: (ctx) => onTogglePin(ctx),
                            backgroundColor: AppColors.iosOrange,
                            foregroundColor: AppColors.onPrimary,
                            label: pinLabel,
                            icon: model.isPinned
                                ? CupertinoIcons.pin_slash_fill
                                : CupertinoIcons.pin_fill,
                          ),
                          SlidableAction(
                            onPressed: (_) => onDelete(),
                            backgroundColor: AppColors.getIosRed(brightness),
                            foregroundColor: AppColors.onPrimary,
                            label: t.common.buttonDelete,
                            icon: CupertinoIcons.delete_solid,
                          ),
                        ],
                      ),
                      // 把侧滑操作暴露给读屏：VoiceOver / TalkBack 用户做不出
                      // 侧滑手势，不挂 customSemanticsActions 的话
                      // 「已读 / 置顶 / 删除」三个操作对他们完全不可达。
                      // 挂上后可从读屏的「操作」菜单里选。
                      child: Builder(
                        builder: (rowContext) => Semantics(
                          customSemanticsActions:
                              <CustomSemanticsAction, VoidCallback>{
                                CustomSemanticsAction(
                                  label: markReadLabel,
                                ): () =>
                                    unawaited(onToggleRead()),
                                CustomSemanticsAction(label: pinLabel): () =>
                                    unawaited(onTogglePin(rowContext)),
                                CustomSemanticsAction(
                                  label: t.common.buttonDelete,
                                ): () =>
                                    unawaited(onDelete()),
                              },
                          child: ConversationItem(
                            model: model,
                            onTap: () {
                              final useSplitView =
                                  _isWebShellHosted(context) &&
                                  AppBreakpoints.isWide(
                                    MediaQuery.sizeOf(context).width,
                                  );
                              final action = resolveConversationTap(
                                useSplitView: useSplitView,
                                peerId: model.peerId.toString(),
                                type: model.type,
                                // 传 resolvedTitle 而非 raw title：
                                // 存量脏 title 里存的就是 peerId，原样传下去
                                // 聊天页就把 TSID 显示给用户（批次 14 实测）。
                                // 也不能传 displayTitle —— 兜底后的「未命名」
                                // 会堵死聊天页继续查群名/成员名的那条链。
                                title: model.resolvedTitle,
                                avatar: model.avatar,
                                sign: model.sign,
                              );
                              if (action is WebSelectChat) {
                                ref
                                    .read(webShellProvider.notifier)
                                    .selectItem(
                                      ChatSelection(
                                        peerId: action.peerId,
                                        chatType: action.chatType,
                                      ),
                                    );
                              } else if (action is MobilePushChat) {
                                context.push(
                                  '/chat/${action.peerId}',
                                  extra: {
                                    'type': action.chatType,
                                    'title': action.title,
                                    'avatar': action.avatar,
                                    'sign': action.sign,
                                  },
                                );
                              }
                            },
                            onTapAvatar: () => context.push(
                              '/contact/people/${model.peerId}',
                              extra: {'scene': ''},
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 分隔线：左 16(页面 padding) + 56(头像) + 12(头像后间距) = 84，
                    // 与文字左缘对齐（DESIGN.md 8.3 A）。
                    // 末行不画——iOS 列表最后一行下面是空白，多一条线会让列表
                    // 看起来"还没到底"。
                    if (index < filtered.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 84),
                        child: Divider(
                          height: 0.5,
                          color: AppColors.getIosSeparator(
                            brightness,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                );
              }, childCount: filtered.length),
            ),
          ),
      ],
    );
  }
}
