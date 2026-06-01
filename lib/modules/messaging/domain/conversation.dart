import 'package:imboy/modules/messaging/domain/value/conversation_id.dart';

/// 会话充血实体 / Conversation rich entity（T1.7）。
///
/// 未读数不变量内聚于实体，杜绝散落各处的外部直接赋值
/// （SOURCE 现状：conversation_repo_sqlite.dart:135 `obj.unreadNum += old`、
/// conversation_provider.dart:240/525 `unreadNum: 0`、chat_provider.dart:1100
/// `> 0 ? : 0` clamp）。语义对齐 BE 权威 `conversation_agg`（未读 >=0、
/// resetUnread 清零）。`mentionUnread` 与未读对称累加/清零（C7-β）。
///
/// 不可变：increment/merge/reset 均返回新实例。纯 Dart——禁止
/// import flutter/* 与 repository/*。
class Conversation {
  /// 主构造默认值；负数计数由 [Conversation.fromCounts] 规整，
  /// 直接构造时调用方须保证非负（与 const 语义一致）。
  const Conversation({
    required this.id,
    this.unreadNum = 0,
    this.mentionUnread = 0,
  });

  /// 从（可能脏的）持久化计数构造，负值规整为 0，守护 unread>=0 不变量。
  factory Conversation.fromCounts({
    required ConversationId id,
    required int unreadNum,
    int mentionUnread = 0,
  }) => Conversation(
    id: id,
    unreadNum: unreadNum > 0 ? unreadNum : 0,
    mentionUnread: mentionUnread > 0 ? mentionUnread : 0,
  );

  final ConversationId id;

  /// 未读消息数，不变量 >= 0。
  final int unreadNum;

  /// @提及未读数（C7-β），不变量 >= 0。
  final int mentionUnread;

  /// 是否有未读。
  bool get hasUnread => unreadNum > 0;

  /// 累加未读（取代外部 `obj.unreadNum = obj.unreadNum + n`）。
  /// 非正增量视为 0（防御），保持单调不减；mention 可对称累加。
  Conversation incrementUnread({int by = 1, int mentionBy = 0}) => _copyWith(
    unreadNum: unreadNum + (by > 0 ? by : 0),
    mentionUnread: mentionUnread + (mentionBy > 0 ? mentionBy : 0),
  );

  /// 合并旧未读计数（repo save 场景：新值累加旧值，镜像
  /// conversation_repo_sqlite.dart:135-136 的累加语义）。负旧值规整为 0。
  Conversation mergeUnread(int previousUnread, {int previousMention = 0}) =>
      _copyWith(
        unreadNum: unreadNum + (previousUnread > 0 ? previousUnread : 0),
        mentionUnread:
            mentionUnread + (previousMention > 0 ? previousMention : 0),
      );

  /// 清零未读（进入会话/已读，取代散落的 `unreadNum: 0` 赋值）。
  /// 同时清零 mention（对齐 conversation_provider.dart:240 对称重置）。
  Conversation resetUnread() => _copyWith(unreadNum: 0, mentionUnread: 0);

  Conversation _copyWith({int? unreadNum, int? mentionUnread}) => Conversation(
    id: id,
    unreadNum: unreadNum ?? this.unreadNum,
    mentionUnread: mentionUnread ?? this.mentionUnread,
  );
}
