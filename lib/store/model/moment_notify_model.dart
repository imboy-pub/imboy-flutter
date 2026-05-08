/// 朋友圈通知 Model（Slice A-1）。
///
/// 纯 Dart，零外部依赖 —— 仅 import `moment_notify_columns.dart` 取列名常量。
/// 设计初衷与测试文件开头说明一致：后端 `moment_like` 通知走 `no_save`，
/// 重连/冷启动会丢失；客户端必须本地落库才能做通知中心红点与历史列表。
library;

import 'moment_notify_columns.dart';

/// `fromS2CPayload` 的解析结果（sealed，switch 必须穷尽）。
sealed class MomentNotifyParseResult {
  const MomentNotifyParseResult();
}

/// 解析成功。
final class MomentNotifyParseOk extends MomentNotifyParseResult {
  const MomentNotifyParseOk(this.model);
  final MomentNotifyModel model;
}

/// 自赞 / 自评（防御分支，后端 `notify_post_liked` / `notify_post_commented`
/// 已在 `FromUid =:= AuthorUid` 分支返回 `ok` 不下发，但客户端仍校验一遍）。
final class MomentNotifyParseSkipSelf extends MomentNotifyParseResult {
  const MomentNotifyParseSkipSelf();
}

/// 非法 payload。`reason` 取值：
/// - `invalid_action`       非 `moment_like` / `moment_comment`
/// - `missing_current_uid`  当前登录用户 UID 为空
/// - `missing_moment_id`    moment_id 缺失 / 空 / 0 / "0"
/// - `missing_from_uid`     from_uid 缺失 / 空 / 空白
final class MomentNotifyParseInvalid extends MomentNotifyParseResult {
  const MomentNotifyParseInvalid(this.reason);
  final String reason;
}

/// 朋友圈通知记录（对应 `moment_notify` 表一行）。
class MomentNotifyModel {
  const MomentNotifyModel({
    this.id,
    required this.userId,
    required this.action,
    required this.momentId,
    required this.fromUid,
    this.commentId,
    this.isRead = false,
    required this.createdAt,
  });

  /// 自增主键；构造本地待插入对象时传 `null`，SQLite 读回时带数值。
  final int? id;

  /// 接收者 UID（当前登录用户）。
  final String userId;

  /// `moment_like` 或 `moment_comment`。
  final String action;

  /// 朋友圈帖子 ID。
  final String momentId;

  /// 发起人 UID（点赞 / 评论者）。
  final String fromUid;

  /// 评论 ID（仅 `moment_comment` 有）。
  final String? commentId;

  /// 已读标记。
  final bool isRead;

  /// 创建时间（ms epoch）。
  final int createdAt;

  /// 合法 action 白名单。
  static const Set<String> _validActions = {'moment_like', 'moment_comment'};

  /// 从 S2C payload 构造 Model。
  ///
  /// 失败返回 sealed `MomentNotifyParseResult` 的 `Invalid` / `SkipSelf` 变体，
  /// 调用方 switch 穷尽处理（不抛异常，避免 S2C dispatcher 被污染）。
  static MomentNotifyParseResult fromS2CPayload({
    required String action,
    required Map<String, dynamic> payload,
    required String currentUid,
    required int nowMs,
  }) {
    if (!_validActions.contains(action)) {
      return const MomentNotifyParseInvalid('invalid_action');
    }
    if (currentUid.trim().isEmpty) {
      return const MomentNotifyParseInvalid('missing_current_uid');
    }

    final momentId = _normalizeId(payload['moment_id']);
    if (momentId.isEmpty) {
      return const MomentNotifyParseInvalid('missing_moment_id');
    }

    final fromUid = _normalizeId(payload['from_uid']);
    if (fromUid.isEmpty) {
      return const MomentNotifyParseInvalid('missing_from_uid');
    }

    if (fromUid == currentUid) {
      return const MomentNotifyParseSkipSelf();
    }

    // comment_id 仅在 moment_comment 时保留；其他 action 强制 null，
    // 即使后端误发也不污染。
    final commentId = action == 'moment_comment'
        ? _optionalId(payload['comment_id'])
        : null;

    return MomentNotifyParseOk(
      MomentNotifyModel(
        userId: currentUid,
        action: action,
        momentId: momentId,
        fromUid: fromUid,
        commentId: commentId,
        createdAt: nowMs,
      ),
    );
  }

  /// 归一化 id：
  /// - null / 空串 / 空白 / `0` / `'0'` → `''`（视为无效）
  /// - int → `toString()`
  /// - String → `trim()`
  /// - 其他 → `''`
  static String _normalizeId(dynamic value) {
    if (value == null) return '';
    if (value is int) return value <= 0 ? '' : value.toString();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '0') return '';
      return trimmed;
    }
    return '';
  }

  /// 与 `_normalizeId` 语义相同，但空值返回 `null` 而非 `''`，
  /// 用于可选字段 `comment_id`。
  static String? _optionalId(dynamic value) {
    final normalized = _normalizeId(value);
    return normalized.isEmpty ? null : normalized;
  }

  /// 插入映射（不含 `id`，由 SQLite 自增填充）。
  Map<String, dynamic> toInsertMap() => <String, dynamic>{
    MomentNotifyColumns.userId: userId,
    MomentNotifyColumns.action: action,
    MomentNotifyColumns.momentId: momentId,
    MomentNotifyColumns.fromUid: fromUid,
    MomentNotifyColumns.commentId: commentId,
    MomentNotifyColumns.isRead: isRead ? 1 : 0,
    MomentNotifyColumns.createdAt: createdAt,
  };

  /// 从 SQLite 行构造 Model。
  factory MomentNotifyModel.fromRow(Map<String, dynamic> row) {
    return MomentNotifyModel(
      id: row[MomentNotifyColumns.id] as int?,
      userId: (row[MomentNotifyColumns.userId] as String?) ?? '',
      action: (row[MomentNotifyColumns.action] as String?) ?? '',
      momentId: (row[MomentNotifyColumns.momentId] as String?) ?? '',
      fromUid: (row[MomentNotifyColumns.fromUid] as String?) ?? '',
      commentId: row[MomentNotifyColumns.commentId] as String?,
      isRead: ((row[MomentNotifyColumns.isRead] as int?) ?? 0) != 0,
      createdAt: (row[MomentNotifyColumns.createdAt] as int?) ?? 0,
    );
  }

  MomentNotifyModel copyWith({
    int? id,
    String? userId,
    String? action,
    String? momentId,
    String? fromUid,
    String? commentId,
    bool? isRead,
    int? createdAt,
  }) {
    return MomentNotifyModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      action: action ?? this.action,
      momentId: momentId ?? this.momentId,
      fromUid: fromUid ?? this.fromUid,
      commentId: commentId ?? this.commentId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
