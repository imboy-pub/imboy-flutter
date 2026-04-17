/// S2C `group_notice_published` 通知 payload 的解析与分派 —— W1.1 GREEN。
///
/// 对齐后端契约（规划中的 `group_notice_logic:publish_notice/3`）：
///   Payload = #{
///     <<"gid">>                => Gid,               % int
///     <<"notice_id">>          => NoticeId,          % int
///     <<"publisher_id">>       => Uid,               % int
///     <<"publisher_nickname">> => <<"Alice">>,       % binary
///     <<"title">>              => <<"新公告">>,       % binary
///     <<"body">>               => <<"...">>,          % binary
///     <<"expired_at">>         => ExpiredAtMs,       % int ms or 0
///     <<"published_at">>       => Now                % int ms
///   }
///
/// 设计要点：
///   - **与 announcement_model 的解析对齐**：`expired_at == 0 → null`
///     （永不过期语义），`published_at` 缺失 → 0（时间轴类字段用 0 标记
///     "未知"，区分于 nullable expiredAt 的"无限期"语义）
///   - **本切片不写 announcement 本地表**：dispatcher 只做 parse + fireEvent，
///     UI 层（`GroupAnnouncementProvider`）在收到事件后自行调 REST 刷新
///     （与后端 REST-only 的现状对齐，避免引入 v20 migration 债务）
///   - 纯函数解析 + 函数注入分派 —— 脱离 `SqliteService`/`AppEventBus`
///     单测，绕开 sqflite→win32 传递链
library;

/// 解析结果（sealed）：
///   - `GroupNoticePublishedPayload`：gid/notice_id/publisher_id 合法
///   - `GroupNoticeParseError`：必需字段非法（reason 为稳定机器码）
sealed class GroupNoticeParseResult {
  const GroupNoticeParseResult();
}

/// 合法 payload 的结构化视图。
final class GroupNoticePublishedPayload extends GroupNoticeParseResult {
  /// 群 ID（必需，>0）
  final int gid;

  /// 公告 ID（必需，>0）
  final int noticeId;

  /// 发布者用户 ID（必需，>0）
  final int publisherId;

  /// 发布者昵称（缺失/null → 空串）
  final String publisherNickname;

  /// 公告标题（缺失/null → 空串）
  final String title;

  /// 公告正文（缺失/null → 空串）
  final String body;

  /// 过期时间戳（毫秒）；`null` 表示永不过期（对齐 announcement_model）
  final int? expiredAt;

  /// 发布时间戳（毫秒）；缺失 → 0（"未知"标记，非 null 以避免 UI 时间轴空洞）
  final int publishedAt;

  const GroupNoticePublishedPayload({
    required this.gid,
    required this.noticeId,
    required this.publisherId,
    required this.publisherNickname,
    required this.title,
    required this.body,
    required this.expiredAt,
    required this.publishedAt,
  });
}

/// 解析失败。`reason` 为稳定的机器可读码：
///   - `'invalid_gid'`       : gid 缺失或 <= 0
///   - `'invalid_notice_id'` : notice_id 缺失或 <= 0
///   - `'invalid_publisher_id'` : publisher_id 缺失或 <= 0
final class GroupNoticeParseError extends GroupNoticeParseResult {
  final String reason;
  const GroupNoticeParseError(this.reason);
}

/// 解析 S2C `group_notice_published` payload。
///
/// 契约见文件头；失败时返回 `GroupNoticeParseError`，成功时返回
/// `GroupNoticePublishedPayload`。
GroupNoticeParseResult parseGroupNoticePublishedPayload(
  Map<String, dynamic> payload,
) {
  final gid = _asInt(payload['gid']);
  if (gid == null || gid <= 0) {
    return const GroupNoticeParseError('invalid_gid');
  }

  final noticeId = _asInt(payload['notice_id']);
  if (noticeId == null || noticeId <= 0) {
    return const GroupNoticeParseError('invalid_notice_id');
  }

  final publisherId = _asInt(payload['publisher_id']);
  if (publisherId == null || publisherId <= 0) {
    return const GroupNoticeParseError('invalid_publisher_id');
  }

  return GroupNoticePublishedPayload(
    gid: gid,
    noticeId: noticeId,
    publisherId: publisherId,
    publisherNickname: _asText(payload['publisher_nickname']),
    title: _asText(payload['title']),
    body: _asText(payload['body']),
    expiredAt: _asOptionalTimestamp(payload['expired_at']),
    publishedAt: _asTimestamp(payload['published_at']),
  );
}

/// 副作用分派：解析 + 广播事件。
///
/// 通过函数注入隔离 `AppEventBus`，便于单元测试。真实接线见 `message_s2c.dart`。
///
/// 契约：
///   - 合法 payload → `fireEvent(payload)`
///   - 非法 payload → `fireEvent` 不调用，仅 `log(reason)` 输出
Future<void> handleGroupNoticeS2C({
  required Map<String, dynamic> payload,
  required void Function(GroupNoticePublishedPayload payload) fireEvent,
  void Function(String message)? log,
}) async {
  final logFn = log ?? (_) {};
  final parsed = parseGroupNoticePublishedPayload(payload);
  switch (parsed) {
    case GroupNoticeParseError(:final reason):
      logFn(
        '[group_notice_published] parse_failed reason=$reason payload=$payload',
      );
      return;
    case GroupNoticePublishedPayload():
      fireEvent(parsed);
  }
}

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

String _asText(Object? raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  return raw.toString();
}

/// 时间轴类字段：缺失 / 非法 → 0（"未知"标记）
int _asTimestamp(Object? raw) {
  final v = _asInt(raw);
  if (v == null || v < 0) return 0;
  return v;
}

/// 过期类字段：0 / 缺失 → null（永不过期语义，对齐 announcement_model）
int? _asOptionalTimestamp(Object? raw) {
  final v = _asInt(raw);
  if (v == null || v <= 0) return null;
  return v;
}
