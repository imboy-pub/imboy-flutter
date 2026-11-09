import 'package:imboy/i18n/strings.g.dart';

/// Inbox timestamps compare local calendar dates, including across DST changes.
///
/// [now] and [yesterdayLabel] keep the display deterministic in tests without
/// changing the app's shared relative-time formatter.
String formatMessageInboxTime(
  int epochMs, {
  DateTime? now,
  String? yesterdayLabel,
}) {
  if (epochMs <= 0) return '';

  final timestamp = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final date = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
  final today = DateTime.utc(reference.year, reference.month, reference.day);

  if (date == today) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (date ==
      DateTime.utc(reference.year, reference.month, reference.day - 1)) {
    return yesterdayLabel ?? t.common.yesterday;
  }
  if (timestamp.year == reference.year) {
    return '${timestamp.month}/${timestamp.day}';
  }
  return '${timestamp.year}/${timestamp.month}/${timestamp.day}';
}
