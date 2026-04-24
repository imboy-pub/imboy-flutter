/// 群公告 —— 纯数据模型 + 解析辅助（F3 C3 REST 集成）
///
/// 本文件严格**零外部依赖**（仅 dart:core），便于 Model-only 单测绕开
/// `http_client.dart`（Dio / config）传递链，避免 sqflite→win32 测试基础设施问题。
///
/// `GroupAnnouncementNotifier` 导入本文件复用 [AnnouncementModel]、
/// [parseAnnouncementTimestamp]、[parseOptionalAnnouncementTimestamp]、
/// [buildNoticeTitle] 与 [toRfc3339]。
library;

/// 群公告数据模型。
///
/// 解析合约：后端字段在不同版本 / 端点有别名共存的情况；本模型用字段融合方式
/// 适配（`id` / `notice_id`、`publisher_id` / `user_id`、`content` / `body`、
/// `publisher_name` / `creator_name`），缺失字段回退到合理默认值而非抛错，
/// 以保证列表渲染不被个别脏数据整条中断。
class AnnouncementModel {
  final String id;
  final String groupId;
  final String content;
  final String publisherId;
  final String publisherName;
  final int createdAt;
  final int? expiredAt;

  const AnnouncementModel({
    required this.id,
    required this.groupId,
    required this.content,
    required this.publisherId,
    required this.publisherName,
    required this.createdAt,
    this.expiredAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final publisherId = (json['publisher_id'] ?? json['user_id'] ?? '')
        .toString();
    final publisherName = (json['publisher_name'] ?? json['creator_name'] ?? '')
        .toString();

    return AnnouncementModel(
      id: (json['id'] ?? json['notice_id'] ?? '').toString(),
      groupId: (json['group_id'] ?? '').toString(),
      content: (json['content'] ?? json['body'] ?? '').toString(),
      publisherId: publisherId,
      // publisher_name 缺失时回退 publisher_id，避免 UI 渲染空昵称
      publisherName: publisherName.isEmpty ? publisherId : publisherName,
      createdAt: parseAnnouncementTimestamp(json['created_at']),
      expiredAt: parseOptionalAnnouncementTimestamp(json['expired_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'content': content,
      'publisher_id': publisherId,
      'publisher_name': publisherName,
      'created_at': createdAt,
      'expired_at': expiredAt,
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? groupId,
    String? content,
    String? publisherId,
    String? publisherName,
    int? createdAt,
    int? expiredAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      content: content ?? this.content,
      publisherId: publisherId ?? this.publisherId,
      publisherName: publisherName ?? this.publisherName,
      createdAt: createdAt ?? this.createdAt,
      expiredAt: expiredAt ?? this.expiredAt,
    );
  }
}

/// 判断一条公告是否处于"昵称回退态"——即 publisherName 等于 publisherId
/// （后端 SELECT 未带昵称，fromJson 回退到 publisherId 防空）。
///
/// 仅 fallback 态的项需要客户端补昵称（#28 Gap #1）。publisherId 空串
/// 直接跳过（回退语义不成立）。
bool isPublisherNameFallback(AnnouncementModel item) {
  return item.publisherId.isNotEmpty && item.publisherName == item.publisherId;
}

/// 对列表中处于昵称回退态的公告，通过 [lookup] 异步补齐 publisherName。
///
/// 设计约束：
/// - 仅对 [isPublisherNameFallback] 成立的项发起查询，已有真实昵称的项原样保留
/// - 同一 publisherId 只查一次（去重后并发 Future.wait）
/// - [lookup] 返回 null/空串 → 保持原值（TSID 数字串兜底），不阻塞 UI
/// - [lookup] 抛异常 → 单项静默失败，其他项不受影响
/// - 零命中时返回原列表实例（无不必要的 allocation）
Future<List<AnnouncementModel>> resolveAnnouncementNicknames(
  List<AnnouncementModel> items,
  Future<String?> Function(String publisherId) lookup,
) async {
  final unresolvedIds = <String>{};
  for (final item in items) {
    if (isPublisherNameFallback(item)) {
      unresolvedIds.add(item.publisherId);
    }
  }
  if (unresolvedIds.isEmpty) return items;

  final resolvedMap = <String, String>{};
  await Future.wait(
    unresolvedIds.map((id) async {
      try {
        final name = await lookup(id);
        if (name != null && name.isNotEmpty) {
          resolvedMap[id] = name;
        }
      } catch (_) {
        // 单项失败不影响其他项
      }
    }),
  );

  if (resolvedMap.isEmpty) return items;

  return items.map((item) {
    final resolved = resolvedMap[item.publisherId];
    if (resolved != null && isPublisherNameFallback(item)) {
      return item.copyWith(publisherName: resolved);
    }
    return item;
  }).toList();
}

/// 解析必填时间戳。
///
/// 支持三种输入：
///   - `int` 毫秒 / 秒（≥ 1e12 视为毫秒，≥ 1e9 视为秒 → ×1000，其它原样返回）
///   - `String` 数字串：同 int 逻辑
///   - `String` ISO-8601：`DateTime.tryParse` → millisecondsSinceEpoch
///   - `null` / 无法解析 → `0`
///
/// 1e12 / 1e9 两道阈值保证：后端返回秒级时间戳（10 位）自动放大到毫秒级，
/// 同时保留已是毫秒级（13 位）的原值，防止再次 ×1000 溢出。
int parseAnnouncementTimestamp(dynamic value) {
  if (value == null) return 0;
  if (value is int) {
    if (value > 1000000000000) return value;
    if (value > 1000000000) return value * 1000;
    return value;
  }
  if (value is String) {
    final intVal = int.tryParse(value);
    if (intVal != null) {
      if (intVal > 1000000000000) return intVal;
      if (intVal > 1000000000) return intVal * 1000;
      return intVal;
    }
    final dt = DateTime.tryParse(value);
    if (dt != null) {
      return dt.millisecondsSinceEpoch;
    }
  }
  return 0;
}

/// 解析可选时间戳；与 [parseAnnouncementTimestamp] 同逻辑，但 `0` / 非法 → `null`。
int? parseOptionalAnnouncementTimestamp(dynamic value) {
  if (value == null) return null;
  final parsed = parseAnnouncementTimestamp(value);
  return parsed > 0 ? parsed : null;
}

/// 根据正文首行构建公告标题。
///
/// 规则：
///   - 取首行（`\n` 分隔）且 trim，空则返回 `'群公告'`
///   - 首行 ≤ 20 字符：原样
///   - 首行 > 20 字符：截取前 20 + `'...'`
String buildNoticeTitle(String content) {
  final firstLine = content.trim().split('\n').first.trim();
  if (firstLine.isEmpty) return '群公告';
  if (firstLine.length <= 20) return firstLine;
  return '${firstLine.substring(0, 20)}...';
}

/// 毫秒级时间戳 → RFC3339 / ISO-8601 UTC 字符串（`Z` 后缀）。
///
/// 后端 `expired_at` 字段要求 ISO-8601。本函数保证无论本地时区如何，
/// 输出都是 UTC 标准串，避免时区漂移。
String toRfc3339(int milliseconds) {
  return DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: false,
  ).toUtc().toIso8601String();
}
