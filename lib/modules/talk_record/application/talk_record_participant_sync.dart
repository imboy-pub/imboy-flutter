import 'package:imboy/store/api/talk_record_api.dart';

import 'talk_record_local_binding.dart';

/// Reconcile first: a response-lost PUT must not cause a second replacement.
Future<TalkRecordLocalBinding> syncTalkRecordParticipants({
  required TalkRecordApi api,
  required TalkRecordLocalBinding local,
  required Future<void> Function(TalkRecordLocalBinding) checkpoint,
  required void Function() checkAccount,
}) async {
  if (!local.participantsRequested || local.participantsSynced) return local;
  checkAccount();
  final current = await api.participants(local.recordId);
  checkAccount();
  if (current.data.recordId != local.recordId || current.etag.isEmpty) {
    throw StateError('Participant resource revision unavailable');
  }
  final verified = current.data.matches(local.participants)
      ? current
      : await api.putParticipants(
          local.recordId,
          participants: local.participants,
          ifMatch: current.etag,
        );
  checkAccount();
  if (verified.data.recordId != local.recordId ||
      verified.etag.isEmpty ||
      !verified.data.matches(local.participants)) {
    throw StateError('Participant synchronization not confirmed');
  }
  final synced = local.copyWith(
    participantsSynced: true,
    recordEtag: verified.etag,
  );
  await checkpoint(synced);
  checkAccount();
  return synced;
}
