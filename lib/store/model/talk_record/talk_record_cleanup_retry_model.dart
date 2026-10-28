import 'package:flutter/foundation.dart' show kIsWeb;

/// Read-only server decision. Missing or malformed facts never grant retry.
class TalkRecordCleanupRetryCapability {
  const TalkRecordCleanupRetryCapability({
    this.allowed = false,
    this.generation,
    this.exhaustedResources = 0,
    this.protectedResources,
    this.reason = 'unknown',
  });
  final bool allowed;
  final int? generation;
  final int exhaustedResources;
  final int? protectedResources;
  final String reason;
  static const reasons = {
    'eligible',
    'partial_protection',
    'protected',
    'not_exhausted',
    'identity_unverified',
    'permission_denied',
    'not_deleted',
    'unknown',
  };
  bool get canRetry =>
      allowed &&
      generation != null &&
      exhaustedResources > 0 &&
      const {'eligible', 'partial_protection'}.contains(reason);

  static int? counter(dynamic value) =>
      value is int && value >= 0 && (!kIsWeb || value <= 9007199254740991)
      ? value
      : null;

  factory TalkRecordCleanupRetryCapability.fromJson(dynamic raw) {
    if (raw is! Map) return const TalkRecordCleanupRetryCapability();
    final generation = counter(raw['generation']);
    final count = counter(raw['exhausted_resources']);
    final protected = counter(raw['protected_resources']);
    final reason = reasons.contains(raw['reason'])
        ? raw['reason'] as String
        : 'unknown';
    return TalkRecordCleanupRetryCapability(
      allowed:
          raw['allowed'] == true &&
          generation != null &&
          count != null &&
          count > 0,
      generation: generation,
      exhaustedResources: count ?? 0,
      protectedResources: protected,
      reason: reason,
    );
  }
}
