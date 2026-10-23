import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;
import 'package:imboy/theme/default/app_spacing.dart';

import '../../application/ai/talk_record_ai_coordinator.dart';
import '../../application/ai/talk_record_ai_credentials.dart';
import '../detail/talk_record_detail_providers.dart';
import 'talk_record_ai_providers.dart';
import 'talk_record_ai_runtime.dart';
import 'talk_record_ai_widgets.dart';

class TalkRecordAiProcessingPanel extends ConsumerStatefulWidget {
  const TalkRecordAiProcessingPanel({super.key, required this.recordId});
  final EntityId recordId;
  @override
  ConsumerState<TalkRecordAiProcessingPanel> createState() =>
      TalkRecordAiProcessingPanelState();
}

class TalkRecordAiProcessingPanelState
    extends ConsumerState<TalkRecordAiProcessingPanel> {
  bool _busy = false;
  bool _controlBusy = false;
  int _viewEpoch = 0;
  String _status = '';
  TalkRecordAiCoordinator? _coordinator;
  String? _coordinatorMode;
  TalkRecordAiRecovery? _recovery;
  String? _recoveryMode;
  TalkRecordAiProvider _asrProvider = TalkRecordAiProvider.minimax;

  Future<void> start(String mode, {TalkRecordAiRecovery? recovery}) async {
    if (_busy || _controlBusy) return;
    if (mode == 'transcribe' && !_asrProvider.executionAvailable) {
      setState(() => _status = t.talkRecord.aiDoubaoPendingNotice);
      return;
    }
    final identity = ref.read(talkRecordAiSessionProvider);
    if (identity == null) return;
    final recordId = widget.recordId, epoch = _viewEpoch;
    setState(() => _busy = true);
    try {
      final consent = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialog) => CupertinoAlertDialog(
          title: Text(
            recovery == null
                ? t.talkRecord.processingRecoveryTitle
                : t.talkRecord.aiUnknownRecoveryTitle,
          ),
          content: Text(
            recovery == null
                ? '${mode == 'transcribe' ? (_asrProvider == TalkRecordAiProvider.doubao ? t.talkRecord.aiDoubaoExternalNotice : t.talkRecord.aiAudioExternalNotice) : t.talkRecord.aiMaxNotice}\n${t.talkRecord.aiProcessingConsent}'
                : '${t.talkRecord.aiUnknownRecoveryNotice}\n${t.talkRecord.aiUnknownRecoveryRun}: ${recovery.previousRunId}\n${t.talkRecord.aiUnknownRecoveryIntents}: ${recovery.intentDetails}',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(t.talkRecord.aiCancel),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialog, true),
              isDestructiveAction: recovery != null,
              child: Text(
                recovery == null
                    ? t.common.confirm
                    : t.talkRecord.aiUnknownRecoveryConfirm,
              ),
            ),
          ],
        ),
      );
      if (consent != true || !_viewCurrent(identity, recordId, epoch)) {
        return;
      }
      final coordinator = await ref.read(
        talkRecordAiRuntimeProvider((
          recordId: recordId,
          mode: mode,
          provider: mode == 'transcribe'
              ? _asrProvider
              : TalkRecordAiProvider.zhipu,
        )).future,
      );
      if (!_viewCurrent(identity, recordId, epoch)) {
        return;
      }
      _coordinator = coordinator;
      _coordinatorMode = mode;
      setState(() => _status = t.talkRecord.aiProcessingRunning);
      await _coordinator!.execute(
        consentConfirmed: true,
        recoveryConfirmation: recovery,
      );
      if (!_viewCurrent(identity, recordId, epoch)) {
        return;
      }
      setState(() {
        _status = t.talkRecord.aiProcessingComplete;
        _recovery = null;
        _recoveryMode = null;
      });
      await ref.read(talkRecordDetailProvider.notifier).reload();
      if (!_viewCurrent(identity, recordId, epoch)) {
        return;
      }
      await ref
          .read(talkRecordSegmentsProvider.notifier)
          .bind(recordId, force: true);
      if (!_viewCurrent(identity, recordId, epoch)) return;
      await ref
          .read(talkRecordSpeakersProvider.notifier)
          .bind(recordId, force: true);
    } on TalkRecordAiWorkflowException catch (error) {
      if (_viewCurrent(identity, recordId, epoch)) {
        _recovery = error.recovery;
        _recoveryMode = error.recovery == null ? null : mode;
        setState(
          () => _status = switch (error.code) {
            'key_invalid' => t.talkRecord.aiProcessingKeyInvalid,
            'insufficient_balance' => t.talkRecord.aiProcessingBalance,
            'provider_outcome_unknown' => t.talkRecord.aiProcessingUnknown,
            'provider_processing' => t.talkRecord.aiProviderPending,
            _ => t.talkRecord.aiProcessingStopped,
          },
        );
      }
    } on ProviderException catch (error) {
      if (_viewCurrent(identity, recordId, epoch)) {
        setState(
          () => _status =
              error.exception is TalkRecordAiWorkflowException &&
                  (error.exception as TalkRecordAiWorkflowException).code ==
                      'key_invalid'
              ? t.talkRecord.aiProcessingKeyInvalid
              : t.talkRecord.aiProcessingStopped,
        );
      }
    } on Object {
      if (_viewCurrent(identity, recordId, epoch)) {
        setState(() => _status = t.talkRecord.aiProcessingStopped);
      }
    } finally {
      if (_viewCurrent(identity, recordId, epoch)) {
        setState(() => _busy = false);
      }
    }
  }

  bool _viewCurrent(
    TalkRecordAiIdentity identity,
    EntityId record,
    int epoch,
  ) =>
      mounted &&
      epoch == _viewEpoch &&
      widget.recordId == record &&
      identity.matches(ref.read(talkRecordAiSessionProvider));
  Future<void> _providerControl(
    bool resubmit, {
    bool preparation = false,
  }) async {
    if (_controlBusy) return;
    final coordinator = _coordinator;
    final record = widget.recordId, epoch = _viewEpoch;
    final identity = ref.read(talkRecordAiSessionProvider);
    if (coordinator == null || identity == null) return;
    final confirmed = await _confirmProviderControl(resubmit, preparation);
    if (confirmed != true ||
        !_viewCurrent(identity, record, epoch) ||
        !identical(coordinator, _coordinator)) {
      return;
    }
    setState(() => _controlBusy = true);
    try {
      await _performProviderControl(
        coordinator,
        resubmit,
        preparation,
        () => _viewCurrent(identity, record, epoch),
      );
      if (_viewCurrent(identity, record, epoch)) {
        setState(
          () => _status = resubmit
              ? t.talkRecord.aiProcessingComplete
              : t.talkRecord.aiProviderCancelled,
        );
      }
    } on TalkRecordAiWorkflowException catch (error) {
      if (_viewCurrent(identity, record, epoch)) {
        setState(
          () => _status = error.code == 'provider_processing'
              ? t.talkRecord.aiProviderPending
              : t.talkRecord.aiProcessingStopped,
        );
      }
    } on Object {
      if (_viewCurrent(identity, record, epoch)) {
        setState(() => _status = t.talkRecord.aiProcessingStopped);
      }
    } finally {
      if (_viewCurrent(identity, record, epoch)) {
        setState(() => _controlBusy = false);
      }
    }
  }

  Future<void> _performProviderControl(
    TalkRecordAiCoordinator coordinator,
    bool resubmit,
    bool preparation,
    bool Function() current,
  ) async {
    if (resubmit) {
      if (preparation) {
        await coordinator.resumeProviderPreparation(consentConfirmed: true);
      } else {
        await coordinator.resubmitProviderTask(
          consentConfirmed: true,
          duplicateChargeConfirmed: true,
        );
      }
      if (!current()) {
        coordinator.cancel();
        return;
      }
      await coordinator.execute(consentConfirmed: true);
    } else {
      await coordinator.cancelProviderTask();
    }
  }

  Future<bool?> _confirmProviderControl(bool resubmit, bool preparation) async {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: Text(
          preparation
              ? t.talkRecord.aiProviderResumePreparation
              : resubmit
              ? t.talkRecord.aiProviderResubmit
              : t.talkRecord.aiProviderCancel,
        ),
        content: Text(
          preparation
              ? '${t.talkRecord.aiProviderResumeNotice}\n${t.talkRecord.aiProcessingConsent}'
              : resubmit
              ? '${t.talkRecord.aiProviderResubmitNotice}\n${t.talkRecord.aiProcessingConsent}'
              : t.talkRecord.aiProviderCancelNotice,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.talkRecord.aiCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  void _expireView() {
    _viewEpoch++;
    _coordinator?.cancel();
    _coordinator = null;
    _coordinatorMode = null;
    _status = '';
    _busy = false;
    _controlBusy = false;
    _recovery = null;
    _recoveryMode = null;
  }

  @override
  void didUpdateWidget(covariant TalkRecordAiProcessingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId) _expireView();
  }

  @override
  void dispose() {
    _viewEpoch++;
    _coordinator?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(talkRecordAiSessionProvider, (_, _) {
      setState(_expireView);
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CupertinoSlidingSegmentedControl<TalkRecordAiProvider>(
                groupValue: _asrProvider,
                children: {
                  for (final provider in [
                    TalkRecordAiProvider.doubao,
                    TalkRecordAiProvider.minimax,
                  ])
                    provider: Padding(
                      padding: const EdgeInsets.all(AppSpacing.small),
                      child: Text(talkRecordAiProviderTitle(provider)),
                    ),
                },
                onValueChanged: (_busy || _controlBusy)
                    ? (_) {}
                    : (provider) {
                        if (provider == null || provider == _asrProvider) {
                          return;
                        }
                        _coordinator?.cancel();
                        setState(() {
                          _expireView();
                          _asrProvider = provider;
                          _recovery = null;
                          _recoveryMode = null;
                          _status = '';
                        });
                      },
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(AppSpacing.small),
                onPressed:
                    _busy || _controlBusy || !_asrProvider.executionAvailable
                    ? null
                    : () => start('transcribe'),
                child: Text(t.talkRecord.aiProcessTranscribe),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(AppSpacing.small),
                onPressed: (_busy || _controlBusy)
                    ? null
                    : () => start('summarize'),
                child: Text(t.talkRecord.aiProcessSummarize),
              ),
            ],
          ),
          if (!_asrProvider.executionAvailable)
            TalkRecordAiText(t.talkRecord.aiDoubaoPendingNotice),
          if (_status.isNotEmpty) TalkRecordAiText(_status),
          if (_asrProvider == TalkRecordAiProvider.doubao &&
              TalkRecordAiProvider.doubaoEnabled &&
              _coordinator != null &&
              _coordinatorMode == 'transcribe') ...[
            CupertinoButton(
              padding: const EdgeInsets.all(AppSpacing.small),
              onPressed: _controlBusy ? null : () => _providerControl(false),
              child: Text(t.talkRecord.aiProviderCancel),
            ),
            if (_coordinator?.canResumeProviderPreparation == true)
              CupertinoButton(
                padding: const EdgeInsets.all(AppSpacing.small),
                onPressed: (_busy || _controlBusy)
                    ? null
                    : () => _providerControl(true, preparation: true),
                child: Text(t.talkRecord.aiProviderResumePreparation),
              ),
            if (_coordinator?.canResubmitProviderTask == true)
              CupertinoButton(
                padding: const EdgeInsets.all(AppSpacing.small),
                onPressed: (_busy || _controlBusy)
                    ? null
                    : () => _providerControl(true),
                child: Text(t.talkRecord.aiProviderResubmit),
              ),
          ],
          if (_recovery case final TalkRecordAiRecovery recovery)
            CupertinoButton(
              padding: const EdgeInsets.all(AppSpacing.small),
              onPressed: (_busy || _controlBusy)
                  ? null
                  : () => start(_recoveryMode!, recovery: recovery),
              child: Text(t.talkRecord.aiUnknownRecoveryTitle),
            ),
        ],
      ),
    );
  }
}
