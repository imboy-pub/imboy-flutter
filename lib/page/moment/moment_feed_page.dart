import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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

/// 朋友圈页面 - iOS 17 Premium 风格重构
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
  bool _isStale = false;

  StreamSubscription<MomentTimelineChangedEvent>? _momentSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _momentSub = AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
      if (shouldRefreshFeedOnEvent(event.action)) _refresh();
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

  Future<void> _refresh() async => await _fetchFirstPage();

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
      remoteEnriched = null;
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
    if (_cursor == null || _cursor!.isEmpty || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
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
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> moment) async {
    final momentId = parseModelString(moment['id']);
    if (momentId.isEmpty) return;
    final liked = parseModelBool(moment['liked']);
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
        EasyLoading.showError(t.common.momentsDeleteFailed);
      }
    } catch (_) {
      if (mounted) setState(() => _items = oldItems);
    }
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
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= _items.length) {
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
                    onLikeTap: () => _toggleLike(item),
                    onDeleteTap: canDelete ? () => _deleteMoment(item) : null,
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
            }, childCount: _items.length + (_isLoadingMore ? 1 : 0)),
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

class _MomentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback? onDeleteTap;
  const _MomentCard({
    required this.item,
    required this.canDelete,
    required this.onTap,
    required this.onLikeTap,
    this.onDeleteTap,
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(imgUri: authorAvatar, width: 44, height: 44),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayName,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.wechatBlue,
                        ),
                      ),
                      if (canDelete && onDeleteTap != null)
                        IconButton(
                          onPressed: onDeleteTap,
                          icon: const Icon(
                            CupertinoIcons.delete,
                            size: 16,
                            color: AppColors.iosGray,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  if (parseModelString(item['content']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        parseModelString(item['content']),
                        style: context
                            .textStyle(FontSizeType.subheadline)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  if (media.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _MomentMediaPreview(media: media),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Text(
                          parseModelString(item['created_at']),
                          style: context.textStyle(
                            FontSizeType.small,
                            color: AppColors.iosGray,
                          ),
                        ),
                        const Spacer(),
                        _buildInteractionButton(
                          CupertinoIcons.heart,
                          parseModelInt(stats['like_count']),
                          parseModelBool(item['liked'])
                              ? AppColors.iosRed
                              : AppColors.iosGray,
                          onLikeTap,
                        ),
                        AppSpacing.horizontalLarge,
                        _buildInteractionButton(
                          CupertinoIcons.chat_bubble,
                          parseModelInt(stats['comment_count']),
                          AppColors.iosGray,
                          onTap,
                        ),
                      ],
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

  Widget _buildInteractionButton(
    IconData icon,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  formatMomentCountLabel(count),
                  style: TextStyle(
                    fontSize: FontSizeType.small.size,
                    color: color,
                    fontWeight: FontWeight.w500,
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
      return _MomentMediaCell(
        item: media.first,
        size: 200,
        imageUrls: isVideo ? const [] : imageUrls,
        imageIndex: 0,
      );
    }
    int imgIdx = 0;
    final cellSize = (MediaQuery.of(context).size.width - 100) / 3;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
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
    // object_key 经后端换取短时 presigned URL；legacy 完整 URL 走旧授权。
    final String resolved = await AssetUrlResolver.instance.resolveForDisplay(
      url,
    );
    if (!mounted || _videoController != null) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(resolved))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      })
      ..setLooping(true)
      ..setVolume(0);
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
            borderRadius: BorderRadius.circular(8),
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
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.8) {
          _initVideoController(parseModelString(widget.item['url']));
          _videoController?.play();
          setState(() => _isPlaying = true);
        } else if (info.visibleFraction < 0.2) {
          _videoController?.pause();
          _videoController?.dispose();
          _videoController = null;
          setState(() => _isPlaying = false);
        }
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // 视频播放衬底，保留纯黑以贴合播放器视觉
          color: Colors.black,
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
          ],
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
    return CupertinoButton(
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
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    );
  }
}
