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
  String _status = '';
  TalkRecordAiCoordinator? _coordinator;
  TalkRecordAiRecovery? _recovery;
  String? _recoveryMode;
  TalkRecordAiProvider _asrProvider = TalkRecordAiProvider.minimax;

  Future<void> start(String mode, {TalkRecordAiRecovery? recovery}) async {
    if (_busy) return;
    if (mode == 'transcribe' && !_asrProvider.executionAvailable) {
      setState(() => _status = t.talkRecord.aiDoubaoPendingNotice);
      return;
    }
    final identity = ref.read(talkRecordAiSessionProvider);
    if (identity == null) return;
    final recordId = widget.recordId;
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
                ? '${mode == 'transcribe' ? t.talkRecord.aiAudioExternalNotice : t.talkRecord.aiMaxNotice}\n${t.talkRecord.aiProcessingConsent}'
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
      if (consent != true ||
          !mounted ||
          widget.recordId != recordId ||
          !identity.matches(ref.read(talkRecordAiSessionProvider))) {
        return;
      }
      _coordinator = await ref.read(
        talkRecordAiRuntimeProvider((
          recordId: recordId,
          mode: mode,
          provider: mode == 'transcribe'
              ? _asrProvider
              : TalkRecordAiProvider.zhipu,
        )).future,
      );
      if (!mounted ||
          !identity.matches(ref.read(talkRecordAiSessionProvider))) {
        return;
      }
      setState(() => _status = t.talkRecord.aiProcessingRunning);
      await _coordinator!.execute(
        consentConfirmed: true,
        recoveryConfirmation: recovery,
      );
      if (!mounted ||
          !identity.matches(ref.read(talkRecordAiSessionProvider))) {
        return;
      }
      setState(() {
        _status = t.talkRecord.aiProcessingComplete;
        _recovery = null;
        _recoveryMode = null;
      });
      await ref.read(talkRecordDetailProvider.notifier).reload();
      if (!mounted ||
          !identity.matches(ref.read(talkRecordAiSessionProvider))) {
        return;
      }
      await ref
          .read(talkRecordSegmentsProvider.notifier)
          .bind(recordId, force: true);
      await ref
          .read(talkRecordSpeakersProvider.notifier)
          .bind(recordId, force: true);
    } on TalkRecordAiWorkflowException catch (error) {
      if (mounted && identity.matches(ref.read(talkRecordAiSessionProvider))) {
        _recovery = error.recovery;
        _recoveryMode = error.recovery == null ? null : mode;
        setState(
          () => _status = switch (error.code) {
            'key_invalid' => t.talkRecord.aiProcessingKeyInvalid,
            'insufficient_balance' => t.talkRecord.aiProcessingBalance,
            'provider_outcome_unknown' => t.talkRecord.aiProcessingUnknown,
            _ => t.talkRecord.aiProcessingStopped,
          },
        );
      }
    } on ProviderException catch (error) {
      if (mounted && identity.matches(ref.read(talkRecordAiSessionProvider))) {
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
      if (mounted && identity.matches(ref.read(talkRecordAiSessionProvider))) {
        setState(() => _status = t.talkRecord.aiProcessingStopped);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _coordinator?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(talkRecordAiSessionProvider, (_, _) {
      _coordinator?.cancel();
      setState(() {
        _status = '';
        _busy = false;
        _recovery = null;
        _recoveryMode = null;
      });
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
                onValueChanged: _busy
                    ? (_) {}
                    : (provider) {
                        if (provider == null || provider == _asrProvider) {
                          return;
                        }
                        _coordinator?.cancel();
                        setState(() {
                          _asrProvider = provider;
                          _recovery = null;
                          _recoveryMode = null;
                          _status = '';
                        });
                      },
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(AppSpacing.small),
                onPressed: _busy || !_asrProvider.executionAvailable
                    ? null
                    : () => start('transcribe'),
                child: Text(t.talkRecord.aiProcessTranscribe),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(AppSpacing.small),
                onPressed: _busy ? null : () => start('summarize'),
                child: Text(t.talkRecord.aiProcessSummarize),
              ),
            ],
          ),
          if (!_asrProvider.executionAvailable)
            TalkRecordAiText(t.talkRecord.aiDoubaoPendingNotice),
          if (_status.isNotEmpty) TalkRecordAiText(_status),
          if (_recovery case final TalkRecordAiRecovery recovery)
            CupertinoButton(
              padding: const EdgeInsets.all(AppSpacing.small),
              onPressed: _busy
                  ? null
                  : () => start(_recoveryMode!, recovery: recovery),
              child: Text(t.talkRecord.aiUnknownRecoveryTitle),
            ),
        ],
      ),
    );
  }
}
