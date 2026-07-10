/// 朋友圈通知中心列表页（Slice A-3 + A-4）。
///
/// - 展示 `moment_like` / `moment_comment` 的本地落库通知
/// - 下拉刷新 / 触底分页
/// - AppBar 两个操作：全部已读 / 清空全部
/// - 点击单条 → 标记已读 + 跳转朋友圈详情
/// - 左滑删除单条（Dismissible）
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Scaffold, Divider, RefreshIndicator, Theme;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_provider.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_state.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/moment_notify_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class MomentNotifyPage extends ConsumerStatefulWidget {
  const MomentNotifyPage({super.key});

  @override
  ConsumerState<MomentNotifyPage> createState() => _MomentNotifyPageState();
}

class _MomentNotifyPageState extends ConsumerState<MomentNotifyPage> {
  static const double _loadMoreThreshold = 120;

  final ScrollController _scrollController = ScrollController();

  /// 联系人 Future 缓存：key = fromUid。
  /// 缓存 Future 而非 value，保证同一 uid 每次 rebuild 返回同一 Future 实例，
  /// 避免 FutureBuilder 误入 waiting 态闪骨架。
  /// 单向惰性填充，不做失效策略（通知中心本身容量有限）。
  final Map<String, Future<ContactModel?>> _contactFutureCache = {};

  /// 最近一次 refresh/loadMore 失败且列表仍为空时置真，用于渲染"错误态"区别
  /// 于"空列表"态。errorMessage 在 provider 侧被 toast 消费后立即清空
  /// （既有约定，对齐 group_announcement），故此处用本地状态承接持久标记；
  /// 一旦拿到数据（items 非空）即复位。
  bool _lastLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(momentNotifyProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - _loadMoreThreshold) return;
    // 早退守卫：快速滚动会在 isLoading=true 置位前触发多次回调；
    // 这里先读瞬时 state，避免多余的 copyWith 写入（loadMore 内部也有守卫）。
    final snapshot = ref.read(momentNotifyProvider);
    if (snapshot.isLoading || !snapshot.hasMore) return;
    ref.read(momentNotifyProvider.notifier).loadMore();
  }

  /// 返回同一 uid 对应的同一 Future 实例，命中缓存时不触发新的 Repo 查询，
  /// 也不让 FutureBuilder 重新进入 waiting 态。
  Future<ContactModel?> _resolveContact(String uid) {
    if (uid.isEmpty) return Future.value(null);
    return _contactFutureCache.putIfAbsent(uid, () async {
      try {
        return await ContactRepo().findByUid(uid, autoFetch: false);
      } on Exception {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // refresh/loadMore 失败时 toast 反馈；消费后即清错，避免重复弹。
    ref.listen<MomentNotifyState>(momentNotifyProvider, (prev, next) {
      final msg = next.errorMessage;
      if (msg != null && msg.isNotEmpty && prev?.errorMessage != msg) {
        AppLoading.showToast(t.momentNotify.loadFailed);
        if (next.items.isEmpty && !_lastLoadFailed) {
          setState(() => _lastLoadFailed = true);
        }
        ref.read(momentNotifyProvider.notifier).clearError();
      } else if (next.items.isNotEmpty && _lastLoadFailed) {
        setState(() => _lastLoadFailed = false);
      }
    });

    final state = ref.watch(momentNotifyProvider);
    final notifier = ref.read(momentNotifyProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.momentNotify.title,
        rightDMActions: [
          if (state.unreadCount > 0)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: notifier.markAllRead,
              child: Text(t.momentNotify.markAllRead),
            ),
          if (state.items.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: () => _confirmClearAll(context, notifier),
              child: const Icon(CupertinoIcons.delete, size: 20),
            ),
        ],
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MomentNotifyState state,
    MomentNotifyNotifier notifier,
  ) {
    // 首次加载：居中转圈（替代空白）
    if (state.items.isEmpty && state.isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (state.items.isEmpty && !state.isLoading) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            // 错误态与空列表态区分：加载失败用感叹号图标 + 可点重试，
            // 真空态用铃铛静音图标 + 标题/提示两行文案。
            _lastLoadFailed
                ? NoDataView(
                    text: t.momentNotify.loadFailed,
                    icon: CupertinoIcons.wifi_exclamationmark,
                    onTop: notifier.refresh,
                  )
                : NoDataView(
                    text: t.momentNotify.emptyTitle,
                    description: t.momentNotify.emptyHint,
                    icon: CupertinoIcons.bell_slash,
                  ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(
          height: 0.5,
          indent: 72,
          endIndent: 16,
          color: AppColors.getIosSeparator(
            Theme.of(context).brightness,
          ).withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.regular),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }
          final item = state.items[index];
          return _buildItem(context, item, notifier);
        },
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    MomentNotifyModel item,
    MomentNotifyNotifier notifier,
  ) {
    final id = item.id;
    final tile = FutureBuilder<ContactModel?>(
      future: _resolveContact(item.fromUid),
      builder: (context, snap) {
        final contact = snap.data;
        final nickname = contact?.title ?? item.fromUid; // fallback 到 uid 避免骨架态
        final avatarUrl = contact?.avatar ?? '';
        final actionText = item.action == 'moment_like'
            ? t.momentNotify.actionLike
            : t.momentNotify.actionComment;
        // toLocal() 修复时区：超 2 天时 DateFormat 用 DateTime 自带时区
        final timeText = DateTimeHelper.dateTimeFmt(
          DateTime.fromMillisecondsSinceEpoch(item.createdAt).toLocal(),
        );

        // DESIGN.md §13.2：卡片点击态用 GestureDetector，禁用 Material Ripple
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onItemTap(context, item, notifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.large,
              vertical: AppSpacing.regular,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                  imgUri: avatarUrl,
                  width: 44,
                  height: 44,
                  onTap: () => context.push(
                    '/contact/people/${item.fromUid}?scene=contact_page',
                  ),
                ),
                AppSpacing.horizontalMedium,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nickname,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.iosRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        actionText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeText,
                        // DESIGN.md §3.4：时间戳数字等宽对齐
                        style: context
                            .textStyle(
                              FontSizeType.small,
                              color: AppColors.iosGray,
                            )
                            .copyWith(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (id == null) return tile;

    return Dismissible(
      key: ValueKey('moment_notify_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
        color: AppColors.iosRed,
        child: Text(
          t.momentNotify.delete,
          style: const TextStyle(color: AppColors.onPrimary),
        ),
      ),
      onDismissed: (_) => notifier.delete(id),
      child: tile,
    );
  }

  Future<void> _onItemTap(
    BuildContext context,
    MomentNotifyModel item,
    MomentNotifyNotifier notifier,
  ) async {
    final id = item.id;
    if (id != null && !item.isRead) {
      await notifier.markRead(id);
    }
    if (!context.mounted) return;
    context.push('/moment/${item.momentId}');
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    MomentNotifyNotifier notifier,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.momentNotify.clearConfirmTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.small),
          child: Text(t.momentNotify.clearConfirmMessage),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.momentNotify.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.momentNotify.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.clearAll();
    }
  }
}
