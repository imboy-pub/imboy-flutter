import 'package:imboy/modules/messaging/public.dart' show MessagingFacade;

/// 已经创建的资源不能因本机消息写入失败变成“创建失败”，避免重复创建。
Future<Map<String, dynamic>?> persistGroupCollabCreatedMessage(
  Map<String, dynamic>? created, {
  Future<void> Function(String, Map<String, dynamic>)? processMessage,
}) async {
  if (created == null) return null;
  final message = created['chat_message'];
  if (message is! Map<String, dynamic>) return created;
  try {
    await (processMessage ?? MessagingFacade.instance.processMessage)(
      'C2G',
      Map<String, dynamic>.from(message),
    );
    return created;
  } catch (_) {
    return {...created, 'message_status': 'failed'};
  }
}
