import 'package:imboy/store/model/message_columns.dart';

/// MessageRepo 的表名/列名常量与表名映射层（自 message_repo_sqlite.dart 拆出，
/// W6 行数收口；纯常量与纯函数，无状态、无 IO）。
///
/// MessageRepo 通过 static 转发保持 `MessageRepo.c2cTable` 等既有调用面
/// 与导入不变，行为零变化。
abstract final class MessageRepoSchema {
  // v2.0 表名常量（与服务端保持一致）
  static const String c2cTable = 'msg_c2c';
  static const String c2gTable = 'msg_c2g';
  static const String c2sTable = 'msg_c2s';
  static const String s2cTable = 'msg_s2c';

  static const String autoId = 'auto_id';
  static const String id = 'id'; // message_id

  // C2C C2G C2C_REVOKE_ACK C2G_REVOKE_ACK
  static const String type = 'type';
  static const String from = 'from_id';
  static const String to = 'to_id';
  static const String payload = 'payload';
  static const String createdAt = 'created_at';

  // varchar(80)
  static const String conversationUk3 = 'conversation_uk3';
  static const String status = 'status';

  // from id is author bool true | false
  static const String isAuthor = 'is_author';
  static const String topicId = 'topic_id';

  // v2.0 新增字段（从 payload 中提取到顶层）
  static const String msgType =
      'msg_type'; // 消息类型：text, image, voice, video, file 等
  static const String action = 'action'; // S2C 消息指令
  static const String e2ee = 'e2ee'; // 端到端加密信息（JSON 字符串）

  static final List<String> defaultColumns = List.unmodifiable([
    autoId,
    id,
    type,
    from,
    to,
    payload,
    createdAt,
    isAuthor,
    status,
    conversationUk3,
    topicId,
    msgType, // v2.0 新增
    action, // v2.0 新增
    e2ee, // v2.0 新增
  ]);

  /// C2C 专用读取列。sender_did 只存在于 msg_c2c，不能放进所有表的
  /// defaultColumns，否则 C2G/C2S 查询会因列不存在而失败。
  static final List<String> c2cColumns = List.unmodifiable([
    ...defaultColumns,
    MessageColumns.senderDid,
  ]);

  // 允许的表名白名单
  static final Set<String> _allowedTables = {
    MessageRepoSchema.c2cTable,
    MessageRepoSchema.c2gTable,
    MessageRepoSchema.c2sTable,
    MessageRepoSchema.s2cTable,
  };

  // 验证表名是否在白名单中
  static bool isTableAllowed(String tableName) {
    return _allowedTables.contains(tableName);
  }

  static String getTableName(String type) {
    String tb = '';
    // func_helper.iPrint("> rtc msg S_RECEIVED:$res");
    switch (type.toUpperCase()) {
      case 'C2C':
        tb = MessageRepoSchema.c2cTable;
        break;
      case 'C2G':
        tb = MessageRepoSchema.c2gTable;
        break;
      case 'C2S':
        tb = MessageRepoSchema.c2sTable;
        break;
      case 'S2C':
        tb = MessageRepoSchema.s2cTable;
        break;

      //
      case 'C2C_SERVER_ACK':
        tb = MessageRepoSchema.c2cTable;
        break;
      case 'C2G_SERVER_ACK':
        tb = MessageRepoSchema.c2gTable;
        break;
      case 'C2S_SERVER_ACK':
        tb = MessageRepoSchema.c2sTable;
        break;
      case 'S2C_SERVER_ACK':
        tb = MessageRepoSchema.s2cTable;
        break;

      //
      case 'C2C_REVOKE':
        tb = MessageRepoSchema.c2cTable;
        break;
      case 'C2G_REVOKE':
        tb = MessageRepoSchema.c2gTable;
        break;

      case 'C2C_REVOKE_ACK':
        tb = MessageRepoSchema.c2cTable;
        break;
      case 'C2G_REVOKE_ACK':
        tb = MessageRepoSchema.c2gTable;
        break;
    }

    // 验证返回的表名是否在白名单中
    if (!isTableAllowed(tb)) {
      throw ArgumentError('Invalid table name: $tb');
    }

    return tb;
  }
}
