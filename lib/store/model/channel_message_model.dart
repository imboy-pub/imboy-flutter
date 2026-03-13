import 'dart:convert';

import 'package:imboy/store/model/model_parse_utils.dart';

/// 频道消息模型
///
/// 频道消息与普通 C2C/Group 消息的区别：
/// - 发送者只能是频道管理员
/// - 消息包含发布者信息（冗余存储）
/// - 支持阅读量和反应统计
class ChannelMessageModel {
  final String id;
  final String channelId;
  final String? authorId;
  final String? authorName;
  final String? authorAvatar;
  final String content;
  final String msgType;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  final bool isPinned;
  final int viewCount;
  final Map<String, int>? reactionSummary;

  ChannelMessageModel({
    required this.id,
    required this.channelId,
    this.authorId,
    this.authorName,
    this.authorAvatar,
    required this.content,
    required this.msgType,
    this.payload,
    required this.createdAt,
    this.isPinned = false,
    this.viewCount = 0,
    this.reactionSummary,
  });

  factory ChannelMessageModel.fromJson(Map<String, dynamic> json) {
    final payloadData = _parsePayload(json['payload']);
    final reactions = _parseReactionSummary(json['reaction_summary']);

    return ChannelMessageModel(
      id: parseModelString(json['id']),
      channelId: parseModelString(json['channel_id']),
      authorId: parseModelNullableString(json['author_id']),
      authorName: parseModelNullableString(json['author_name']),
      authorAvatar: parseModelNullableString(json['author_avatar']),
      content: parseModelString(json['content']),
      msgType: parseModelString(json['msg_type'], defaultValue: 'channel_text'),
      payload: payloadData,
      createdAt: parseModelDateTime(json['created_at']),
      isPinned: parseModelBool(json['is_pinned']),
      viewCount: parseModelInt(json['view_count']),
      reactionSummary: reactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channel_id': channelId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'content': content,
      'msg_type': msgType,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_pinned': isPinned ? 1 : 0,
      'view_count': viewCount,
      'reaction_summary': reactionSummary != null
          ? jsonEncode(reactionSummary)
          : null,
    };
  }

  /// 从 SQLite Map 创建
  factory ChannelMessageModel.fromMap(Map<String, dynamic> map) {
    final payloadData = _parsePayload(map['payload']);
    final reactions = _parseReactionSummary(map['reaction_summary']);

    return ChannelMessageModel(
      id: parseModelString(map['id']),
      channelId: parseModelString(map['channel_id']),
      authorId: parseModelNullableString(map['author_id']),
      authorName: parseModelNullableString(map['author_name']),
      authorAvatar: parseModelNullableString(map['author_avatar']),
      content: parseModelString(map['content']),
      msgType: parseModelString(map['msg_type'], defaultValue: 'channel_text'),
      payload: payloadData,
      createdAt: parseModelDateTime(map['created_at']),
      isPinned: parseModelBool(map['is_pinned']),
      viewCount: parseModelInt(map['view_count']),
      reactionSummary: reactions,
    );
  }

  static Map<String, dynamic>? _parsePayload(dynamic value) {
    return parseModelJsonMap(value);
  }

  static Map<String, int>? _parseReactionSummary(dynamic value) {
    if (value == null) return null;

    dynamic source = value;
    if (source is String) {
      if (source.isEmpty) return null;
      try {
        source = jsonDecode(source);
      } catch (_) {
        return null;
      }
    }

    if (source is Map) {
      final result = <String, int>{};
      for (final entry in source.entries) {
        result[entry.key.toString()] = parseModelInt(entry.value);
      }
      return result;
    }

    return null;
  }

  /// 转换为 SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'channel_id': channelId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'content': content,
      'msg_type': msgType,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_pinned': isPinned ? 1 : 0,
      'view_count': viewCount,
      'reaction_summary': reactionSummary != null
          ? jsonEncode(reactionSummary)
          : null,
    };
  }

  /// 获取消息预览文本
  ///
  /// 根据消息类型返回对应格式的预览文本
  String get contentPreview {
    switch (msgType) {
      case 'channel_text':
        return content.length > 50 ? '${content.substring(0, 50)}...' : content;
      case 'channel_image':
        return '[图片]';
      case 'channel_video':
        return '[视频]';
      case 'channel_audio':
        return '[语音]';
      case 'channel_file':
        return '[文件]';
      case 'channel_link':
        return '[链接]';
      case 'channel_location':
        return '[位置]';
      default:
        // 尝试从 payload 获取文本
        if (payload != null && payload!['text'] != null) {
          final text = payload!['text'].toString();
          return text.length > 50 ? '${text.substring(0, 50)}...' : text;
        }
        return '[消息]';
    }
  }

  /// 复制并修改部分字段
  ChannelMessageModel copyWith({
    String? id,
    String? channelId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    String? msgType,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    bool? isPinned,
    int? viewCount,
    Map<String, int>? reactionSummary,
  }) {
    return ChannelMessageModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      msgType: msgType ?? this.msgType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      viewCount: viewCount ?? this.viewCount,
      reactionSummary: reactionSummary ?? this.reactionSummary,
    );
  }

  @override
  String toString() {
    return 'ChannelMessageModel(id: $id, channelId: $channelId, msgType: $msgType, contentPreview: $contentPreview)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelMessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
