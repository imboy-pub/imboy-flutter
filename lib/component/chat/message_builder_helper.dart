import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/store/model/message_model.dart';

/// 聊天消息组件辅助类
///
/// 提供通用的消息处理方法，减少消息组件中的重复代码
///
/// 使用示例：
/// ```dart
/// class MyMessageBuilderState extends State<MyMessageBuilder> {
///   late Future<CustomMessage?> messageFuture;
///
///   @override
///   void initState() {
///     super.initState();
///     messageFuture = MessageBuilderHelper.getMessage(widget.message, widget.info);
///   }
/// }
/// ```
class MessageBuilderHelper {
  MessageBuilderHelper._();

  /// 获取消息对象
  ///
  /// 从 [message] 或 [info] 中获取 CustomMessage 对象
  ///
  /// 优先返回 [message]，如果为空则从 [info] 转换
  ///
  /// 返回：CustomMessage 对象或 null
  static Future<CustomMessage?> getMessage(
    CustomMessage? message,
    Map<String, dynamic>? info,
  ) async {
    if (message != null) {
      return message;
    }
    if (info != null) {
      try {
        return await MessageModel.fromJson(info).toTypeMessage()
            as CustomMessage?;
      } catch (e) {
        // 转换失败，返回 null
        return null;
      }
    }
    return null;
  }

  /// 安全获取消息元数据字段
  ///
  /// 从消息的 metadata 中获取指定字段的值
  ///
  /// 参数：
  /// - [message]: 消息对象
  /// - [key]: 元数据键名
  /// - [defaultValue]: 默认值
  ///
  /// 返回：字段值或默认值
  static T? getMetadata<T>(
    CustomMessage? message,
    String key, {
    T? defaultValue,
  }) {
    final metadata = message?.metadata;
    if (metadata is Map<String, dynamic>) {
      final value = metadata[key];
      if (value is T) {
        return value;
      }
    }
    return defaultValue;
  }

  /// 检查消息是否为特定类型
  ///
  /// 参数：
  /// - [message]: 消息对象
  /// - [customType]: 自定义类型
  ///
  /// 返回：是否匹配
  static bool isMessageType(CustomMessage? message, String customType) {
    return getMetadata<String>(message, 'custom_type') == customType;
  }

  /// 获取消息文本内容
  ///
  /// 尝试从 metadata 中获取文本内容
  /// 注意：CustomMessage 没有 text getter，需要从 metadata 获取
  ///
  /// 参数：
  /// - [message]: 消息对象
  ///
  /// 返回：文本内容或空字符串
  static String getText(CustomMessage? message) {
    if (message == null) return '';

    // CustomMessage 没有 text getter，只能从 metadata 获取
    // 尝试从 metadata 获取
    final metadata = message.metadata;
    if (metadata is Map<String, dynamic>) {
      // 尝试各种可能的文本字段
      for (String key in ['text', 'content', 'message', 'body']) {
        final value = metadata[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return '';
  }

  /// 获取消息 payload
  ///
  /// 获取消息的 payload 元数据
  ///
  /// 参数：
  /// - [message]: 消息对象
  ///
  /// 返回：payload Map 或 null
  static Map<String, dynamic>? getPayload(CustomMessage? message) {
    final payload = getMetadata<Map<String, dynamic>>(message, 'payload');
    return payload;
  }

  /// 验证消息数据完整性
  ///
  /// 检查消息是否包含必要的字段
  ///
  /// 参数：
  /// - [message]: 消息对象
  /// - [requiredFields]: 必需字段列表
  ///
  /// 返回：是否包含所有必需字段
  static bool validateMessage(
    CustomMessage? message,
    List<String> requiredFields,
  ) {
    if (message == null) return false;

    final metadata = message.metadata;
    if (metadata is! Map<String, dynamic>) return false;

    for (String field in requiredFields) {
      if (!metadata.containsKey(field) || metadata[field] == null) {
        return false;
      }
    }

    return true;
  }
}
