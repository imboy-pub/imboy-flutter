import 'dart:convert';

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
    Map<String, dynamic>? payloadData;
    if (json['payload'] != null) {
      if (json['payload'] is String) {
        try {
          payloadData = jsonDecode(json['payload'] as String)
              as Map<String, dynamic>?;
        } catch (_) {
          payloadData = null;
        }
      } else if (json['payload'] is Map<String, dynamic>) {
        payloadData = json['payload'] as Map<String, dynamic>;
      }
    }

    Map<String, int>? reactions;
    if (json['reaction_summary'] != null) {
      if (json['reaction_summary'] is String) {
        try {
          reactions = Map<String, int>.from(
              jsonDecode(json['reaction_summary'] as String));
        } catch (_) {
          reactions = null;
        }
      } else if (json['reaction_summary'] is Map) {
        reactions = Map<String, int>.from(json['reaction_summary'] as Map);
      }
    }

    return ChannelMessageModel(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      authorId: json['author_id'] as String?,
      authorName: json['author_name'] as String?,
      authorAvatar: json['author_avatar'] as String?,
      content: json['content'] as String? ?? '',
      msgType: json['msg_type'] as String? ?? 'channel_text',
      payload: payloadData,
      createdAt: json['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
          : DateTime.parse(json['created_at'] as String),
      isPinned: (json['is_pinned'] as int? ?? 0) == 1,
      viewCount: json['view_count'] as int? ?? 0,
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
      'reaction_summary':
          reactionSummary != null ? jsonEncode(reactionSummary) : null,
    };
  }

  /// 从 SQLite Map 创建
  factory ChannelMessageModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? payloadData;
    if (map['payload'] != null && map['payload'].toString().isNotEmpty) {
      try {
        payloadData =
            jsonDecode(map['payload'] as String) as Map<String, dynamic>?;
      } catch (_) {
        payloadData = null;
      }
    }

    Map<String, int>? reactions;
    if (map['reaction_summary'] != null &&
        map['reaction_summary'].toString().isNotEmpty) {
      try {
        reactions = Map<String, int>.from(
            jsonDecode(map['reaction_summary'] as String));
      } catch (_) {
        reactions = null;
      }
    }

    return ChannelMessageModel(
      id: map['id'] as String,
      channelId: map['channel_id'] as String,
      authorId: map['author_id'] as String?,
      authorName: map['author_name'] as String?,
      authorAvatar: map['author_avatar'] as String?,
      content: map['content'] as String? ?? '',
      msgType: map['msg_type'] as String? ?? 'channel_text',
      payload: payloadData,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      viewCount: map['view_count'] as int? ?? 0,
      reactionSummary: reactions,
    );
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
      'reaction_summary':
          reactionSummary != null ? jsonEncode(reactionSummary) : null,
    };
  }

  /// 获取消息预览文本
  ///
  /// 根据消息类型返回对应格式的预览文本
  String get contentPreview {
    switch (msgType) {
      case 'channel_text':
        return content.length > 50
            ? '${content.substring(0, 50)}...'
            : content;
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
