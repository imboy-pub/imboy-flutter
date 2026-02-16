/// 消息类型归一化器
///
/// 职责：
/// 1. 修正服务端发送的错误 msg_type（如 'custom'）
/// 2. 类型别名转换（audio → voice）
/// 3. 提供类型验证和默认值
///
/// 设计原则：
/// - 单一数据源：数据库 msg_type 字段必须存储实际类型
/// - 类型归一化：统一命名规范（voice 优先于 audio）
/// - 向后兼容：支持历史数据和旧代码
library;

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/message_type_constants.dart' show MessageType;

/// 消息类型归一化器
///
/// 用于修正服务端发送的消息类型，确保数据库存储正确的类型值。
///
/// ## 使用示例
/// ```dart
/// // 修正 custom 类型
/// final type = MessageTypeNormalizer.normalize(
///   msgType: 'custom',
///   payload: {'custom_type': 'audio'},
/// );
/// // 返回: 'voice'
///
/// // 归一化 audio 类型
/// final type = MessageTypeNormalizer.normalize(
///   msgType: 'audio',
///   payload: {},
/// );
/// // 返回: 'voice'
/// ```
class MessageTypeNormalizer {
  /// 私有构造函数，防止实例化
  MessageTypeNormalizer._();

  /// 修正消息类型
  ///
  /// 处理步骤：
  /// 1. 如果 [msgType] 是 'custom'，从 [payload] 的 'custom_type' 获取实际类型
  /// 2. 类型归一化：'audio' → 'voice'
  /// 3. 验证类型有效性，无效则返回 'unsupported'
  ///
  /// ## 参数
  /// - [msgType]: 原始 msg_type（可能为 'custom'）
  /// - [payload]: 消息负载（可能包含 custom_type）
  ///
  /// ## 返回
  /// 修正后的实际类型
  ///
  /// ## 示例
  /// ```dart
  /// // 修正 custom 类型
  /// MessageTypeNormalizer.normalize(
  ///   msgType: 'custom',
  ///   payload: {'custom_type': 'audio'},
  /// ) // 返回 'voice'
  ///
  /// // 保留其他类型
  /// MessageTypeNormalizer.normalize(
  ///   msgType: 'image',
  ///   payload: {},
  /// ) // 返回 'image'
  ///
  /// // 处理无效类型
  /// MessageTypeNormalizer.normalize(
  ///   msgType: 'invalid',
  ///   payload: {},
  /// ) // 返回 'unsupported'
  /// ```
  static String normalize({
    required String? msgType,
    required Map<String, dynamic>? payload,
  }) {
    // 步骤1: 处理空值
    String type = msgType?.trim() ?? '';
    if (type.isEmpty) {
      iPrint('⚠️ [MessageTypeNormalizer] msgType 为空');
      return 'unsupported';
    }

    // 步骤2: 处理 custom 类型（从 custom_type 获取实际类型）
    if (type == 'custom') {
      final customType = payload?['custom_type']?.toString().trim() ?? '';
      iPrint('🔍 [MessageTypeNormalizer] custom 类型检测: custom_type="$customType"');
      if (customType.isNotEmpty) {
        type = customType;
        iPrint('🔧 [MessageTypeNormalizer] custom -> $type');
      } else {
        iPrint('⚠️ [MessageTypeNormalizer] custom 类型缺少 custom_type');
        return 'unsupported';
      }
    }

    // 步骤3: 类型归一化和命名转换
    // 3.1 audio → voice
    if (type == 'audio') {
      iPrint('🔧 [MessageTypeNormalizer] audio -> voice');
      type = 'voice';
    }
    // 3.2 下划线命名转小驼峰（visit_card → visitCard, webrtc_audio → webrtcAudio）
    else if (type.contains('_')) {
      final camelCase = _toCamelCase(type);
      if (camelCase != type) {
        iPrint('🔧 [MessageTypeNormalizer] $type -> $camelCase (下划线转小驼峰)');
        type = camelCase;
      }
    }

    // 步骤4: 验证有效性
    iPrint('🔍 [MessageTypeNormalizer] 验证类型: "$type"');
    if (!_isValidType(type)) {
      // 打印原始消息格式帮助调试
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
      return 'unsupported';
    }

    iPrint('✅ [MessageTypeNormalizer] 有效类型: $type');
    return type;
  }

  /// 批量修正消息列表
  ///
  /// 适用于离线消息批量处理场景
  ///
  /// ## 参数
  /// - [messages]: 原始消息列表
  ///
  /// ## 返回
  /// 修正后的消息列表（不修改原始数据）
  ///
  /// ## 示例
  /// ```dart
  /// final messages = [
  ///   {'msg_type': 'custom', 'payload': {'custom_type': 'audio'}},
  ///   {'msg_type': 'image', 'payload': {}},
  /// ];
  /// final normalized = MessageTypeNormalizer.normalizeBatch(messages);
  /// // 结果: [
  /// //   {'msg_type': 'voice', 'payload': {'custom_type': 'audio'}},
  /// //   {'msg_type': 'image', 'payload': {}},
  /// // ]
  /// ```
  static List<Map<String, dynamic>> normalizeBatch(
    List<Map<String, dynamic>> messages,
  ) {
    return messages.map((msg) {
      final msgType = msg['msg_type'] as String?;
      final payload = msg['payload'] is Map<String, dynamic>
          ? msg['payload'] as Map<String, dynamic>
          : null;

      final normalizedType = normalize(
        msgType: msgType,
        payload: payload,
      );

      // 创建修正后的消息副本（不修改原始数据）
      final normalizedMsg = Map<String, dynamic>.from(msg);
      normalizedMsg['msg_type'] = normalizedType;

      return normalizedMsg;
    }).toList();
  }

  /// 判断是否为有效的消息类型
  ///
  /// ## 参数
  /// - [type]: 待验证的类型
  ///
  /// ## 返回
  /// true 如果类型有效，false 否则
  static bool isValidType(String type) {
    return _isValidType(type);
  }

  /// 内部方法：判断类型有效性
  static bool _isValidType(String type) {
    // 检查是否在预定义的类型列表中
    if (MessageType.allTypes.contains(type)) {
      return true;
    }

    // 特殊类型（不在常量中但需要处理）
    const specialTypes = {
      'custom', // 过渡期使用，用于从 custom_type 提取实际类型
    };

    return specialTypes.contains(type);
  }

  /// 获取类型的标准名称（别名转换）
  ///
  /// ## 参数
  /// - [type]: 原始类型
  ///
  /// ## 返回
  /// 标准类型名称
  ///
  /// ## 示例
  /// ```dart
  /// MessageTypeNormalizer.getStandardName('audio') // 返回 'voice'
  /// MessageTypeNormalizer.getStandardName('image') // 返回 'image'
  /// ```
  static String getStandardName(String type) {
    // 使用预定义的别名映射
    return MessageType.aliases[type] ?? type;
  }

  /// 判断是否需要归一化
  ///
  /// ## 参数
  /// - [msgType]: 原始消息类型
  ///
  /// ## 返回
  /// true 如果需要归一化，false 否则
  ///
  /// ## 示例
  /// ```dart
  /// MessageTypeNormalizer.needsNormalization('custom') // true
  /// MessageTypeNormalizer.needsNormalization('audio') // true
  /// MessageTypeNormalizer.needsNormalization('voice') // false
  /// MessageTypeNormalizer.needsNormalization('image') // false
  /// ```
  static bool needsNormalization(String? msgType) {
    if (msgType == null || msgType.isEmpty) {
      return true;
    }

    // 需要归一化的类型
    const needsNorm = {'custom', 'audio'};

    return needsNorm.contains(msgType);
  }

  /// 获取归一化后的类型（不验证有效性）
  ///
  /// 与 [normalize] 的区别：此方法不验证类型有效性，仅进行转换
  ///
  /// ## 参数
  /// - [msgType]: 原始消息类型
  /// - [customType]: 自定义类型（当 msgType 为 custom 时使用）
  ///
  /// ## 返回
  /// 归一化后的类型
  ///
  /// ## 示例
  /// ```dart
  /// MessageTypeNormalizer.getNormalizedType('custom', 'audio') // 返回 'voice'
  /// MessageTypeNormalizer.getNormalizedType('audio', null) // 返回 'voice'
  /// MessageTypeNormalizer.getNormalizedType('voice', null) // 返回 'voice'
  /// ```
  static String getNormalizedType(
    String? msgType,
    String? customType,
  ) {
    String type = msgType?.trim() ?? '';

    // custom -> custom_type
    if (type == 'custom' && customType != null && customType.isNotEmpty) {
      type = customType;
    }

    // audio -> voice
    if (type == 'audio') {
      type = 'voice';
    }

    return type.isEmpty ? 'unsupported' : type;
  }

  /// 将下划线命名转换为小驼峰命名
  ///
  /// ## 示例
  /// ```dart
  /// _toCamelCase('visit_card') // 返回 'visitCard'
  /// _toCamelCase('webrtc_audio') // 返回 'webrtcAudio'
  /// _toCamelCase('voice') // 返回 'voice' (无变化)
  /// ```
  static String _toCamelCase(String input) {
    if (!input.contains('_')) {
      return input; // 没有下划线，直接返回
    }

    final parts = input.split('_');
    if (parts.isEmpty) {
      return input;
    }

    // 第一部分小写，后续部分首字母大写
    final buffer = StringBuffer();
    buffer.write(parts[0].toLowerCase());

    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.isNotEmpty) {
        buffer.write(part[0].toUpperCase());
        if (part.length > 1) {
          buffer.write(part.substring(1).toLowerCase());
        }
      }
    }

    return buffer.toString();
  }
}
