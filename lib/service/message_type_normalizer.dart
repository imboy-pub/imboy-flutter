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

  /// 历史/外来类型 → 现役类型的别名表（只做渲染兼容，不是可发送类型）。
  ///
  /// `channel_message`：2026-10-30 之前「频道消息 → 分享到聊天」写出的私有
  /// msg_type，全站没有为它注册 builder —— 发送方自己与接收方都只能看到
  /// 「不支持的消息类型 (channel_message)」。发送侧已改为 `channel_card`
  /// （见 page/channel/channel_share_payload.dart），此处把**已落库的历史行**
  /// 与旧客户端产出的值归一到同一渲染器，读回不再是「不支持」。
  ///
  /// 别名刻意不进 `MessageType.allTypes`：它不合法、不可发送、可随时移除。
  static const Map<String, String> _legacyAliases = <String, String>{
    MessageType.legacyChannelMessage: MessageType.channelCard,
  };

  /// 归一历史别名（不做有效性校验）。
  ///
  /// 供转发链路使用：把旧消息的 `channel_message` 换成现役类型再发出去，
  /// 避免继续把不可渲染的值传播给对端。
  static String aliasOf(String type) => _alias(type.trim());

  static String _alias(String type) => _legacyAliases[type] ?? type;

  /// 归一化消息类型。
  ///
  /// 仅处理命名规范与有效性，不再依赖 payload 内的子类型字段。
  static String normalize({
    required String? msgType,
    required Map<String, dynamic>? payload,
  }) {
    final type = _alias(msgType?.trim() ?? '');
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
    return _canonical(type);
  }

  /// 协议别称 → 渲染真值归一。
  ///
  /// 'audio' 是 protobuf 通道（ContentType.AUDIO）与收藏恢复链路
  /// （kind=3）产出的协议别称，全站发送口径与渲染注册都是 'voice'
  /// （MessageAudioBuilder.type = MessageType.voice）。不归一的话
  /// 'audio' 虽判有效，渲染注册表却解析不到对应 builder，照样落
  /// 「不支持的消息类型」。
  static String _canonical(String type) {
    return type == MessageType.audio ? MessageType.voice : type;
  }

  /// 渲染优先类型。
  ///
  /// msg_type 原值有效则直接使用——它是消息类型的真值；
  /// effective_msg_type 是 WS 回显时的写时缓存，旧版本曾把
  /// redPacket/transfer/groupSchedule 归一化成 unsupported 并持久化，
  /// 脏缓存会挡住本应正常渲染的类型（读回显示「不支持的消息类型」）。
  /// 仅当 msg_type 无效（真未知/为空）时回退 effective_msg_type。
  ///
  /// ⚠️ `unsupported` 本身是**脏值不是真值**：`_isValidType` 把
  /// `unsupported` 判为有效（归一化器的合法取值之一），旧版本把业务
  /// 类型归一化成 unsupported 持久化后，raw 与 effective 都是
  /// `unsupported`——不加排除 raw 永远"有效"，脏缓存照常渲染成
  /// 「不支持的消息类型」。排除后回退 effective 仍可能救回
  /// `effective_msg_type` 未被覆盖的历史行。
  static String renderType({
    required String? effectiveMsgType,
    required String? rawMsgType,
  }) {
    final raw = _alias(rawMsgType?.trim() ?? '');
    if (raw.isNotEmpty && raw != MessageType.unsupported && _isValidType(raw)) {
      return _canonical(raw);
    }
    final effective = _alias(effectiveMsgType?.trim() ?? '');
    if (effective.isNotEmpty &&
        effective != MessageType.unsupported &&
        _isValidType(effective)) {
      return _canonical(effective);
    }
    return '';
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
