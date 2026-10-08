import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_type_constants.dart';

/// Returns null for other message types; collaboration cards keep their title.
String? groupCollaborationSummary(
  String type,
  Map<String, dynamic> payload, {
  bool includeLabel = false,
  String fallbackTitle = '',
}) {
  final label = switch (type) {
    MessageType.groupVote => t.groupVote.title,
    MessageType.groupTask => t.groupTask.title,
    MessageType.groupSchedule => t.groupSchedule.title,
    _ => null,
  };
  if (label == null) return null;
  final title = payload['title']?.toString().trim() ?? '';
  final fallback = fallbackTitle.trim();
  final generic = {'[消息]', '[新消息]', '[$label]'};
  final text = title.isNotEmpty
      ? title
      : generic.contains(fallback)
      ? ''
      : fallback;
  return includeLabel ? '[$label]$text' : text;
}
