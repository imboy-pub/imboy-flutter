import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart'; // 引入 cachedImageProvider
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/assets.dart'; // 引入 AssetsService
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:octo_image/octo_image.dart';

import 'moment_confirm_dialog.dart';
import 'moment_interactions.dart';
import 'moment_notify/moment_notify_provider.dart';
import 'moment_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:imboy/modules/moment_social/application/moment_facade.dart';

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
  bool _hasMore = true;

  /// 当前渲染的 items 是否来自失败回退（离线缓存 / 旧数据）。
  /// 上层 UI 可据此显示离线 banner；当前暂未渲染 banner，仅做 state 持久化。
  bool _isStale = false;

  StreamSubscription<MomentTimelineChangedEvent>? _momentSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _momentSub = AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
      if (shouldRefreshFeedOnEvent(event.action)) {
        _refresh();
      }
    });
    _loadInitial();
  }

  @override
  void dispose() {
    _momentSub?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    // hasClients 是 Flutter 特定 guard（无 attached View 时访问 position 会抛），
    // 不进入纯函数；其余三段判断（loading / hasMore / 距底阈值）走 shouldTriggerFeedLoadMore。
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    await _fetchFirstPage();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await _fetchFirstPage();
  }

  /// 拉取首页并在网络失败时走 `pickFeedSnapshot` 离线兜底：
  /// - 成功：用 remote 覆盖 items、清 stale、更新 cursor/hasMore
  /// - 失败：保留当前 items、打 stale 标、cursor/hasMore 保持旧值（避免下拉
  ///   刷新失败后把「还有更多」强行翻成 false，影响后续滚动加载）
  Future<void> _fetchFirstPage() async {
    List<Map<String, dynamic>>? remoteEnriched;
    String? nextCursor;
    bool? hasMore;
    try {
      final page = await _api.getFeedPage(limit: 20);
      remoteEnriched = await enrichItemsWithAuthor(page.list);
      nextCursor = page.nextCursor;
      hasMore = page.hasMore;
    } on Exception {
      remoteEnriched = null; // 走 pickFeedSnapshot 的 stale 分支
    }
    if (!mounted) return;
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
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _cursor!.isEmpty || _isLoadingMore) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
    });
    final page = await _api.getFeedPage(cursor: _cursor, limit: 20);
    if (!mounted) return;
    final enriched = await enrichItemsWithAuthor(page.list);
    if (!mounted) return;
    setState(() {
      _items = [..._items, ...enriched];
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
      _isLoadingMore = false;
    });
  }

  Future<void> _toggleLike(Map<String, dynamic> moment) async {
    final momentId = parseModelString(moment['id']);
    if (momentId.isEmpty) return;
    final liked = parseModelBool(moment['liked']);

    // 保存旧状态用于回滚
    final oldItems = _items;

    // 乐观更新 UI
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((item) {
            if (parseModelString(item['id']) != momentId) {
              return item;
            }
            return applyOptimisticLikeToggle(item);
          })
          .toList(growable: false);
    });

    // 发送请求，失败时回滚
    try {
      final ok = liked
          ? await _api.unlikePost(momentId)
          : await _api.likePost(momentId);
      if (!ok && mounted) {
        setState(() {
          _items = oldItems;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _items = oldItems;
        });
      }
    }
  }

  Future<void> _deleteMoment(Map<String, dynamic> moment) async {
    final momentId = parseModelString(moment['id']);
    if (momentId.isEmpty) return;
    final t = context.t;
    final confirmed = await showMomentConfirmDialog(
      context,
      title: t.delete,
      message: t.momentsDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    // 保存旧状态用于回滚
    final oldItems = _items;

    // 乐观移除 UI
    setState(() {
      _items = removeMomentById(_items, momentId);
    });

    // 发送请求，失败时回滚并提示
    bool ok = false;
    try {
      ok = await _api.deletePost(momentId);
    } on Exception {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _items = oldItems;
      });
      EasyLoading.showError(context.t.momentsDeleteFailed);
      return;
    }
    AppEventBus.fire(
      MomentTimelineChangedEvent(
        action: 'moment_deleted',
        momentId: momentId,
        payload: const <String, dynamic>{},
      ),
    );
  }

  Future<void> _openCreate() async {
    // Create page fires a MomentTimelineChangedEvent('moment_new') on success;
    // the eventbus subscription handles the refresh. Avoid calling _refresh
    // here to prevent a redundant double-fetch.
    await context.push(AppRoutes.momentCreate);
  }

  Future<void> _openDetail(String momentId) async {
    if (momentId.isEmpty) return;
    // Detail page's _deleteMoment fires a moment_deleted event on success;
    // eventbus subscription handles the refresh. The push result is no longer
    // consulted to avoid double-fetch.
    await context.push('${AppRoutes.momentRoot}/$momentId');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.moments),
        actions: [
          const _MomentNotifyEntry(),
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: t.momentsSend,
          ),
        ],
      ),
      body: _isLoading
          ? const ShimmerList(itemHeight: 140)
          : Column(
              children: [
                MomentStaleBanner(isStale: _isStale, onRetry: _refresh),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: _items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 96,
                            ),
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.photo_library_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(child: Text(t.momentsNoData)),
                            ],
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, thickness: 0.5),
                            itemBuilder: (context, index) {
                              if (index >= _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final item = _items[index];
                              final currentUid = currentUidOrEmpty();
                              final canDelete = canDeleteMoment(
                                item,
                                currentUid,
                              );
                              return _MomentCard(
                                item: item,
                                canDelete: canDelete,
                                onTap: () =>
                                    _openDetail(parseModelString(item['id'])),
                                onLikeTap: () => _toggleLike(item),
                                onDeleteTap: canDelete
                                    ? () => _deleteMoment(item)
                                    : null,
                                onVideoVisible: null,
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 顶部离线 banner：当 feed 首页拉取失败、回退到缓存时显示。
///
/// 行为契约：
/// - `isStale = false` → 返回 `SizedBox.shrink()`，不占位、不影响 ListView 首项。
/// - `isStale = true`  → 橙色轻量提示 + 右侧「重试」按钮，点击触发 `onRetry`。
///
/// 刻意做成 public StatelessWidget 便于 widget 测试单独 pump，
/// 避免测试时必须伪造 `MomentFacade` 整条数据链。
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
    final t = context.t;
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.momentsFeedStale,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(t.buttonRetry)),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback? onDeleteTap;
  // 用于自动播放控制
  final void Function(String videoUrl)? onVideoVisible;

  const _MomentCard({
    required this.item,
    required this.canDelete,
    required this.onTap,
    required this.onLikeTap,
    this.onDeleteTap,
    this.onVideoVisible,
  });

  @override
  Widget build(BuildContext context) {
    final content = parseModelString(item['content']);
    final authorNickname = parseModelString(item['author_nickname']);
    final authorRemark = parseModelString(item['author_remark']);
    final authorAvatar = parseModelString(item['author_avatar']);
    final authorUid = parseModelString(item['author_uid']);
    final displayName = resolveMomentDisplayName(
      remark: authorRemark,
      nickname: authorNickname,
      uid: authorUid,
    );
    final createdAt = parseModelString(item['created_at']);
    final liked = parseModelBool(item['liked']);
    final stats = item['stats'] is Map
        ? Map<String, dynamic>.from(item['stats'] as Map)
        : const <String, dynamic>{};
    final likeCount = parseModelInt(stats['like_count']);
    final commentCount = parseModelInt(stats['comment_count']);
    final media = normalizeMedia(item['media']);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: authorAvatar.isNotEmpty
                      ? cachedImageProvider(authorAvatar, w: 36)
                      : null,
                  child: authorAvatar.isEmpty
                      ? Text(avatarInitialFrom(displayName))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (canDelete && onDeleteTap != null)
                  IconButton(
                    onPressed: onDeleteTap,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.t.delete,
                  ),
              ],
            ),
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(content),
              ),
            if (media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _MomentMediaPreview(
                  media: media,
                  onVideoVisible: onVideoVisible,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onLikeTap,
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.red : null,
                    ),
                  ),
                  Text(formatMomentCountLabel(likeCount)),
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline, size: 20),
                  const SizedBox(width: 4),
                  Text(formatMomentCountLabel(commentCount)),
                  const Spacer(),
                  Text(
                    createdAt,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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

class _MomentMediaPreview extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final void Function(String videoUrl)? onVideoVisible;

  const _MomentMediaPreview({required this.media, this.onVideoVisible});

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      final item = media.first;
      return _MomentMediaCell(
        item: item,
        size: 200,
        onVideoVisible: onVideoVisible,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: media
          .map((item) => _MomentMediaCell(item: item, size: 96))
          .toList(growable: false),
    );
  }
}

class _MomentMediaCell extends StatefulWidget {
  final Map<String, dynamic> item;
  final double size;
  final void Function(String videoUrl)? onVideoVisible;

  const _MomentMediaCell({
    required this.item,
    required this.size,
    this.onVideoVisible,
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

  void _disposeVideoController() {
    _videoController?.dispose();
    _videoController = null;
    if (mounted) setState(() => _isPlaying = false);
  }

  void _initVideoController(String url) {
    if (_videoController != null) return;

    // 使用 AssetsService.viewUrl 获取授权 URL
    final authorizedUrl = AssetsService.viewUrl(url);

    _videoController = VideoPlayerController.networkUrl(authorizedUrl)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      })
      ..setLooping(true)
      ..setVolume(0); // 默认静音播放
  }

  void _play() {
    if (_videoController != null && !_isPlaying) {
      _videoController!.play();
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  void _pause() {
    if (_videoController != null && _isPlaying) {
      _videoController!.pause();
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = parseModelString(widget.item['type']);
    final url = parseModelString(widget.item['url']);
    // 图片：直接用 url；视频：优先 cover_url，缺失时回退 url
    final previewUrl = pickMediaPreviewUrl(widget.item);
    final isVideo = type == 'video';

    if (!isVideo) {
      return Container(
        width: widget.size,
        height: widget.size,
        color: Colors.black12,
        child: previewUrl.isEmpty
            ? const Icon(Icons.broken_image_outlined)
            : OctoImage(
                image: cachedImageProvider(previewUrl),
                fit: BoxFit.cover,
                placeholderBuilder: (context) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorBuilder: (context, error, stacktrace) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      );
    }

    // 视频处理逻辑
    return VisibilityDetector(
      key: Key('video_$url'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.8) {
          // 80% 可见时初始化并播放
          _initVideoController(url);
          _play();
          widget.onVideoVisible?.call(url);
        } else if (info.visibleFraction < 0.2) {
          _pause();
          // 释放资源，避免内存泄漏
          _disposeVideoController();
        }
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_videoController != null &&
                _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            else
              // 视频加载前显示封面（cover_url，不是视频 URL）或黑屏
              previewUrl.isEmpty
                  ? const Icon(Icons.broken_image_outlined)
                  : OctoImage(
                      image: cachedImageProvider(previewUrl),
                      fit: BoxFit.cover,
                      width: widget.size,
                      height: widget.size,
                      placeholderBuilder: (context) => Shimmer.fromColors(
                        baseColor: Colors.grey[800]!,
                        highlightColor: Colors.grey[700]!,
                        child: Container(color: Colors.black),
                      ),
                      errorBuilder: (_, _, _) => Container(color: Colors.black),
                    ),

            // 播放状态指示器
            if (!_isPlaying)
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 30),

            // 静音图标提示
            if (_isPlaying)
              const Positioned(
                bottom: 8,
                right: 8,
                child: Icon(Icons.volume_off, color: Colors.white54, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

/// 朋友圈通知入口：铃铛图标 + 未读数红点徽章。
///
/// - 通过 [momentNotifyProvider] 订阅未读数，实时响应 S2C 推送；
/// - 点击跳转 `/moment_notify` 列表页（路由已注册）。
class _MomentNotifyEntry extends ConsumerWidget {
  const _MomentNotifyEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(momentNotifyProvider.select((s) => s.unreadCount));
    return IconButton(
      onPressed: () => context.push('/moment_notify'),
      tooltip: context.t.momentNotify.title,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unread > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: AppRadius.borderRadiusCell,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
