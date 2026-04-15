import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart'; // 引入 cachedImageProvider
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/assets.dart'; // 引入 AssetsService
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:octo_image/octo_image.dart';

import 'moment_interactions.dart';
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

  StreamSubscription<MomentTimelineChangedEvent>? _momentSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _momentSub = AppEventBus.on<MomentTimelineChangedEvent>().listen((_) {
      _refresh();
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
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) return;
    _loadMore();
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final page = await _api.getFeedPage(limit: 20);
    if (!mounted) return;
    final enriched = await enrichItemsWithAuthor(page.list);
    if (!mounted) return;
    setState(() {
      _items = enriched;
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final page = await _api.getFeedPage(limit: 20);
    if (!mounted) return;
    final enriched = await enrichItemsWithAuthor(page.list);
    if (!mounted) return;
    setState(() {
      _items = enriched;
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t.delete),
          content: Text(t.momentsDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.buttonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.confirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

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
    final result = await context.push(AppRoutes.momentCreate);
    if (!mounted) return;
    if (result == true) {
      await _refresh();
    }
  }

  Future<void> _openDetail(String momentId) async {
    if (momentId.isEmpty) return;
    final result = await context.push('${AppRoutes.momentRoot}/$momentId');
    if (!mounted) return;
    if (result == true) {
      await _refresh();
    }
  }


  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.moments),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: t.momentsSend,
          ),
        ],
      ),
      body: _isLoading
          ? const ShimmerList(itemHeight: 140)
          : RefreshIndicator(
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
                        final canDelete = canDeleteMoment(item, currentUid);
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
  final Function(String videoUrl)? onVideoVisible;

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
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName.substring(0, 1)
                              : '?',
                        )
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
  final Function(String videoUrl)? onVideoVisible;

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
  final Function(String videoUrl)? onVideoVisible;

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
    final isVideo = type == 'video';

    if (!isVideo) {
      return Container(
        width: widget.size,
        height: widget.size,
        color: Colors.black12,
        child: url.isEmpty
            ? const Icon(Icons.broken_image_outlined)
            : OctoImage(
                image: cachedImageProvider(url),
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
              // 视频加载前显示缩略图（如果有）或黑屏
              url.isEmpty
                  ? const Icon(Icons.broken_image_outlined)
                  : OctoImage(
                      image: cachedImageProvider(url), // 很多时候视频URL也是封面图URL
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
