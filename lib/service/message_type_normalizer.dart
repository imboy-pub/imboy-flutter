/// 消息类型归一化器
///
/// 职责：
/// 1. 校验 msg_type 合法性
/// 2. 提供类型验证和默认值
///
/// 设计原则：
/// - 单一数据源：只信任顶层 msg_type
/// - 不再从 payload 推断消息类型
library;

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/message_type_constants.dart' show MessageType;

/// 消息类型归一化器
class MessageTypeNormalizer {
  /// 私有构造函数，防止实例化
  MessageTypeNormalizer._();

  /// 归一化消息类型。
  ///
  /// 仅处理命名规范与有效性，不再依赖 payload 内的子类型字段。
  static String normalize({
    required String? msgType,
    required Map<String, dynamic>? payload,
  }) {
    final type = msgType?.trim() ?? '';
    if (type.isEmpty) {
      iPrint('⚠️ [MessageTypeNormalizer] msgType 为空');
      return MessageType.unsupported;
    }

    if (!_isValidType(type)) {
      iPrint(
        '⚠️ [MessageTypeNormalizer] 无效类型: "$type"\n'
        '   ┌─ 原始输入 ────────────────────────────────\n'
        '   │  msgType: "$msgType"\n'
        '   │  payload keys: ${payload?.keys.toList() ?? []}\n'
        '   │  payload: ${payload?.toString() ?? "null"}\n'
        '   └──────────────────────────────────────────\n'
        '   - allTypes=${MessageType.allTypes}\n'
        '   - 是否在列表中: ${MessageType.allTypes.contains(type)}',
      );
      return MessageType.unsupported;
    }

    iPrint('✅ [MessageTypeNormalizer] 有效类型: $type');
    return type;
  }

  /// 渲染优先类型。
  ///
  /// msg_type 原值有效则直接使用——它是消息类型的真值；
  /// effective_msg_type 是 WS 回显时的写时缓存，旧版本曾把
  /// redPacket/transfer/groupSchedule 归一化成 unsupported 并持久化，
  /// 脏缓存会挡住本应正常渲染的类型（读回显示「不支持的消息类型」）。
  /// 仅当 msg_type 无效（真未知/为空）时回退 effective_msg_type。
  static String renderType({
    required String? effectiveMsgType,
    required String? rawMsgType,
  }) {
    final raw = rawMsgType?.trim() ?? '';
    if (_isValidType(raw)) {
      return raw;
    }
    return effectiveMsgType ?? '';
  }

  /// 批量归一化消息列表（不修改原始数据）
  static List<Map<String, dynamic>> normalizeBatch(
    List<Map<String, dynamic>> messages,
  ) {
    return messages.map((msg) {
      final msgType = msg['msg_type'] as String?;
      final payload = msg['payload'] is Map<String, dynamic>
          ? msg['payload'] as Map<String, dynamic>
          : null;

      final normalizedType = normalize(msgType: msgType, payload: payload);

      final normalizedMsg = Map<String, dynamic>.from(msg);
      normalizedMsg['msg_type'] = normalizedType;
      return normalizedMsg;
    }).toList();
  }

  /// 判断是否为有效消息类型
  static bool isValidType(String type) {
    return _isValidType(type);
  }

  /// 内部方法：判断类型有效性
  static bool _isValidType(String type) {
    return MessageType.allTypes.contains(type) ||
        type == MessageType.custom ||
        type == MessageType.unsupported;
  }
}
