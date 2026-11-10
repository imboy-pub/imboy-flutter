import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/moment_social/public.dart';
import 'package:imboy/store/api/moment_api.dart';

import 'support/moment_feed_fixture.dart';

class _PagedMomentApi extends FakeMomentApi {
  final requestedCursors = <String?>[];

  @override
  Future<MomentPageResult<Map<String, dynamic>>> getFeedPage({
    String? cursor,
    int limit = 20,
  }) async {
    requestedCursors.add(cursor);
    if (cursor == null) {
      return MomentPageResult(
        list: List.generate(
          20,
          (index) => MockMomentData.createMoment(
            id: 'page1_$index',
            authorUid: '',
            content: 'First page item $index',
            likeCount: 0,
            commentCount: 0,
          ),
        ),
        nextCursor: 'page-2',
        hasMore: true,
      );
    }
    return MomentPageResult(
      list: [
        MockMomentData.createMoment(
          id: 'page2_1',
          authorUid: '',
          content: 'Second page item',
          likeCount: 0,
          commentCount: 0,
        ),
      ],
      nextCursor: null,
      hasMore: false,
    );
  }
}

void main() {
  testWidgets('滚动到底部通过页面控制器加载下一页', (tester) async {
    final api = _PagedMomentApi();
    await tester.pumpWidget(
      MomentTestWrapper(
        child: MomentFeedPage(facade: MomentFacade(api: api)),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(api.requestedCursors, [null]);

    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    ).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(api.requestedCursors, [null, 'page-2']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
