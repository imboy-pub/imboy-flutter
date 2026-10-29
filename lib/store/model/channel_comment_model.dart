import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/channel_decimal_id.dart';

/// 频道评论模型
///
/// 对标公众号/知识星球评论：支持多级回复、点赞计数。
class ChannelCommentModel {
  final String id;
  final String channelId;
  final String messageId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final String parentId;
  final String replyToUid;
  final String replyToName;
  final int likeCount;

  /// 当前用户是否已点赞。后端暂未返回该字段时默认 false（初始一律未赞，
  /// 首次点击才 like），彻底正确需后端在 getComments 返回 is_liked。
  final bool isLiked;
  final DateTime createdAt;

  ChannelCommentModel({
    required Object id,
    required Object channelId,
    required Object messageId,
    required Object userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    Object parentId = 0,
    Object replyToUid = 0,
    this.replyToName = '',
    this.likeCount = 0,
    this.isLiked = false,
    required this.createdAt,
  }) : id = id.toString(),
       channelId = channelId.toString(),
       messageId = messageId.toString(),
       userId = userId.toString(),
       parentId = parentId.toString(),
       replyToUid = replyToUid.toString();

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
      id: channelDecimalId(json['id'], allowZero: true) ?? '0',
      channelId: channelDecimalId(json['channel_id'], allowZero: true) ?? '0',
      messageId: channelDecimalId(json['message_id'], allowZero: true) ?? '0',
      userId: channelDecimalId(json['user_id'], allowZero: true) ?? '0',
      userName: parseModelString(json['user_name']),
      userAvatar: parseModelString(json['user_avatar']),
      content: parseModelString(json['content']),
      parentId: channelDecimalId(json['parent_id'], allowZero: true) ?? '0',
      replyToUid:
          channelDecimalId(json['reply_to_uid'], allowZero: true) ?? '0',
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
