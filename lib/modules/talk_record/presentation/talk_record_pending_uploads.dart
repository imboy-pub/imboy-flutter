import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../application/talk_record_local_binding.dart';
import '../application/talk_record_capture_api_gateway.dart';
import '../application/talk_record_processing_consent.dart';

import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

import 'talk_record_auth.dart';
import 'talk_record_participant_picker.dart';

import 'package:imboy/theme/default/app_spacing.dart';

import '../application/talk_record_recording_coordinator.dart';
import '../application/talk_record_recording_runtime.dart';
import 'talk_record_entry_context.dart';
import 'talk_record_providers.dart';

/// Auth changes invalidate the projection; transitions resolve to an empty UID.
final talkRecordPendingAccountProvider = Provider<TalkRecordAccount>((ref) {
  void changed() => ref.invalidateSelf();
  UserRepoLocal.to.addAuthListener(changed);
  ref.onDispose(() => UserRepoLocal.to.removeAuthListener(changed));
  return currentTalkRecordAccount();
});

final talkRecordPendingRetryProvider =
    Provider<Future<void> Function(TalkRecordPendingEnded)>((ref) {
      var authEpoch = 0;
      final remove = ref.read(talkRecordAuthSubscribeProvider)(() {
        authEpoch++;
      });
      ref.onDispose(remove);
      return (item) async {
        final epoch = authEpoch;
        void check() {
          if (!ref.mounted ||
              epoch != authEpoch ||
              ref.read(talkRecordPendingAccountProvider) !=
                  item.binding.account) {
            throw StateError('Pending recording account changed');
          }
        }

        check();
        final runtime = await ref.read(
          talkRecordRecordingRuntimeProvider.future,
        );
        check();
        await runtime.retryPending(item.binding, checkCurrentOperation: check);
        check();
        if (ref.mounted) {
          await ref.read(talkRecordListProvider.notifier).reload();
        }
      };
    });

/// Explicit correction then the existing authorized pipeline; no audio deletion
/// and no automatic removal of contacts whose directory eligibility changed.
final talkRecordPendingParticipantsEditProvider =
    Provider<
      Future<void> Function(
        TalkRecordPendingEnded,
        List<TalkRecordParticipantInput>,
      )
    >((ref) {
      var authEpoch = 0;
      final remove = ref.read(talkRecordAuthSubscribeProvider)(() {
        authEpoch++;
      });
      ref.onDispose(remove);
      return (item, selected) async {
        final epoch = authEpoch;
        void check() {
          if (!ref.mounted ||
              epoch != authEpoch ||
              ref.read(talkRecordPendingAccountProvider) !=
                  item.binding.account) {
            throw StateError('Pending recording account changed');
          }
        }

        check();
        final runtime = await ref.read(
          talkRecordRecordingRuntimeProvider.future,
        );
        check();
        final updated = await runtime.updatePendingParticipants(
          item.binding,
          selected,
          checkCurrentOperation: check,
        );
        check();
        await runtime.retryPending(updated, checkCurrentOperation: check);
        check();
        await ref.read(talkRecordListProvider.notifier).reload();
      };
    });

final talkRecordPendingUploadsProvider =
    FutureProvider<List<TalkRecordPendingEnded>>((ref) async {
      ref.watch(talkRecordPendingAccountProvider);
      // Ending capture and changing account both invalidate this projection.
      ref.watch(
        talkRecordActiveCaptureProvider.select(
          (capture) => (capture.visible, capture.phase, capture.title),
        ),
      );
      final runtime = await ref.watch(
        talkRecordRecordingRuntimeProvider.future,
      );
      return runtime.pendingEnded();
    });

/// Ended local recordings remain discoverable until server completion succeeds.
class TalkRecordPendingUploads extends ConsumerStatefulWidget {
  const TalkRecordPendingUploads({super.key, required this.contextFilter});
  final TalkRecordEntryContext contextFilter;

  @override
  ConsumerState<TalkRecordPendingUploads> createState() =>
      _PendingUploadsState();
}

class _PendingUploadsState extends ConsumerState<TalkRecordPendingUploads> {
  bool _busy = false;
  bool _failed = false;
  int _authEpoch = 0;
  void Function()? _removeAuth;

  @override
  void initState() {
    super.initState();
    _removeAuth = ref.read(talkRecordAuthSubscribeProvider)(() {
      _authEpoch++;
    });
  }

  @override
  void dispose() {
    _removeAuth?.call();
    super.dispose();
  }

  Future<void> _retry(TalkRecordPendingEnded item) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    final epoch = _authEpoch;
    void check() {
      if (!mounted ||
          epoch != _authEpoch ||
          ref.read(talkRecordPendingAccountProvider) != item.binding.account) {
        throw StateError('Pending recording account changed');
      }
    }

    try {
      var selected = item;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await ref.read(talkRecordPendingRetryProvider)(selected);
          check();
          return;
        } on TalkRecordUploadPolicyRequired {
          final next = await _confirmPolicy(selected, check);
          check();
          if (next == null) return;
          selected = next;
        } on TalkRecordProcessingConsentRequired catch (required) {
          final next = await _confirmProcessing(selected, required, check);
          check();
          if (next == null) return;
          selected = next;
        }
      }
      throw StateError('Recording policy changed again; retry explicitly');
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        ref.invalidate(talkRecordPendingUploadsProvider);
        setState(() => _busy = false);
      }
    }
  }

  Future<TalkRecordPendingEnded?> _confirmPolicy(
    TalkRecordPendingEnded item,
    void Function() check,
  ) async {
    final cap = await ref.read(talkRecordListServiceProvider).capabilities();
    check();
    if (!cap.recordingEnabled || cap.policyVersion.isEmpty) {
      throw StateError('Recording upload unavailable');
    }
    if (!mounted) return null;
    final accepted = await _showNotice(cap.policyVersion);
    check();
    if (accepted != true) return null;
    final runtime = await ref.read(talkRecordRecordingRuntimeProvider.future);
    check();
    final binding = await runtime.confirmPendingUploadPolicy(
      item.binding,
      cap.policyVersion,
      checkCurrentOperation: check,
    );
    check();
    return TalkRecordPendingEnded(binding, item.durationMs, item.segmentCount);
  }

  Future<TalkRecordPendingEnded?> _confirmProcessing(
    TalkRecordPendingEnded item,
    TalkRecordProcessingConsentRequired required,
    void Function() check,
  ) async {
    final cap = required.capabilities;
    check();
    if (!mounted) return null;
    final available = talkRecordProcessingAvailable(
      cap,
      item.binding.processingMode,
    );
    final accepted = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(t.talkRecord.processingRecoveryTitle),
        content: SingleChildScrollView(
          child: Text(
            '${available ? t.talkRecord.processingRecoveryHint : t.talkRecord.processingRecoveryUnavailable}\n\n'
            '${item.binding.processingMode == 'summarize' ? t.talkRecord.processingSummarize : t.talkRecord.processingTranscribe}\n${cap.processorLocationCategory}\n'
            'PV: ${cap.policyVersion}\nPCV: ${cap.processorConfigVersion}',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.talkRecord.keepRecordingLocal),
          ),
          if (available)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t.talkRecord.confirmProcessingUpload),
            ),
        ],
      ),
    );
    check();
    if (accepted != true) return null;
    final runtime = await ref.read(talkRecordRecordingRuntimeProvider.future);
    check();
    final updated = await runtime.confirmPendingProcessingConsent(
      item.binding,
      cap.policyVersion,
      cap.processorConfigVersion,
      checkCurrentOperation: check,
    );
    check();
    return TalkRecordPendingEnded(updated, item.durationMs, item.segmentCount);
  }

  Future<bool?> _showNotice(String version) => showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(t.talkRecord.uploadNoticeTitle),
      content: Text(
        '${t.talkRecord.uploadNoticeHint}\n\n'
        '${t.talkRecord.noticeCheckbox}\n$version',
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(t.common.confirm),
        ),
      ],
    ),
  );

  Future<void> _editParticipants(TalkRecordPendingEnded item) async {
    final authEpoch = _authEpoch;
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final selected = await showTalkRecordParticipantPicker(
        context,
        entryContext: item.binding.context,
        selected: item.binding.participants,
      );
      if (!mounted || selected == null || authEpoch != _authEpoch) {
        return;
      }
      if (ref.read(talkRecordPendingAccountProvider) != item.binding.account) {
        return;
      }
      await ref.read(talkRecordPendingParticipantsEditProvider)(item, selected);
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        ref.invalidate(talkRecordPendingUploadsProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(talkRecordPendingAccountProvider);
    if (account.userId.isEmpty) {
      return const SizedBox.shrink();
    }
    final pending = ref.watch(talkRecordPendingUploadsProvider);
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => CupertinoButton(
        onPressed: () => ref.invalidate(talkRecordPendingUploadsProvider),
        child: Text(t.common.retryFailedPleaseCheckNetwork),
      ),
      data: (items) {
        final visible = items.where(
          (item) =>
              item.binding.account == account &&
              widget.contextFilter.matchesContext(
                scope: item.binding.context.scope,
                organizationId: item.binding.context.organizationId,
                workspaceId: item.binding.context.workspaceId,
              ),
        );
        return Column(
          children: [
            if (_failed) Text(t.common.retryFailedPleaseCheckNetwork),
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.binding.title.isEmpty
                          ? t.talkRecord.untitledRecord
                          : item.binding.title,
                    ),
                    Text(t.talkRecord.localDraftBadge),
                    Wrap(
                      children: [
                        CupertinoButton(
                          onPressed: _busy
                              ? null
                              : () => _editParticipants(item),
                          child: Text(
                            '${t.talkRecord.collabParticipantsLabel} · ${t.common.edit}',
                          ),
                        ),
                        CupertinoButton(
                          onPressed: _busy ? null : () => _retry(item),
                          child: Text(
                            _busy
                                ? t.common.uploading
                                : item.binding.uploadAttempted
                                ? t.talkRecord.retryRecordingUpload
                                : t.talkRecord.uploadRecording,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
