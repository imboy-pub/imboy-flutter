/// 面聊记录（talk_record）cursor 分页结果（T08 数据层）。
///
/// 契约源：BACKEND-API.md §4 —— talk_record 域游标资源（列表、segments、
/// creation-contexts、share-candidates 等）使用 **opaque cursor + limit
/// （默认 20、最大 100）**，不沿用项目 page/size（CONTRACT-FREEZE-T02 §2.4
/// 冻结的差异决策）。cursor 绑定筛选与调用者，不能切 org 沿用。
library;

class TalkRecordCursorPage<T> {
  final List<T> list;

  /// 下一页 opaque cursor；空串表示没有更多数据。
  final String nextCursor;

  final bool hasMore;

  const TalkRecordCursorPage({
    this.list = const [],
    this.nextCursor = '',
    this.hasMore = false,
  });

  factory TalkRecordCursorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rows = json['list'] is List
        ? (json['list'] as List).whereType<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    final next = json['next_cursor']?.toString() ?? '';
    final more = json['has_more'];
    return TalkRecordCursorPage<T>(
      list: rows.map(fromJson).toList(growable: false),
      nextCursor: next,
      hasMore: more is bool ? more : next.isNotEmpty,
    );
  }
}
