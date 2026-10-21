/// Production assembly. The root provider retains this across page navigation.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';

import '../presentation/talk_record_services.dart';
import 'talk_record_capture_api_gateway.dart';
import 'talk_record_attachment_upload_gateway.dart';
import 'talk_record_local_binding.dart';
import 'talk_record_launch_failure.dart';
import 'talk_record_recording_coordinator.dart';

TalkRecordAccount currentTalkRecordAccount() => TalkRecordAccount(
  Env().apiBaseUrl,
  UserRepoLocal.to.isAuthTransitioning ? '' : UserRepoLocal.to.currentUid,
);

Future<TalkRecordRecordingCoordinator>
createTalkRecordRecordingRuntime() async {
  final support = await getApplicationSupportDirectory();
  final keys = SecureTalkRecordKeyStore();
  return TalkRecordRecordingCoordinator(
    store: TalkRecordBindingStore(Directory('${support.path}/talk_record')),
    keys: keys,
    currentAccount: currentTalkRecordAccount,
    captureGateway: TalkRecordApiCaptureGateway(TalkRecordApi()),
    uploadGateway: TalkRecordAttachmentUploadGateway(api: TalkRecordApi()),
    recorderFactory: (directory) => TalkRecordRecorderService(
      baseDirectory: directory,
      keyStore: keys,
      interruptionSource: TalkRecordSystemInterruptionSource(),
    ),
  );
}

class TalkRecordCoordinatorLauncher implements TalkRecordRecordingLauncher {
  TalkRecordCoordinatorLauncher(this.resolve);
  final Future<TalkRecordRecordingCoordinator> Function() resolve;
  @override
  Future<TalkRecordRecordingLaunchResult> launch(
    TalkRecordRecordingDraftRequest request,
  ) async {
    try {
      request.checkCurrentOperation();
      final coordinator = await resolve();
      request.checkCurrentOperation();
      return await coordinator.launch(request);
    } on Object catch (error) {
      return talkRecordLaunchFailure(error);
    }
  }
}
