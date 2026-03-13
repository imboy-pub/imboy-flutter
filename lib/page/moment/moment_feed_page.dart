import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/moment_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MomentFeedPage extends StatefulWidget {
  const MomentFeedPage({super.key});

  @override
  State<MomentFeedPage> createState() => _MomentFeedPageState();
}

class _MomentFeedPageState extends State<MomentFeedPage> {
  final MomentApi _api = MomentApi();
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
    setState(() {
      _items = page.list;
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    final page = await _api.getFeedPage(limit: 20);
    if (!mounted) return;
    setState(() {
      _items = page.list;
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
    setState(() {
      _items = [..._items, ...page.list];
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
      _isLoadingMore = false;
    });
  }

  Future<void> _toggleLike(Map<String, dynamic> moment) async {
    final momentId = parseModelString(moment['id']);
    if (momentId.isEmpty) return;
    final liked = parseModelBool(moment['liked']);
    final ok = liked
        ? await _api.unlikePost(momentId)
        : await _api.likePost(momentId);
    if (!ok) return;

    final stats = Map<String, dynamic>.from(
      (moment['stats'] is Map) ? moment['stats'] as Map : <String, dynamic>{},
    );
    final likeCount = parseModelInt(stats['like_count']);
    final nextLikeCount = liked
        ? (likeCount > 0 ? likeCount - 1 : 0)
        : likeCount + 1;
    stats['like_count'] = nextLikeCount;

    if (!mounted) return;
    setState(() {
      _items = _items
          .map((item) {
            if (parseModelString(item['id']) != momentId) {
              return item;
            }
            final next = Map<String, dynamic>.from(item);
            next['liked'] = !liked;
            next['stats'] = stats;
            return next;
          })
          .toList(growable: false);
    });
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
          content: const Text('确定删除这条动态吗？'),
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
    if (confirmed != true) return;

    final ok = await _api.deletePost(momentId);
    if (!ok || !mounted) return;
    setState(() {
      _items = _items
          .where((item) => parseModelString(item['id']) != momentId)
          .toList(growable: false);
    });
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
    if (result == true) {
      await _refresh();
    }
  }

  Future<void> _openDetail(String momentId) async {
    if (momentId.isEmpty) return;
    final result = await context.push('${AppRoutes.momentRoot}/$momentId');
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
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 220),
                        Center(child: Text('暂无动态')),
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
                        final currentUid = UserRepoLocal.to.current.uid;
                        final canDelete =
                            parseModelString(item['author_uid']) == currentUid;
                        return _MomentCard(
                          item: item,
                          canDelete: canDelete,
                          onTap: () =>
                              _openDetail(parseModelString(item['id'])),
                          onLikeTap: () => _toggleLike(item),
                          onDeleteTap: canDelete
                              ? () => _deleteMoment(item)
                              : null,
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

  const _MomentCard({
    required this.item,
    required this.canDelete,
    required this.onTap,
    required this.onLikeTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = parseModelString(item['content']);
    final authorUid = parseModelString(item['author_uid']);
    final createdAt = parseModelString(item['created_at']);
    final liked = parseModelBool(item['liked']);
    final stats = item['stats'] is Map
        ? Map<String, dynamic>.from(item['stats'] as Map)
        : const <String, dynamic>{};
    final likeCount = parseModelInt(stats['like_count']);
    final commentCount = parseModelInt(stats['comment_count']);
    final media = _normalizeMedia(item['media']);

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
                  child: Text(
                    authorUid.isNotEmpty ? authorUid.substring(0, 1) : '?',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'UID: $authorUid',
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
                child: _MomentMediaPreview(media: media),
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
                  Text('$likeCount'),
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline, size: 20),
                  const SizedBox(width: 4),
                  Text('$commentCount'),
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

  const _MomentMediaPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      final item = media.first;
      return _MomentMediaCell(item: item, size: 200);
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

class _MomentMediaCell extends StatelessWidget {
  final Map<String, dynamic> item;
  final double size;

  const _MomentMediaCell({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    final type = parseModelString(item['type']);
    final url = parseModelString(item['url']);
    final isVideo = type == 'video';

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          color: Colors.black12,
          child: url.isEmpty
              ? const Icon(Icons.broken_image_outlined)
              : Image.network(url, fit: BoxFit.cover),
        ),
        if (isVideo)
          const Positioned.fill(
            child: Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }
}

List<Map<String, dynamic>> _normalizeMedia(dynamic rawMedia) {
  if (rawMedia is! List) return const [];
  return rawMedia
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
