import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/public.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_provider.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_state.dart';
import 'package:imboy/store/api/moment_api.dart';

/// Test-only fake that bypasses singleton access (UserRepoLocal / MomentNotifyRepo)
class _FakeMomentNotifyNotifier extends MomentNotifyNotifier {
  @override
  MomentNotifyState build() => const MomentNotifyState();
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

class FakeMomentApi extends MomentApi {
  FakeMomentApi({List<Map<String, dynamic>> items = const []})
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
    facade: MomentFacade(api: FakeMomentApi(items: items)),
  );
}
