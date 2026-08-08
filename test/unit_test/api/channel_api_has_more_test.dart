import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/channel_api.dart';

/// `ChannelApi.hasMoreByPage` 的 hasMore 判据，与
/// `MomentPageResult.fromPayload` 同款修法。
///
/// 回归的真 bug：getSubscribedChannelsPage 原来按「next_cursor 非空」
/// 推 hasMore，而服务端对最后一页也照样回游标 —— 末页时「加载更多」
/// 照样显示，底部永远转圈。判据改为「本页满一页且游标非空」。
void main() {
  group('ChannelApi.hasMoreByPage', () {
    test('满一页 + 游标非空 → true', () {
      expect(
        ChannelApi.hasMoreByPage(listLength: 50, limit: 50, nextCursor: 'c1'),
        isTrue,
      );
    });

    test('不满一页但游标非空 → false（服务端末页照样回游标）', () {
      expect(
        ChannelApi.hasMoreByPage(listLength: 1, limit: 50, nextCursor: 'c1'),
        isFalse,
      );
    });

    test('空列表 + 游标非空 → false', () {
      expect(
        ChannelApi.hasMoreByPage(listLength: 0, limit: 50, nextCursor: 'c1'),
        isFalse,
      );
    });

    test('满一页但游标为空 → false（无游标翻不了页）', () {
      expect(
        ChannelApi.hasMoreByPage(listLength: 50, limit: 50, nextCursor: null),
        isFalse,
      );
    });

    test('超过一页（后端多返）→ true', () {
      expect(
        ChannelApi.hasMoreByPage(listLength: 51, limit: 50, nextCursor: 'c1'),
        isTrue,
      );
    });

    test('limit <= 0 → false，不因 `length >= 0` 恒真而误判有下一页', () {
      expect(
        ChannelApi.hasMoreByPage(listLength: 0, limit: 0, nextCursor: null),
        isFalse,
      );
    });
  });
}
