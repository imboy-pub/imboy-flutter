import 'burn_after_ms_rules.dart';
import 'burn_read_at_rules.dart';

/// Absolute burn deadline shared by chat and search (epoch milliseconds).
///
/// A recipient without a read timestamp has no countdown. Only the sender may
/// supply the message creation time as [fallbackStartMs]; never write that
/// fallback into the payload sent to the recipient. A null result means that
/// the payload does not establish a valid burn deadline, not that it is visible
/// regardless of revocation or a burn tombstone.
int? burnExpiresAtMs(Map<String, dynamic> payload, {int fallbackStartMs = 0}) {
  if (payload['burn'] != true && payload['is_burn'] != true) return null;
  final duration = parseBurnAfterMs(
    payload['burn_after_ms'] ?? payload['expiry_time'],
  );
  if (duration == null) return null;
  final readAt = parseBurnReadAtMs(payload);
  final start = readAt > 0 ? readAt : fallbackStartMs;
  return start > 0 ? start + duration : null;
}

/// The deadline itself is expired, matching chat's existing deletion boundary.
bool isBurnExpiredAt(
  Map<String, dynamic> payload,
  int nowMs, {
  int fallbackStartMs = 0,
}) {
  final deadline = burnExpiresAtMs(payload, fallbackStartMs: fallbackStartMs);
  return deadline != null && deadline <= nowMs;
}
