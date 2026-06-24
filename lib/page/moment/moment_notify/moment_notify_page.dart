/// 朋友圈通知中心列表页（Slice A-3 + A-4）。
///
/// - 展示 `moment_like` / `moment_comment` 的本地落库通知
/// - 下拉刷新 / 触底分页
/// - AppBar 两个操作：全部已读 / 清空全部
/// - 点击单条 → 标记已读 + 跳转朋友圈详情
/// - 左滑删除单条（Dismissible）
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
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
        ref.read(momentNotifyProvider.notifier).clearError();
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
            TextButton(
              onPressed: notifier.markAllRead,
              child: Text(t.momentNotify.markAllRead),
            ),
          if (state.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: t.momentNotify.clearAll,
              onPressed: () => _confirmClearAll(context, notifier),
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
    if (state.items.isEmpty && !state.isLoading) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.iosGray,
                  ),
                  AppSpacing.verticalMedium,
                  Text(
                    t.momentNotify.emptyTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxLarge,
                    ),
                    child: Text(
                      t.momentNotify.emptyHint,
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.iosGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 72, endIndent: 16),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.regular),
              child: Center(child: CircularProgressIndicator()),
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
        final timeText = DateTimeHelper.dateTimeFmt(
          DateTime.fromMillisecondsSinceEpoch(item.createdAt),
        );

        return ListTile(
          onTap: () => _onItemTap(context, item, notifier),
          leading: Avatar(imgUri: avatarUrl, width: 44, height: 44),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  nickname,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(actionText, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  timeText,
                  // DESIGN.md §3.4：时间戳数字等宽对齐
                  style: context
                      .textStyle(FontSizeType.small, color: AppColors.iosGray)
                      .copyWith(fontFeatures: [FontFeature.tabularFigures()]),
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
