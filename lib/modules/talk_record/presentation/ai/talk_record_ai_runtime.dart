import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import '../../application/ai/talk_record_ai_checkpoint.dart';
import '../../application/ai/talk_record_ai_coordinator.dart';
import '../../application/ai/talk_record_ai_credentials.dart';
import '../../application/ai/talk_record_ai_local_audio.dart';
import '../talk_record_providers.dart';
import 'talk_record_ai_providers.dart';

typedef TalkRecordAiTask = ({
  EntityId recordId,
  String mode,
  TalkRecordAiProvider provider,
});

final talkRecordAiRuntimeProvider =
    FutureProvider.family<TalkRecordAiCoordinator, TalkRecordAiTask>((
      ref,
      task,
    ) async {
      if (task.mode == 'transcribe' && !task.provider.executionAvailable) {
        throw const TalkRecordAiWorkflowException('provider_not_integrated');
      }
      final credentials = ref.watch(talkRecordAiCredentialsProvider);
      if (credentials == null) {
        throw const TalkRecordAiWorkflowException('account_changed');
      }
      final recordings = await ref.watch(
        talkRecordRecordingRuntimeProvider.future,
      );
      final account = recordings.currentAccount();
      void guard() {
        if (!ref.mounted ||
            recordings.currentAccount() != account ||
            account.userId != credentials.scope.accountId ||
            Uri.tryParse(account.endpoint)?.origin !=
                credentials.scope.deploymentOrigin ||
            !credentials.scope.matches(credentials.currentScope()) ||
            credentials.currentAuthSessionEpoch() !=
                credentials.authSessionEpoch) {
          throw const TalkRecordAiWorkflowException('account_changed');
        }
      }

      guard();
      final identity = jsonEncode([
        credentials.scope.deploymentOrigin,
        credentials.scope.accountId,
        task.recordId,
        task.mode,
      ]);
      final coordinator = TalkRecordAiCoordinator(
        recordId: task.recordId,
        mode: task.mode,
        asrProvider: task.provider,
        credentials: credentials,
        checkpoints: TalkRecordAiCheckpointStore(
          Directory(
            '${recordings.store.audioDirectory(account).parent.path}/ai',
          ),
          recordings.keys,
          identity,
        ),
        gateway: TalkRecordAiApiGateway(TalkRecordApi()),
        guard: guard,
        audio: TalkRecordAiLocalAudio(recordings, task.recordId, guard).read,
      );
      ref.onDispose(coordinator.cancel);
      return coordinator;
    }, retry: (_, _) => null);
