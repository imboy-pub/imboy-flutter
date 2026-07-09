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

  /// 当前用户是否已点赞。后端暂未返回该字段时默认 false（初始一律未赞，
  /// 首次点击才 like），彻底正确需后端在 getComments 返回 is_liked。
  final bool isLiked;
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
    this.isLiked = false,
    required this.createdAt,
  });

  ChannelCommentModel copyWith({int? likeCount, bool? isLiked}) {
    return ChannelCommentModel(
      id: id,
      channelId: channelId,
      messageId: messageId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: content,
      parentId: parentId,
      replyToUid: replyToUid,
      replyToName: replyToName,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt,
    );
  }

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
      isLiked: json['is_liked'] == true,
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
