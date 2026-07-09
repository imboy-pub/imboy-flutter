import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoViewGalleryWithInitialPage;
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:octo_image/octo_image.dart';

import 'moment_confirm_dialog.dart';
import 'moment_interactions.dart';
import 'moment_notify/moment_notify_provider.dart';
import 'moment_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:imboy/modules/moment_social/application/moment_facade.dart';

/// 朋友圈页面 - 对标微信朋友圈体验重构
class MomentFeedPage extends StatefulWidget {
  const MomentFeedPage({super.key, this.facade});

  final MomentFacade? facade;

  @override
  State<MomentFeedPage> createState() => _MomentFeedPageState();
}

class _MomentFeedPageState extends State<MomentFeedPage> {
  MomentFacade get _api => widget.facade ?? MomentFacade.instance;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _items = [];
  String? _cursor;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadMoreError = false;
  bool _hasMore = true;
  bool _isStale = false;

  StreamSubscription<MomentTimelineChangedEvent>? _momentSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _momentSub = AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
      if (shouldRefreshFeedOnEvent(event.action)) {
        // 发布新帖后刷新并滚到顶部（让用户立刻看到自己刚发的帖）
        final isNewPost = event.action == 'moment_new';
        _refresh().then((_) {
          if (isNewPost && mounted) _scrollToTop();
        });
      }
    });
    _loadInitial();
  }

  @override
  void dispose() {
    _momentSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!shouldTriggerFeedLoadMore(
      pixels: position.pixels,
      maxExtent: position.maxScrollExtent,
      isLoadingMore: _isLoadingMore,
      hasMore: _hasMore,
    )) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    await _fetchFirstPage();
  }

  Future<void> _refresh() async {
    final ok = await _fetchFirstPage();
    // 下拉刷新失败时：若已有数据（非首屏），toast 提示而非突兀 banner
    if (!ok && mounted && _items.isNotEmpty) {
      AppLoading.showError(t.common.loadError);
    }
  }

  /// 滚动到列表顶部，等下一帧确保新数据已布局。
  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// 返回 true 表示拉取成功，false 表示失败（用于下拉刷新反馈）。
  Future<bool> _fetchFirstPage() async {
    List<Map<String, dynamic>>? remoteEnriched;
    String? nextCursor;
    bool? hasMore;
    try {
      final page = await _api.getFeedPage(limit: 20);
      remoteEnriched = await enrichItemsWithAuthor(page.list);
      nextCursor = page.nextCursor;
      hasMore = page.hasMore;
    } on Exception {
      remoteEnriched = null;
    }
    if (!mounted) return false;
    final snapshot = pickFeedSnapshot(remote: remoteEnriched, cached: _items);
    setState(() {
      _items = snapshot.items;
      _isStale = snapshot.isStale;
      if (!snapshot.isStale) {
        _cursor = nextCursor;
        _hasMore = hasMore ?? _hasMore;
      }
      _isLoading = false;
    });
    return !snapshot.isStale;
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _cursor!.isEmpty || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = false;
    });
    try {
      final page = await _api.getFeedPage(cursor: _cursor, limit: 20);
      if (!mounted) return;
      final enriched = await enrichItemsWithAuthor(page.list);
      setState(() {
        _items = [..._items, ...enriched];
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      // 失败时标记错误，列表末尾渲染"加载失败，点击重试"
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _loadMoreError = true;
        });
      }
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> moment) async {
    final momentId = parseModelString(moment['id']);
    if (momentId.isEmpty) return;
    final liked = parseModelBool(moment['liked']);
    // 点赞/取消点赞轻触感反馈
    HapticFeedback.lightImpact();
    final oldItems = _items;
    setState(() {
      _items = _items
          .map(
            (item) => parseModelString(item['id']) == momentId
                ? applyOptimisticLikeToggle(item)
                : item,
          )
          .toList();
    });
    try {
      final ok = liked
          ? await _api.unlikePost(momentId)
          : await _api.likePost(momentId);
      if (!ok && mounted) setState(() => _items = oldItems);
    } catch (_) {
      if (mounted) setState(() => _items = oldItems);
    }
  }

  Future<void> _deleteMoment(Map<String, dynamic> moment) async {
    final momentId = parseModelString(moment['id']);
    if (momentId.isEmpty) return;
    final confirmed = await showMomentConfirmDialog(
      context,
      title: t.common.delete,
      message: t.common.momentsDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final oldItems = _items;
    setState(() {
      _items = removeMomentById(_items, momentId);
    });
    try {
      if (await _api.deletePost(momentId)) {
        AppEventBus.fire(
          MomentTimelineChangedEvent(
            action: 'moment_deleted',
            momentId: momentId,
            payload: const {},
          ),
        );
      } else if (mounted) {
        setState(() => _items = oldItems);
        AppLoading.showError(t.common.momentsDeleteFailed);
      }
    } catch (_) {
      if (mounted) setState(() => _items = oldItems);
    }
  }

  /// 弹出卡片操作菜单（赞 / 评论 / 删除）。
  void _showActionSheet(
    BuildContext context,
    Map<String, dynamic> item,
    bool canDelete,
  ) {
    HapticFeedback.selectionClick();
    final liked = parseModelBool(item['liked']);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleLike(item);
            },
            child: Text(
              liked
                  ? t.discovery.momentActionCancelLike
                  : t.discovery.momentActionLike,
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(
                '${AppRoutes.momentRoot}/${parseModelString(item['id'])}',
              );
            },
            child: Text(t.discovery.momentActionComment),
          ),
          if (canDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteMoment(item);
              },
              child: Text(t.discovery.momentActionDelete),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.discovery.momentActionCancel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IosPageTemplate(
      title: t.discovery.moments,
      actions: [
        const _MomentNotifyEntry(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.push(AppRoutes.momentCreate),
          child: const Icon(CupertinoIcons.camera, size: 22),
        ),
      ],
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refresh),
        if (_isStale)
          SliverToBoxAdapter(
            child: MomentStaleBanner(isStale: _isStale, onRetry: _refresh),
          ),
        if (_isLoading)
          const SliverFillRemaining(child: ShimmerList(itemHeight: 140))
        else if (_items.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _items.length) {
                  // 触底加载区：失败时显示重试，否则转圈
                  if (_loadMoreError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CupertinoButton(
                          onPressed: _loadMore,
                          child: Text(
                            t.common.loadError,
                            style: context.textStyle(
                              FontSizeType.footnote,
                              color: AppColors.iosGray,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }
                final item = _items[index];
                final currentUid = currentUidOrEmpty();
                final canDelete = canDeleteMoment(item, currentUid);
                return Column(
                  children: [
                    _MomentCard(
                      item: item,
                      canDelete: canDelete,
                      onTap: () => context.push(
                        '${AppRoutes.momentRoot}/${parseModelString(item['id'])}',
                      ),
                      onActionTap: () =>
                          _showActionSheet(context, item, canDelete),
                    ),
                    Divider(
                      height: 0.5,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.getIosSeparator(
                        theme.brightness,
                      ).withValues(alpha: 0.3),
                    ),
                  ],
                );
              },
              childCount:
                  _items.length + ((_isLoadingMore || _loadMoreError) ? 1 : 0),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.photo_on_rectangle,
            size: 60,
            color: AppColors.iosGray.withValues(alpha: 0.3),
          ),
          AppSpacing.verticalRegular,
          Text(
            t.common.momentsNoData,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.iosGray,
            ),
          ),
        ],
      ),
    );
  }
}

class MomentStaleBanner extends StatelessWidget {
  final bool isStale;
  final VoidCallback onRetry;
  const MomentStaleBanner({
    super.key,
    required this.isStale,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    if (!isStale) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.iosOrange.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 18,
            color: AppColors.iosOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.discovery.momentsFeedStale,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosOrange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onRetry,
            child: Text(
              t.common.buttonRetry,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 朋友圈动态卡片（微信式重构）。
class _MomentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onActionTap;

  const _MomentCard({
    required this.item,
    required this.canDelete,
    required this.onTap,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = resolveMomentDisplayName(
      remark: parseModelString(item['author_remark']),
      nickname: parseModelString(item['author_nickname']),
      uid: parseModelString(item['author_uid']),
    );
    final authorAvatar = parseModelString(item['author_avatar']);
    final stats = item['stats'] is Map
        ? Map<String, dynamic>.from(item['stats'] as Map)
        : const <String, dynamic>{};
    final media = normalizeMedia(item['media']);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final likeCount = parseModelInt(stats['like_count']);
    final likers = parseRecentLikers(item);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(
              imgUri: authorAvatar,
              width: 42,
              height: 42,
              // Hero 共享元素：feed→详情头像平滑过渡
              heroTag: 'moment_avatar_${parseModelString(item['id'])}',
              // 点作者头像跳资料页（对齐微信）
              onTap: () => context.push(
                '/contact/people/${parseModelString(item['author_uid'])}'
                '?scene=contact_page',
              ),
            ),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 作者名 + 右上角操作入口
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        // 点作者名跳资料页（对齐微信，与头像一致）
                        child: GestureDetector(
                          onTap: () => context.push(
                            '/contact/people/${parseModelString(item['author_uid'])}'
                            '?scene=contact_page',
                          ),
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.medium,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.wechatBlue,
                            ),
                          ),
                        ),
                      ),
                      // 右上角•••操作入口，命中区 44×44
                      Semantics(
                        button: true,
                        label: t.discovery.momentActionComment,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onActionTap,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Icon(
                                CupertinoIcons.ellipsis,
                                size: 18,
                                color: AppColors.iosGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (parseModelString(item['content']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _MomentContent(
                        content: parseModelString(item['content']),
                        onViewFull: onTap,
                      ),
                    ),
                  if (media.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _MomentMediaPreview(media: media),
                    ),
                  // 点赞人行（微信核心社交反馈）— AnimatedSize 让出现/消失高度平滑过渡
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: (likeCount > 0 || likers.isNotEmpty)
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _MomentLikersRow(
                              likers: likers,
                              totalCount: likeCount,
                              onTap: onTap,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // 底部时间行（相对时间，定时刷新避免"刚刚"假死）
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _RelativeTimeText(
                      createdAt: parseModelString(item['created_at']),
                    ),
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

/// Feed 卡片正文：超长文本默认折叠（6 行），「全文」展开/「收起」折叠。
///
/// 替代原先无限制 Text——长文会把卡片撑成几屏高，破坏列表浏览。
/// 短文（<140 字）不显示展开按钮。
class _MomentContent extends StatefulWidget {
  final String content;
  final VoidCallback? onViewFull;

  const _MomentContent({required this.content, this.onViewFull});

  @override
  State<_MomentContent> createState() => _MomentContentState();
}

class _MomentContentState extends State<_MomentContent> {
  bool _expanded = false;

  /// 约 6 行的字符阈值，超过则显示「全文」。
  bool get _isLong => widget.content.length > 140;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 展开后用 SelectableText（可复制），折叠态用 Text（避免手势冲突）
        if (_expanded)
          SelectableText(
            widget.content,
            style: context
                .textStyle(FontSizeType.subheadline)
                .copyWith(height: 1.45),
          )
        else
          Text(
            widget.content,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: context
                .textStyle(FontSizeType.subheadline)
                .copyWith(height: 1.45),
          ),
        if (_isLong)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? t.discovery.momentCollapse
                    : t.discovery.momentShowFull,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.wechatBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 时间戳定时刷新：解决停留时"刚刚"假死问题。
///
/// 最近 1 小时内每 60 秒重建一次（"刚刚"→"N分钟前"过渡自然）；
/// 超过 1 小时变化慢，不启用 Timer，避免无效开销。
/// 列表滚动回收时 dispose 自动取消 Timer。
class _RelativeTimeText extends StatefulWidget {
  final String createdAt;

  const _RelativeTimeText({required this.createdAt});

  @override
  State<_RelativeTimeText> createState() => _RelativeTimeTextState();
}

class _RelativeTimeTextState extends State<_RelativeTimeText> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _maybeStartTimer();
  }

  void _maybeStartTimer() {
    final dt = DateTime.tryParse(widget.createdAt.trim());
    if (dt == null) return;
    final diffMin = DateTime.now().difference(dt.toLocal()).inMinutes;
    // 只在最近 1 小时内启用定时刷新
    if (diffMin < 60) {
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (mounted) setState(() => _tick++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // _tick 引用确保 Timer 触发时重建
    assert(_tick >= 0);
    return Text(
      momentRelativeTime(widget.createdAt),
      style: context.textStyle(FontSizeType.small, color: AppColors.iosGray),
    );
  }
}

/// 点赞心形：点赞数增加时做一次弹跳动画（1.0→1.3→1.0）。
class _AnimatedHeart extends StatefulWidget {
  final int count;
  const _AnimatedHeart({required this.count});

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.count;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_AnimatedHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > _prevCount) {
      _controller.forward(from: 0);
    }
    _prevCount = widget.count;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(
        CupertinoIcons.heart_fill,
        size: 14,
        color: AppColors.wechatBlue,
      ),
    );
  }
}

/// 点赞人行：左侧心形图标 + 「张三、李四 等 N 人赞了」。
class _MomentLikersRow extends StatelessWidget {
  final List<Map<String, dynamic>> likers;
  final int totalCount;
  final VoidCallback onTap;

  const _MomentLikersRow({
    required this.likers,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = buildLikersLabel(likers, totalCount, translations: context.t);
    if (label.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurfaceGrouped,
          borderRadius: AppRadius.borderRadiusMedium,
        ),
        child: Row(
          children: [
            _AnimatedHeart(count: totalCount),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.wechatBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentMediaPreview extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  const _MomentMediaPreview({required this.media});
  @override
  Widget build(BuildContext context) {
    final imageUrls = media
        .where((m) => parseModelString(m['type']) != 'video')
        .map(pickMediaPreviewUrl)
        .where((u) => u.isNotEmpty)
        .toList();
    if (media.length == 1) {
      final isVideo = parseModelString(media.first['type']) == 'video';
      // 单图按真实宽高比展示，视频仍走固定尺寸 cell
      if (!isVideo) {
        return _SingleImagePreview(
          item: media.first,
          imageUrls: imageUrls,
          imageIndex: 0,
        );
      }
      return _MomentMediaCell(
        item: media.first,
        size: 200,
        imageUrls: const [],
        imageIndex: 0,
      );
    }
    int imgIdx = 0;
    final cellSize = (MediaQuery.of(context).size.width - 100) / 3;
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: media.map((item) {
        final isVideo = parseModelString(item['type']) == 'video';
        final idx = isVideo ? 0 : imgIdx++;
        return _MomentMediaCell(
          item: item,
          size: cellSize,
          imageUrls: isVideo ? const [] : imageUrls,
          imageIndex: idx,
        );
      }).toList(),
    );
  }
}

/// 单图按真实宽高比展示（对齐微信/小红书）。
class _SingleImagePreview extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<String> imageUrls;
  final int imageIndex;

  const _SingleImagePreview({
    required this.item,
    required this.imageUrls,
    required this.imageIndex,
  });

  @override
  State<_SingleImagePreview> createState() => _SingleImagePreviewState();
}

class _SingleImagePreviewState extends State<_SingleImagePreview> {
  double? _aspectRatio;
  ImageStream? _imageStream;
  late ImageStreamListener _listener;

  @override
  void initState() {
    super.initState();
    final url = pickMediaPreviewUrl(widget.item);
    if (url.isEmpty) return;
    final provider = cachedImageProvider(url);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final img = info.image;
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      if (h > 0 && mounted) {
        setState(() => _aspectRatio = w / h);
      }
    });
    _imageStream = provider.resolve(createLocalImageConfiguration(context));
    _imageStream!.addListener(_listener);
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = pickMediaPreviewUrl(widget.item);
    final cardWidth = MediaQuery.of(context).size.width - 16 * 2 - 42 - 12;
    final maxHeight = MediaQuery.of(context).size.width * 0.6;
    final aspect = _aspectRatio ?? 4 / 3;
    var displayWidth = cardWidth;
    var displayHeight = displayWidth / aspect;
    if (displayHeight > maxHeight) {
      displayHeight = maxHeight;
      displayWidth = displayHeight * aspect;
    }

    return GestureDetector(
      onTap: widget.imageUrls.isNotEmpty
          ? () => zoomInPhotoViewGalleryWithInitialPage(
              context,
              widget.imageUrls,
              widget.imageIndex,
            )
          : null,
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusMedium,
        child: Container(
          width: displayWidth,
          height: displayHeight,
          color: AppColors.iosGray.withValues(alpha: 0.1),
          child: OctoImage(
            image: cachedImageProvider(url),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }
}

/// 视频角标：半透明黑底圆角小徽章。
class _VideoBadge extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final double iconSize;

  const _VideoBadge({this.text, this.icon, this.iconSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.darkBackground.withValues(alpha: 0.5),
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: iconSize, color: AppColors.onPrimary),
          if (icon != null && text != null) const SizedBox(width: 3),
          if (text != null)
            Text(
              text!,
              style: context
                  .textStyle(
                    FontSizeType.tiny,
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w500,
                  )
                  .copyWith(height: 1.2),
            ),
        ],
      ),
    );
  }
}

class _MomentMediaCell extends StatefulWidget {
  final Map<String, dynamic> item;
  final double size;
  final List<String> imageUrls;
  final int imageIndex;
  const _MomentMediaCell({
    required this.item,
    required this.size,
    this.imageUrls = const [],
    this.imageIndex = 0,
  });
  @override
  State<_MomentMediaCell> createState() => _MomentMediaCellState();
}

class _MomentMediaCellState extends State<_MomentMediaCell> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoController(String url) async {
    if (_videoController != null) return;
    final String resolved = await AssetUrlResolver.instance.resolveForDisplay(
      url,
    );
    if (!mounted || _videoController != null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _videoController = controller;
    controller
      ..initialize().then((_) {
        if (mounted && _videoController == controller) {
          setState(() {});
          controller.play();
        }
      })
      ..setLooping(true)
      ..setVolume(0);
  }

  /// 点击视频：未播放时手动播放（移动网络兜底）。
  Future<void> _onVideoTap() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    await _initVideoController(parseModelString(widget.item['url']));
    if (mounted) {
      _videoController?.play();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = parseModelString(widget.item['type']);
    final previewUrl = pickMediaPreviewUrl(widget.item);
    if (type != 'video') {
      return GestureDetector(
        onTap: widget.imageUrls.isNotEmpty
            ? () => zoomInPhotoViewGalleryWithInitialPage(
                context,
                widget.imageUrls,
                widget.imageIndex,
              )
            : null,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMedium,
            color: AppColors.iosGray.withValues(alpha: 0.1),
          ),
          clipBehavior: Clip.antiAlias,
          child: OctoImage(
            image: cachedImageProvider(previewUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          ),
        ),
      );
    }
    return VisibilityDetector(
      key: Key('video_${widget.item['url']}'),
      onVisibilityChanged: (info) async {
        if (info.visibleFraction > 0.8) {
          // 移动网络下不自动播放（省流量），WiFi 才自动播放
          final unmetered = await isUnmeteredNetwork();
          if (!mounted) return;
          if (unmetered) {
            _initVideoController(parseModelString(widget.item['url']));
            _videoController?.play();
            setState(() => _isPlaying = true);
          }
        } else if (info.visibleFraction < 0.2) {
          _videoController?.pause();
          _videoController?.dispose();
          _videoController = null;
          setState(() => _isPlaying = false);
        }
      },
      child: GestureDetector(
        // 点击兜底播放（移动网络未自动播放时，用户主动点击可播放）
        onTap: _onVideoTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMedium,
            // 视频播放衬底，保留纯黑以贴合播放器视觉
            color: AppColors.darkBackground,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_videoController?.value.isInitialized ?? false)
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
              else
                OctoImage(
                  image: cachedImageProvider(previewUrl),
                  fit: BoxFit.cover,
                ),
              if (!_isPlaying)
                const Icon(
                  CupertinoIcons.play_circle_fill,
                  color: AppColors.onPrimary,
                  size: 30,
                ),
              // 左上角静音指示
              Positioned(
                left: 6,
                top: 6,
                child: const _VideoBadge(
                  icon: CupertinoIcons.speaker_slash_fill,
                  iconSize: 11,
                ),
              ),
              // 右下角时长徽章
              if (mediaDurationMs(widget.item) > 0)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _VideoBadge(
                    text: formatVideoDuration(mediaDurationMs(widget.item)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentNotifyEntry extends ConsumerWidget {
  const _MomentNotifyEntry();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(momentNotifyProvider.select((s) => s.unreadCount));
    return Semantics(
      button: true,
      label: t.momentNotify.title,
      hint: unread > 0 ? '$unread' : null,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => context.push('/moment_notify'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(CupertinoIcons.bell, size: 22),
            if (unread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.iosRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: context.textStyle(
                      FontSizeType.tiny,
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
