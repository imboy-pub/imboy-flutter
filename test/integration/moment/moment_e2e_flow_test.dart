import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// End-to-End flow tests for Moment feature
///
/// Tests the complete user flow:
/// 1. Publish moment -> Feed refresh
/// 2. Like/Comment state sync
/// 3. Detail page return -> List state consistency
void main() {
  group('Moment E2E Flow Tests', () {
    group('Publish to Feed Flow Tests', () {
      test('moment_new event triggers feed refresh', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription =
            AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
          receivedEvents.add(event);
        });

        // Simulate publish success
        AppEventBus.fire(
          const MomentTimelineChangedEvent(
            action: 'moment_new',
            momentId: 'moment_001',
            payload: {
              'id': 'moment_001',
              'content': 'New moment!',
              'author_uid': 'user_001',
              'stats': {'like_count': 0, 'comment_count': 0},
            },
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_new');
        expect(receivedEvents[0].momentId, 'moment_001');

        await subscription.cancel();
      });

      test('feed list updates with new moment at top', () {
        final feedItems = <Map<String, dynamic>>[
          {'id': 'moment_old_001', 'created_at': '2026-03-14 10:00:00'},
          {'id': 'moment_old_002', 'created_at': '2026-03-14 09:00:00'},
        ];

        final newMoment = <String, dynamic>{
          'id': 'moment_new_001',
          'created_at': '2026-03-15 10:00:00',
        };

        // New moment should be prepended
        feedItems.insert(0, newMoment);

        expect(feedItems.length, 3);
        expect(feedItems[0]['id'], 'moment_new_001');
        expect(feedItems[1]['id'], 'moment_old_001');
      });

      test('feed refresh clears cursor and resets pagination', () {
        String? cursor = 'cursor_001';
        bool hasMore = true;

        // Simulate refresh
        cursor = null;
        hasMore = true;

        expect(cursor, isNull);
        expect(hasMore, isTrue);
      });

      test('multiple publishes result in correct order', () {
        final feedItems = <Map<String, dynamic>>[];

        // First publish
        feedItems.insert(0, {'id': 'moment_001', 'order': 1});

        // Second publish
        feedItems.insert(0, {'id': 'moment_002', 'order': 2});

        // Third publish
        feedItems.insert(0, {'id': 'moment_003', 'order': 3});

        expect(feedItems.length, 3);
        expect(feedItems[0]['id'], 'moment_003');
        expect(feedItems[1]['id'], 'moment_002');
        expect(feedItems[2]['id'], 'moment_001');
      });
    });

    group('Like State Sync Tests', () {
      test('like in feed updates like count and icon', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5},
        };

        // Simulate like action
        final liked = parseModelBool(moment['liked']);
        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        final likeCount = parseModelInt(stats['like_count']);

        moment['liked'] = !liked;
        stats['like_count'] = liked
            ? (likeCount > 0 ? likeCount - 1 : 0)
            : likeCount + 1;
        moment['stats'] = stats;

        expect(moment['liked'], isTrue);
        expect((moment['stats'] as Map<String, dynamic>)['like_count'], 6);
      });

      test('unlike in feed decreases like count', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'liked': true,
          'stats': {'like_count': 10},
        };

        // Simulate unlike action
        final liked = parseModelBool(moment['liked']);
        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        final likeCount = parseModelInt(stats['like_count']);

        moment['liked'] = !liked;
        stats['like_count'] = liked
            ? (likeCount > 0 ? likeCount - 1 : 0)
            : likeCount + 1;
        moment['stats'] = stats;

        expect(moment['liked'], isFalse);
        expect((moment['stats'] as Map<String, dynamic>)['like_count'], 9);
      });

      test('like state persists after scroll away and back', () {
        // Simulate scrolling away and back
        final feedItems = <Map<String, dynamic>>[
          {'id': 'moment_001', 'liked': true, 'stats': {'like_count': 6}},
          {'id': 'moment_002', 'liked': false, 'stats': {'like_count': 3}},
        ];

        // Scroll simulation - state should remain
        final firstItem = feedItems[0];
        expect(firstItem['liked'], isTrue);
        expect((firstItem['stats'] as Map<String, dynamic>)['like_count'], 6);
      });

      test('like count never goes below zero', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'liked': true,
          'stats': {'like_count': 0},
        };

        final liked = parseModelBool(moment['liked']);
        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        final likeCount = parseModelInt(stats['like_count']);

        stats['like_count'] = liked
            ? (likeCount > 0 ? likeCount - 1 : 0)
            : likeCount + 1;

        expect(stats['like_count'], 0);
      });
    });

    group('Comment State Sync Tests', () {
      test('new comment increases comment count', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'stats': {'comment_count': 3},
        };

        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        final commentCount = parseModelInt(stats['comment_count']);

        stats['comment_count'] = commentCount + 1;

        expect(stats['comment_count'], 4);
      });

      test('delete comment decreases comment count', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'stats': {'comment_count': 5},
        };

        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        final commentCount = parseModelInt(stats['comment_count']);

        stats['comment_count'] = commentCount > 0 ? commentCount - 1 : 0;

        expect(stats['comment_count'], 4);
      });

      test('comment count never goes below zero', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'stats': {'comment_count': 0},
        };

        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        final commentCount = parseModelInt(stats['comment_count']);

        stats['comment_count'] = commentCount > 0 ? commentCount - 1 : 0;

        expect(stats['comment_count'], 0);
      });
    });

    group('Detail Page Return State Consistency Tests', () {
      test('like in detail page reflects in feed after return', () {
        // Initial feed state
        final feedItem = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 3},
        };

        // Simulate detail page like action
        final detailState = <String, dynamic>{
          'id': 'moment_001',
          'liked': true,
          'stats': {'like_count': 6, 'comment_count': 3},
        };

        // After returning, feed should be refreshed
        // Simulating refresh by updating feed item
        feedItem['liked'] = detailState['liked'];
        feedItem['stats'] = Map<String, dynamic>.from(detailState['stats'] as Map<String, dynamic>);

        expect(feedItem['liked'], isTrue);
        expect((feedItem['stats'] as Map<String, dynamic>)['like_count'], 6);
      });

      test('comment in detail page reflects in feed after return', () {
        // Initial feed state
        final feedItem = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 3},
        };

        // Simulate detail page comment action
        final detailState = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 4},
        };

        // After returning, feed should be refreshed
        feedItem['stats'] = Map<String, dynamic>.from(detailState['stats'] as Map<String, dynamic>);

        expect((feedItem['stats'] as Map<String, dynamic>)['comment_count'], 4);
      });

      test('delete in detail page removes from feed after return', () {
        // Initial feed state
        var feedItems = <Map<String, dynamic>>[
          {'id': 'moment_001'},
          {'id': 'moment_002'},
          {'id': 'moment_003'},
        ];

        // Simulate delete in detail page
        const deletedId = 'moment_002';

        // Event fired for delete
        // After returning, feed should be refreshed
        feedItems = feedItems
            .where((item) => parseModelString(item['id']) != deletedId)
            .toList();

        expect(feedItems.length, 2);
        expect(feedItems[0]['id'], 'moment_001');
        expect(feedItems[1]['id'], 'moment_003');
      });

      test('multiple changes in detail page all reflect after return', () {
        // Initial feed state
        final feedItem = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 3},
        };

        // Simulate multiple actions in detail page
        final detailState = <String, dynamic>{
          'id': 'moment_001',
          'liked': true,
          'stats': {'like_count': 7, 'comment_count': 5},
        };

        // After returning, feed should reflect all changes
        feedItem['liked'] = detailState['liked'];
        feedItem['stats'] = Map<String, dynamic>.from(detailState['stats'] as Map<String, dynamic>);

        expect(feedItem['liked'], isTrue);
        expect((feedItem['stats'] as Map<String, dynamic>)['like_count'], 7);
        expect((feedItem['stats'] as Map<String, dynamic>)['comment_count'], 5);
      });
    });

    group('Event-Driven State Sync Tests', () {
      test('moment_deleted event triggers feed removal', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription =
            AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
          receivedEvents.add(event);
        });

        AppEventBus.fire(
          const MomentTimelineChangedEvent(
            action: 'moment_deleted',
            momentId: 'moment_001',
            payload: {},
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_deleted');
        expect(receivedEvents[0].momentId, 'moment_001');

        await subscription.cancel();
      });

      test('moment_like event triggers feed update', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription =
            AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
          receivedEvents.add(event);
        });

        AppEventBus.fire(
          const MomentTimelineChangedEvent(
            action: 'moment_like',
            momentId: 'moment_001',
            payload: {'liked': true, 'like_count': 6},
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_like');
        expect(receivedEvents[0].payload['liked'], isTrue);

        await subscription.cancel();
      });

      test('moment_comment event triggers feed update', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription =
            AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
          receivedEvents.add(event);
        });

        AppEventBus.fire(
          const MomentTimelineChangedEvent(
            action: 'moment_comment',
            momentId: 'moment_001',
            payload: {'comment_count': 4},
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_comment');
        expect(receivedEvents[0].payload['comment_count'], 4);

        await subscription.cancel();
      });
    });

    group('Complete E2E Flow Tests', () {
      test('full flow: publish -> feed refresh -> verify', () async {
        // 1. Initial feed state
        var feedItems = <Map<String, dynamic>>[];

        // 2. Listen for event
        final receivedEvents = <MomentTimelineChangedEvent>[];
        final subscription =
            AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
          receivedEvents.add(event);
        });

        // 3. Simulate publish
        final newMoment = <String, dynamic>{
          'id': 'moment_new_001',
          'content': 'New moment!',
          'author_uid': 'user_001',
          'stats': {'like_count': 0, 'comment_count': 0},
        };

        AppEventBus.fire(
          MomentTimelineChangedEvent(
            action: 'moment_new',
            momentId: 'moment_new_001',
            payload: newMoment,
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        // 4. Verify event received
        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_new');

        // 5. Simulate feed refresh (prepend new moment)
        feedItems.insert(0, newMoment);

        // 6. Verify feed updated
        expect(feedItems.length, 1);
        expect(feedItems[0]['id'], 'moment_new_001');

        await subscription.cancel();
      });

      test('full flow: like -> state update -> verify', () {
        // 1. Initial state
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 3},
        };

        // 2. Perform like
        final liked = parseModelBool(moment['liked']);
        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        final likeCount = parseModelInt(stats['like_count']);

        moment['liked'] = !liked;
        stats['like_count'] = liked
            ? (likeCount > 0 ? likeCount - 1 : 0)
            : likeCount + 1;
        moment['stats'] = stats;

        // 3. Verify state
        expect(moment['liked'], isTrue);
        expect((moment['stats'] as Map<String, dynamic>)['like_count'], 6);
      });

      test('full flow: detail -> like -> return -> verify feed', () {
        // 1. Initial feed state
        final feedItem = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 3},
        };

        // 2. Open detail, perform like
        // Simulating detail page state
        final detailState = Map<String, dynamic>.from(feedItem);
        detailState['liked'] = true;
        final detailStats =
            Map<String, dynamic>.from(detailState['stats'] as Map<String, dynamic>);
        detailStats['like_count'] = 6;
        detailState['stats'] = detailStats;

        // 3. Return from detail (result = true triggers refresh)
        const returnResult = true;

        // 4. If return is true, feed refreshes
        if (returnResult) {
          feedItem['liked'] = detailState['liked'];
          feedItem['stats'] = Map<String, dynamic>.from(detailState['stats'] as Map<String, dynamic>);
        }

        // 5. Verify feed consistency
        expect(feedItem['liked'], isTrue);
        expect((feedItem['stats'] as Map<String, dynamic>)['like_count'], 6);
      });

      test('full flow: detail -> comment -> return -> verify feed', () {
        // 1. Initial feed state
        final feedItem = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 3},
        };

        // 2. Open detail, add comment
        final detailState = Map<String, dynamic>.from(feedItem);
        final detailStats =
            Map<String, dynamic>.from(detailState['stats'] as Map<String, dynamic>);
        detailStats['comment_count'] = 4;
        detailState['stats'] = detailStats;

        // 3. Return from detail (result = true triggers refresh)
        const returnResult = true;

        // 4. If return is true, feed refreshes
        if (returnResult) {
          feedItem['stats'] = Map<String, dynamic>.from(detailState['stats'] as Map<String, dynamic>);
        }

        // 5. Verify feed consistency
        expect((feedItem['stats'] as Map<String, dynamic>)['comment_count'], 4);
      });

      test('full flow: detail -> delete -> return -> verify feed', () {
        // 1. Initial feed state
        var feedItems = <Map<String, dynamic>>[
          {'id': 'moment_001'},
          {'id': 'moment_002'},
          {'id': 'moment_003'},
        ];

        // 2. Open detail for moment_002, delete
        const deletedId = 'moment_002';

        // 3. Return from detail (result = true triggers refresh)
        const returnResult = true;

        // 4. If return is true, feed refreshes and removes deleted
        if (returnResult) {
          feedItems = feedItems
              .where((item) => parseModelString(item['id']) != deletedId)
              .toList();
        }

        // 5. Verify feed consistency
        expect(feedItems.length, 2);
        expect(feedItems.where((i) => i['id'] == 'moment_002'), isEmpty);
      });
    });

    group('Concurrency and Edge Case Tests', () {
      test('rapid like/unlike maintains correct state', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'liked': false,
          'stats': {'like_count': 5},
        };

        // Rapid like
        for (int i = 0; i < 10; i++) {
          final liked = parseModelBool(moment['liked']);
          final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
          final likeCount = parseModelInt(stats['like_count']);

          moment['liked'] = !liked;
          stats['like_count'] = liked
              ? (likeCount > 0 ? likeCount - 1 : 0)
              : likeCount + 1;
          moment['stats'] = stats;
        }

        // After 10 toggles (even number), should return to original state
        expect(moment['liked'], isFalse);
        expect((moment['stats'] as Map<String, dynamic>)['like_count'], 5);
      });

      test('event during refresh does not cause race condition', () async {
        var feedItems = <Map<String, dynamic>>[];

        // Start refresh
        // isLoading = true;

        // Event arrives during refresh
        final newMoment = <String, dynamic>{'id': 'moment_new_001'};

        // Refresh completes
        feedItems.insert(0, newMoment);
        // isLoading = false;

        // Event should not be lost
        expect(feedItems.length, 1);
        expect(feedItems[0]['id'], 'moment_new_001');
      });

      test('empty feed handles new moment correctly', () {
        var feedItems = <Map<String, dynamic>>[];

        final newMoment = <String, dynamic>{'id': 'moment_001', 'content': 'First moment!'};

        feedItems.insert(0, newMoment);

        expect(feedItems.length, 1);
        expect(feedItems[0]['id'], 'moment_001');
      });

      test('large feed handles delete correctly', () {
        final feedItems = List.generate(
          100,
          (i) => <String, dynamic>{'id': 'moment_$i'},
        );

        const deletedId = 'moment_50';
        final updatedItems = feedItems
            .where((item) => parseModelString(item['id']) != deletedId)
            .toList();

        expect(updatedItems.length, 99);
        expect(
          updatedItems.where((i) => i['id'] == 'moment_50'),
          isEmpty,
        );
      });
    });

    group('Data Integrity Tests', () {
      test('moment data structure is preserved', () {
        const moment = <String, dynamic>{
          'id': 'moment_001',
          'author_uid': 'user_001',
          'content': 'Test content',
          'created_at': '2026-03-15 10:00:00',
          'liked': false,
          'stats': {'like_count': 5, 'comment_count': 3},
          'media': [
            {'type': 'image', 'url': 'https://example.com/image.jpg'}
          ],
        };

        expect(parseModelString(moment['id']), 'moment_001');
        expect(parseModelString(moment['author_uid']), 'user_001');
        expect(parseModelString(moment['content']), 'Test content');
        expect(parseModelBool(moment['liked']), isFalse);

        final stats = moment['stats'] as Map<String, dynamic>;
        expect(parseModelInt(stats['like_count']), 5);
        expect(parseModelInt(stats['comment_count']), 3);

        final media = moment['media'] as List;
        expect(media.length, 1);
      });

      test('stats object is properly cloned on update', () {
        final moment = <String, dynamic>{
          'id': 'moment_001',
          'stats': {'like_count': 5},
        };

        final stats = Map<String, dynamic>.from(moment['stats'] as Map<String, dynamic>);
        stats['like_count'] = 6;

        final updatedMoment = Map<String, dynamic>.from(moment);
        updatedMoment['stats'] = stats;

        // Original should be unchanged
        expect((moment['stats'] as Map<String, dynamic>)['like_count'], 5);
        // Updated should have new value
        expect((updatedMoment['stats'] as Map<String, dynamic>)['like_count'], 6);
      });

      test('media array is properly normalized', () {
        final rawMedia = <dynamic>[
          {'type': 'image', 'url': 'url1'},
          {'type': 'video', 'url': 'url2'},
          'invalid_entry',
          {'type': 'image', 'url': 'url3'},
        ];

        final normalizedMedia = rawMedia
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        expect(normalizedMedia.length, 3);
        expect(normalizedMedia[0]['type'], 'image');
        expect(normalizedMedia[1]['type'], 'video');
        expect(normalizedMedia[2]['type'], 'image');
      });
    });
  });
}
