import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:badges/badges.dart' as badges;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart'
    show newFriendRemindProvider;
import 'package:imboy/page/conversation/widget/subscribed_channel_strip.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/conversation/widget/right_button.dart'
    show RightButton;
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/websocket_events.dart'
    show WebSocketStatusChangedEvent;
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'conversation_provider.dart';
import 'widget/conversation_item.dart';

/// 会话列表页面 - Riverpod 版本
///
/// 此页面使用 Riverpod 进行状态管理，替代原有的 GetX 版本
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  StreamSubscription? ssMsg;
  StreamSubscription? ssExtend; // 监听会话扩展事件（清空聊天记录等）

  // 语言变化监听器
  StreamSubscription? _localeSubscription;

  // 网络状态监听器
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _websocketStatusSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(initData());

    // 监听语言变化，切换语言时刷新页面
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) async {
      if (!mounted) return;
      // 更新网络连接描述文本
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        ref
            .read(conversationProvider.notifier)
            .setConnectDesc(t.tipConnectDescWithParen(param: t.tipConnectDesc));
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
    super.dispose();
  }

  Future<void> initData() async {
    final notifier = ref.read(conversationProvider.notifier);

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      notifier.setConnectDesc(
        t.tipConnectDescWithParen(param: t.tipConnectDesc),
      );
    } else {
      notifier.setConnectDesc('');
    }

    // 监听网络状态
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> r,
    ) {
      if (!mounted) return;

      if (r.contains(ConnectivityResult.none)) {
        notifier.setConnectDesc(
          t.tipConnectDescWithParen(param: t.tipConnectDesc),
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

    // 监听会话消息
    ssMsg = AppEventBus.on<DataWrapperEvent>().listen((event) async {
      if (!mounted) return;

      // 处理不同的数据类型
      if (event.data is ConversationModel) {
        final obj = event.data as ConversationModel;
        obj.title = await notifier.computeTitle(obj);
        // 更新会话
        await notifier.replace(obj);
      } else if (event.data is List && event.data.isNotEmpty) {
        // 处理消息列表（用于批量更新）
        final messages = event.data as List;
        if (messages.first is Message) {
          // 消息列表由其他地方处理，这里跳过或做特殊处理
          iPrint('收到消息列表事件，跳过会话更新');
        }
      }
    });

    // 监听会话扩展事件（清空聊天记录、删除消息等）
    ssExtend = AppEventBus.on<ChatExtendEvent>().listen((event) async {
      if (!mounted) return;

      // 处理会话刷新事件
      if (event.type == 'refresh_conversations' || event.type == 'clean_msg') {
        // 优先使用事件中的完整会话对象
        if (event.payload['conversation'] is ConversationModel) {
          final updatedConv =
              event.payload['conversation'] as ConversationModel;
          if (updatedConv.id > 0) {
            await notifier.replace(updatedConv);
            return;
          }
        }

        // 回退：从 uk3 查询
        final uk3 = event.payload['uk3'] as String?;
        if (uk3 != null && uk3.isNotEmpty) {
          // 从 uk3 中解析 type 和 peerId (格式: "C2C_uid1_uid2" 或 "C2G_groupId")
          final parts = uk3.split('_');
          if (parts.length >= 3) {
            final type = parts[0];
            final peerId = parts.sublist(1).join('_');

            // 从数据库重新加载该会话的信息
            final updatedConv = await ConversationRepo().findByPeerId(
              type,
              peerId,
            );
            if (updatedConv != null && updatedConv.id > 0) {
              await notifier.replace(updatedConv);
            }
          }
        }
      }
    });

    // 加载会话记录
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

    return Scaffold(
      appBar: GlassAppBar(
        leading: const SizedBox.shrink(),
        title: '${t.titleMessage}${state.connectDesc}',
        rightDMActions: <Widget>[
          // 联系人入口（带新朋友请求角标），从联系人 Tab 迁入
          _ContactsIconButton(),
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: const RightButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.connectDesc.isNotEmpty)
            NetworkFailureTips()
          else
            const SizedBox.shrink(),
          // 频道置顶区（订阅频道 Telegram 式归并，feature flag 控制）
          if (AppFeatureRegistry.isEnabled('channel'))
            const SubscribedChannelStrip(),
          Expanded(
            child: SlidableAutoCloseBehavior(
              child: RefreshIndicator(
                onRefresh: () async {
                  await notifier.syncAuthoritativeConversationList(
                    trigger: 'pull_to_refresh',
                  );
                },
                child: state.isLoading
                    ? const ShimmerList()
                    : state.conversations.isEmpty
                    ? NoDataView(text: t.noConversationMessages)
                    : ListView.builder(
                        itemExtent: 88.0,
                        itemCount: state.conversations.length,
                        itemBuilder: (BuildContext context, int index) {
                          if (index >= state.conversations.length) {
                            return const SizedBox.shrink();
                          }
                          ConversationModel model = state.conversations[index];
                          return InkWell(
                            onTap: () {
                              context.push(
                                '/chat/${model.peerId}',
                                extra: {
                                  'type': strEmpty(model.type)
                                      ? 'C2C'
                                      : model.type,
                                  'title': model.title,
                                  'avatar': model.avatar,
                                  'sign': model.sign,
                                },
                              );
                            },
                            onTapDown: (TapDownDetails details) {},
                            onLongPress: () {},
                            child: Slidable(
                              key: ValueKey(model.id),
                              groupTag: '0',
                              closeOnScroll: true,
                              endActionPane: ActionPane(
                                extentRatio: 0.618,
                                motion: const StretchMotion(),
                                children: [
                                  CustomSlidableAction(
                                    onPressed: (_) async {
                                      final targetUnread = model.unreadNum > 0
                                          ? 0
                                          : 1;
                                      if (model.unreadNum > 0) {
                                        // 当前有未读消息，标记为已读
                                        // 同步将该会话未读消息状态从 delivered 改为 seen
                                        try {
                                          final db = await SqliteService.to.db;
                                          if (db != null) {
                                            final tb = MessageRepo.getTableName(
                                              model.type,
                                            );
                                            await db.update(
                                              tb,
                                              {
                                                MessageRepo.status:
                                                    IMBoyMessageStatus.seen,
                                              },
                                              where:
                                                  "${MessageRepo.conversationUk3} = ? and ${MessageRepo.status} = ? and ${MessageRepo.isAuthor} = ?",
                                              whereArgs: [
                                                model.uk3,
                                                IMBoyMessageStatus.delivered,
                                                0,
                                              ],
                                            );
                                          }
                                        } catch (e) {
                                          // 忽略异常以保证交互流畅
                                        }
                                        // 推进水位到该会话来自对方的最新消息
                                        await notifier.advanceWatermarkToLatest(
                                          model,
                                        );
                                        await notifier.setConversationRemind(
                                          model,
                                          0,
                                        );
                                      } else {
                                        // 当前没有未读消息，标记为未读
                                        await notifier.setConversationRemind(
                                          model,
                                          1,
                                        );
                                      }
                                      notifier.applyConversationSnapshot(
                                        model.copyWith(unreadNum: targetUnread),
                                      );
                                    },
                                    autoClose: true,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    flex: 2,
                                    child: Builder(
                                      builder: (context) {
                                        final currentNum = model.unreadNum > 0
                                            ? 0
                                            : 1;
                                        return Text(
                                          currentNum > 0
                                              ? t.markRead
                                              : t.markUnread,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SlidableAction(
                                    key: ValueKey("pin_$index"),
                                    flex: 3,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                    onPressed: (_) async {
                                      final targetPinned = !model.isPinned;
                                      final ok = await notifier
                                          .setConversationPinned(
                                            model,
                                            targetPinned,
                                          );
                                      if (!context.mounted || ok) {
                                        return;
                                      }
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        SnackBar(content: Text(t.tipFailed)),
                                      );
                                    },
                                    label: model.isPinned ? t.unpin : t.pin,
                                    spacing: 1,
                                  ),
                                  SlidableAction(
                                    key: ValueKey("delete_$index"),
                                    flex: 2,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onError,
                                    onPressed: (_) async {
                                      final ok = await notifier
                                          .deleteConversationRemote(model);
                                      if (!context.mounted || ok) {
                                        return;
                                      }
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        SnackBar(content: Text(t.tipFailed)),
                                      );
                                    },
                                    label: t.buttonDelete,
                                    spacing: 1,
                                  ),
                                ],
                              ),
                              child: ConversationItem(
                                model: model,
                                onTapAvatar: () {
                                  context.push(
                                    '/contact/people/${model.peerId}',
                                    extra: {'scene': ''},
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 联系人入口图标按钮（带新朋友请求角标）
///
/// 原联系人 Tab 角标移入此处，保证"新朋友请求"可见性不丢失。
class _ContactsIconButton extends ConsumerWidget {
  const _ContactsIconButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newFriendCount = ref.watch(newFriendRemindProvider).length;
    return badges.Badge(
      showBadge: newFriendCount > 0,
      position: badges.BadgePosition.topStart(top: -2, start: 18),
      badgeContent: Text(
        newFriendCount.toString(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      badgeStyle: badges.BadgeStyle(
        badgeColor: AppColors.messageFailed,
        borderRadius: AppRadius.borderRadiusMedium,
        elevation: 2,
      ),
      child: IconButton(
        onPressed: () => context.push('/contact'),
        tooltip: context.t.titleContact,
        icon: Icon(
          Icons.people_alt_outlined,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
