import 'package:imboy/store/model/model_parse_utils.dart';

/// 频道评论模型
///
/// 对标公众号/知识星球评论：支持多级回复、点赞计数。
class ChannelCommentModel {
  final int id;
  final int channelId;
  final int messageId;
  final int userId;
  final String userName;
  final String userAvatar;
  final String content;
  final int parentId;
  final int replyToUid;
  final String replyToName;
  final int likeCount;
  final DateTime createdAt;

  ChannelCommentModel({
    required this.id,
    required this.channelId,
    required this.messageId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    this.parentId = 0,
    this.replyToUid = 0,
    this.replyToName = '',
    this.likeCount = 0,
    required this.createdAt,
  });

  factory ChannelCommentModel.fromJson(Map<String, dynamic> json) {
    return ChannelCommentModel(
      id: parseModelInt(json['id']),
      channelId: parseModelInt(json['channel_id']),
      messageId: parseModelInt(json['message_id']),
      userId: parseModelInt(json['user_id']),
      userName: parseModelString(json['user_name']),
      userAvatar: parseModelString(json['user_avatar']),
      content: parseModelString(json['content']),
      parentId: parseModelInt(json['parent_id']),
      replyToUid: parseModelInt(json['reply_to_uid']),
      replyToName: parseModelString(json['reply_to_name']),
      likeCount: parseModelInt(json['like_count']),
      createdAt: parseModelDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'channel_id': channelId,
      'message_id': messageId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'content': content,
      'parent_id': parentId,
      'reply_to_uid': replyToUid,
      'reply_to_name': replyToName,
      'like_count': likeCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'ChannelCommentModel(id: $id, content: $content)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelCommentModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
