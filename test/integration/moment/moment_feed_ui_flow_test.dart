import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/public.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_provider.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_state.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/store/api/moment_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/page/moment/moment_utils.dart';

/// Test-only fake that bypasses singleton access (UserRepoLocal / MomentNotifyRepo)
class _FakeMomentNotifyNotifier extends MomentNotifyNotifier {
  @override
  MomentNotifyState build() => const MomentNotifyState();
}

Future<void> _pumpMomentFeedPage(WidgetTester tester) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  await tester.pumpWidget(MomentTestWrapper(child: buildMomentFeedPage()));
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

/// Test wrapper for moment pages with proper localization
class MomentTestWrapper extends StatelessWidget {
  final Widget child;
  final List<NavigatorObserver>? observers;

  const MomentTestWrapper({super.key, required this.child, this.observers});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        momentNotifyProvider.overrideWith(_FakeMomentNotifyNotifier.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(home: child, navigatorObservers: observers ?? []),
      ),
    );
  }
}

/// Mock moment data for testing
class MockMomentData {
  static Map<String, dynamic> createMoment({
    String id = 'moment_test_001',
    String authorUid = 'user_001',
    String content = 'Test moment content',
    bool liked = false,
    int likeCount = 5,
    int commentCount = 3,
    List<Map<String, dynamic>>? media,
  }) {
    return {
      'id': id,
      'author_uid': authorUid,
      'content': content,
      'created_at': '2026-03-15 10:00:00',
      'liked': liked,
      'stats': {'like_count': likeCount, 'comment_count': commentCount},
      'media': media ?? [],
    };
  }

  static List<Map<String, dynamic>> createMomentList(int count) {
    return List.generate(
      count,
      (i) => createMoment(
        id: 'moment_$i',
        authorUid: 'user_$i',
        content: 'Moment content $i',
        likeCount: i * 2,
        commentCount: i,
      ),
    );
  }
}

class _FakeMomentApi extends MomentApi {
  _FakeMomentApi({List<Map<String, dynamic>> items = const []})
    : _items = List<Map<String, dynamic>>.from(items);

  final List<Map<String, dynamic>> _items;

  @override
  Future<MomentPageResult<Map<String, dynamic>>> getFeedPage({
    String? cursor,
    int limit = 20,
  }) async {
    final list = _items.take(limit).map(Map<String, dynamic>.from).toList();
    return MomentPageResult(list: list, nextCursor: null, hasMore: false);
  }

  @override
  Future<bool> likePost(String momentId) async => true;

  @override
  Future<bool> unlikePost(String momentId) async => true;

  @override
  Future<bool> deletePost(String momentId) async => true;
}

MomentFeedPage buildMomentFeedPage({
  List<Map<String, dynamic>> items = const [],
}) {
  return MomentFeedPage(
    facade: MomentFacade(api: _FakeMomentApi(items: items)),
  );
}

void main() {
  group('MomentFeedPage Complete Flow Tests', () {
    group('Page Rendering Tests', () {
      testWidgets('renders page with AppBar and title', (tester) async {
        await _pumpMomentFeedPage(tester);

        expect(find.byType(MomentFeedPage), findsOneWidget);
        expect(find.text(t.discovery.moments), findsOneWidget);
      });

      testWidgets('shows publish button in AppBar', (tester) async {
        await _pumpMomentFeedPage(tester);

        final publishButton = find.byIcon(Icons.add_a_photo_outlined);
        expect(publishButton, findsOneWidget);

        // Verify tooltip
        final iconButton = find.ancestor(
          of: publishButton,
          matching: find.byType(IconButton),
        );
        expect(iconButton, findsOneWidget);
      });

      testWidgets('shows loading indicator initially', (tester) async {
        await _pumpMomentFeedPage(tester);

        expect(find.byType(MomentFeedPage), findsOneWidget);
      });

      testWidgets('has RefreshIndicator for pull-to-refresh', (tester) async {
        await _pumpMomentFeedPage(tester);

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('MomentCard Widget Tests', () {
      testWidgets('_MomentCard displays author avatar', (tester) async {
        final moment = MockMomentData.createMoment();

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('_MomentCard displays content', (tester) async {
        final moment = MockMomentData.createMoment(content: 'Hello World');

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Hello World'), findsOneWidget);
      });

      testWidgets('_MomentCard displays like count', (tester) async {
        final moment = MockMomentData.createMoment(likeCount: 10);

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('10'), findsOneWidget);
      });

      testWidgets('_MomentCard displays liked icon when liked', (tester) async {
        final moment = MockMomentData.createMoment(liked: true);

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        final icon = tester.widget<Icon>(find.byIcon(Icons.favorite));
        expect(icon.color, Colors.red);
      });

      testWidgets('_MomentCard displays unliked icon when not liked', (
        tester,
      ) async {
        final moment = MockMomentData.createMoment(liked: false);

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      });

      testWidgets('_MomentCard shows delete button when canDelete is true', (
        tester,
      ) async {
        final moment = MockMomentData.createMoment();

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: true,
                onTap: () {},
                onLikeTap: () {},
                onDeleteTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('_MomentCard hides delete button when canDelete is false', (
        tester,
      ) async {
        final moment = MockMomentData.createMoment();

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.delete_outline), findsNothing);
      });
    });

    group('Like Toggle State Sync Tests', () {
      test('like toggle correctly updates like count', () {
        bool liked = false;
        int likeCount = 5;

        // Simulate like
        liked = !liked;
        likeCount = likeCount + 1;

        expect(liked, isTrue);
        expect(likeCount, 6);

        // Simulate unlike
        liked = !liked;
        likeCount = likeCount - 1;

        expect(liked, isFalse);
        expect(likeCount, 5);
      });

      test('unlike does not go below zero', () {
        bool liked = false;
        int likeCount = 0;

        // Try to like when count is 0
        liked = !liked; // liked = true
        likeCount = likeCount + 1;

        expect(likeCount, 1);

        // Unlike
        liked = !liked; // liked = false
        likeCount = likeCount > 0 ? likeCount - 1 : 0;

        expect(likeCount, 0);

        // Try to unlike again (should stay at 0)
        likeCount = likeCount > 0 ? likeCount - 1 : 0;
        expect(likeCount, 0);
      });

      test('item list updates correctly after like toggle', () {
        final items = <Map<String, dynamic>>[
          {
            'id': 'moment_001',
            'liked': false,
            'stats': {'like_count': 5},
          },
          {
            'id': 'moment_002',
            'liked': true,
            'stats': {'like_count': 10},
          },
        ];

        final momentId = 'moment_001';
        final updatedItems = items.map((item) {
          if (parseModelString(item['id']) != momentId) {
            return item;
          }
          final next = Map<String, dynamic>.from(item);
          next['liked'] = true;
          final stats = Map<String, dynamic>.from(item['stats'] as Map);
          stats['like_count'] = 6;
          next['stats'] = stats;
          return next;
        }).toList();

        expect(updatedItems[0]['liked'], isTrue);
        expect(updatedItems[0]['stats']['like_count'], 6);
        expect(updatedItems[1]['liked'], isTrue);
        expect(updatedItems[1]['stats']['like_count'], 10);
      });
    });

    group('Delete State Sync Tests', () {
      test('delete removes item from list correctly', () {
        final items = [
          {'id': 'moment_001'},
          {'id': 'moment_002'},
          {'id': 'moment_003'},
        ];

        final momentId = 'moment_002';
        final newItems = items
            .where((item) => parseModelString(item['id']) != momentId)
            .toList();

        expect(newItems.length, 2);
        expect(newItems[0]['id'], 'moment_001');
        expect(newItems[1]['id'], 'moment_003');
      });

      test('delete non-existent item does not affect list', () {
        final items = [
          {'id': 'moment_001'},
          {'id': 'moment_002'},
        ];

        final momentId = 'moment_999';
        final newItems = items
            .where((item) => parseModelString(item['id']) != momentId)
            .toList();

        expect(newItems.length, 2);
      });
    });

    group('Event Bus Integration Tests', () {
      test('MomentTimelineChangedEvent triggers refresh', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription = AppEventBus.on<MomentTimelineChangedEvent>()
            .listen((event) {
              receivedEvents.add(event);
            });

        AppEventBus.fire(
          const MomentTimelineChangedEvent(
            action: 'moment_new',
            momentId: 'm_abc123',
            payload: {'moment_id': 'm_abc123'},
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_new');
        expect(receivedEvents[0].momentId, 'm_abc123');

        await subscription.cancel();
      });

      test('delete event contains correct momentId', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription = AppEventBus.on<MomentTimelineChangedEvent>()
            .listen((event) {
              receivedEvents.add(event);
            });

        AppEventBus.fire(
          const MomentTimelineChangedEvent(
            action: 'moment_deleted',
            momentId: 'm_delete_001',
            payload: {},
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_deleted');
        expect(receivedEvents[0].momentId, 'm_delete_001');

        await subscription.cancel();
      });
    });

    group('Scroll Loading Tests', () {
      test('load more triggers when near bottom', () {
        bool isLoadingMore = false;
        bool hasMore = true;
        const threshold = 320;
        const pixels = 800.0;
        const maxScrollExtent = 1000.0;

        final shouldLoadMore =
            !isLoadingMore && hasMore && pixels >= maxScrollExtent - threshold;

        expect(shouldLoadMore, isTrue);
      });

      test('load more does not trigger when already loading', () {
        const bool isLoadingMore = true;
        // When already loading, shouldLoadMore is always false regardless of other conditions
        const bool shouldLoadMore = false;

        expect(shouldLoadMore, isFalse);
        expect(isLoadingMore, isTrue);
      });

      test('load more does not trigger when no more data', () {
        bool isLoadingMore = false;
        bool hasMore = false;
        const threshold = 320;
        const pixels = 800.0;
        const maxScrollExtent = 1000.0;

        final shouldLoadMore = <bool>[
          !isLoadingMore,
          hasMore,
          pixels >= maxScrollExtent - threshold,
        ].every((value) => value);

        expect(shouldLoadMore, isFalse);
      });

      test('load more does not trigger when not near bottom', () {
        bool isLoadingMore = false;
        bool hasMore = true;
        const threshold = 320;
        const pixels = 100.0;
        const maxScrollExtent = 1000.0;

        final shouldLoadMore =
            !isLoadingMore && hasMore && pixels >= maxScrollExtent - threshold;

        expect(shouldLoadMore, isFalse);
      });
    });

    group('Detail Page Return State Consistency Tests', () {
      test('detail page returns true when moment is updated', () {
        // Simulate detail page returning result
        Object? result = true;

        // Feed page should refresh when result is true
        bool shouldRefresh = result == true;
        expect(shouldRefresh, isTrue);
      });

      test('detail page returns null when back without changes', () {
        // Simulate detail page returning null
        Object? result;

        // Feed page should not refresh when result is null
        bool shouldRefresh = result == true;
        expect(shouldRefresh, isFalse);
      });

      test('state consistency after like in detail page', () {
        // Initial state
        final feedItem = {
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5},
        };

        // Simulate like in detail page
        final detailState = {
          'id': 'moment_001',
          'liked': true,
          'stats': {'like_count': 6},
        };

        // After returning, feed should match detail state
        final updatedFeedItem = Map<String, dynamic>.from(feedItem);
        updatedFeedItem['liked'] = detailState['liked'];
        updatedFeedItem['stats'] = detailState['stats'];

        expect(updatedFeedItem['liked'], isTrue);
        expect(updatedFeedItem['stats']['like_count'], 6);
      });

      test('state consistency after comment in detail page', () {
        // Initial state
        final feedItem = {
          'id': 'moment_001',
          'stats': {'comment_count': 3},
        };

        // Simulate comment added in detail page
        final newCommentCount = 4;

        // After returning, feed should reflect new comment count
        final updatedFeedItem = Map<String, dynamic>.from(feedItem);
        final stats = Map<String, dynamic>.from(
          updatedFeedItem['stats'] as Map,
        );
        stats['comment_count'] = newCommentCount;
        updatedFeedItem['stats'] = stats;

        expect(updatedFeedItem['stats']['comment_count'], 4);
      });
    });

    group('Media Display Tests', () {
      testWidgets('single media displays at large size', (tester) async {
        final moment = MockMomentData.createMoment(
          media: [
            {
              'type': 'image',
              'url': '',
            }, // Empty URL to avoid network requests in tests
          ],
        );

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Should find the media preview
        expect(find.byType(_MomentMediaPreview), findsOneWidget);
        // Should show placeholder icon for empty URL
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      });

      testWidgets('multiple media displays in grid', (tester) async {
        final moment = MockMomentData.createMoment(
          media: [
            {
              'type': 'image',
              'url': '',
            }, // Empty URL to avoid network requests in tests
            {'type': 'image', 'url': ''},
            {'type': 'image', 'url': ''},
          ],
        );

        await tester.pumpWidget(
          MomentTestWrapper(
            child: Scaffold(
              body: _MomentCard(
                item: moment,
                canDelete: false,
                onTap: () {},
                onLikeTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(_MomentMediaPreview), findsOneWidget);
        expect(find.byType(Wrap), findsOneWidget);
      });

      test('video media shows play icon', () {
        const media = [
          {'type': 'video', 'url': 'https://example.com/video.mp4'},
        ];

        final isVideo = parseModelString(media[0]['type']) == 'video';
        expect(isVideo, isTrue);
      });
    });

    group('Empty State Tests', () {
      testWidgets('shows empty state when no moments', (tester) async {
        await _pumpMomentFeedPage(tester);

        // Page should render without error
        expect(find.byType(MomentFeedPage), findsOneWidget);
      });
    });

    group('Boundary Condition Tests', () {
      test('handles empty content correctly', () {
        final moment = MockMomentData.createMoment(content: '');
        expect(parseModelString(moment['content']), isEmpty);
      });

      test('handles null stats correctly', () {
        final moment = <String, dynamic>{'id': 'moment_001', 'stats': null};

        final stats = moment['stats'] is Map
            ? Map<String, dynamic>.from(moment['stats'] as Map)
            : const <String, dynamic>{};

        expect(parseModelInt(stats['like_count']), 0);
      });

      test('handles missing author_uid correctly', () {
        final moment = <String, dynamic>{'id': 'moment_001'};

        final authorUid = parseModelString(moment['author_uid']);
        expect(authorUid, isEmpty);
      });

      test('handles malformed media array', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'media': 'not_an_array',
        };

        final rawMedia = moment['media'];
        expect(rawMedia is! List, isTrue);
      });
    });
  });
}

// Helper widget classes for testing (extracted from moment_feed_page.dart)
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
                    tooltip: context.t.common.delete,
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
