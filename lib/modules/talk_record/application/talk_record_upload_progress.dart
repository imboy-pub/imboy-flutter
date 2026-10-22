import 'talk_record_local_binding.dart';

/// Only server-confirmed parts advance the count. Completion means the server
/// accepted the manifest, not that assembled audio is already playable.
enum TalkRecordUploadPhase {
  register,
  upload,
  confirm,
  submitting,
  completed,
  failed,
}

class TalkRecordUploadSnapshot {
  const TalkRecordUploadSnapshot({
    required this.account,
    required this.recordId,
    required this.sessionId,
    required this.totalParts,
    required this.confirmedParts,
    required this.phase,
    this.pendingBinding,
  });
  final TalkRecordAccount account;
  final String recordId, sessionId;
  final int totalParts, confirmedParts;
  final TalkRecordUploadPhase phase;

  /// Added by the coordinator only after its validated bind has been persisted.
  final TalkRecordLocalBinding? pendingBinding;

  bool matches(TalkRecordLocalBinding binding) =>
      account == binding.account &&
      recordId == binding.recordId &&
      sessionId == binding.sessionId;
}

abstract interface class TalkRecordUploadProgressSource {
  TalkRecordUploadSnapshot? get uploadSnapshot;
  Stream<TalkRecordUploadSnapshot> get uploadUpdates;
}
