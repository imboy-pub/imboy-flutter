/// 消息表列名常量（纯 Dart，不依赖任何数据库 / 平台插件）。
///
/// 设计目的（T1.6）：解耦 `MessageModel` ↔ `MessageRepo`。
/// - Model 以前通过 `MessageRepo.xxx` 读取列名字符串，会把 Model 的传递依赖
///   拉到 `sqflite_sqlcipher` → `win32_*`（Windows 条件编译路径），导致 macOS
///   下单元测试编译时也要解析整条插件链，环境错配时测试无法启动。
/// - 抽出纯 Dart 常量后，Model 只依赖本文件，即可在无平台插件的环境中被
///   单元测试直接 import。同时斩断 model → repository 的反向（向下）依赖。
///
/// Repo 侧现有 `MessageRepo.xxx` 静态字段保持不动，作为既有调用点的兼容层；
/// 后续可以让 Repo 直接引用这里的常量以消除重复定义（镜像 GroupMemberColumns）。
class MessageColumns {
  MessageColumns._();

  static const String autoId = 'auto_id';
  static const String id = 'id'; // message_id

  // C2C / C2G / C2C_REVOKE_ACK / C2G_REVOKE_ACK
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
  static const String msgType = 'msg_type';
  static const String action = 'action'; // S2C 消息指令
  static const String e2ee = 'e2ee'; // 端到端加密信息（JSON 字符串）
}
