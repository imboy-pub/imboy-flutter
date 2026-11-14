import 'dart:convert';

import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/config/env.dart';

import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// Sender-only display recovery; this never changes or authenticates wire data.
Future<Map<String, dynamic>?> loadLocalAttachmentPayload(
  MessageModel model, {
  AttachmentUploadTaskRepo? repo,
  UploadKeyStore? keyStore,
}) async {
  if (model.isAuthor != 1 ||
      model.payload != '' ||
      model.e2ee?['meta_version'] != 3 ||
      !{
        'image',
        'imageMulti',
        'video',
        'voice',
        'file',
        'location',
      }.contains(model.msgType) ||
      !{'C2C', 'C2G'}.contains(model.type)) {
    return null;
  }
  final actor = UserRepoLocal.to;
  final uid = actor.currentUid;
  final generation = actor.sessionGeneration;
  final environment = currentEnv;
  final endpoint = Env().apiBaseUrl;
  bool current() =>
      uid.isNotEmpty &&
      actor.currentUid == uid &&
      actor.isCurrentSession(generation) &&
      !actor.isAuthTransitioning &&
      currentEnv == environment &&
      Env().apiBaseUrl == endpoint;
  if (!current() || model.fromId.toString() != uid) {
    return null;
  }
  try {
    return await _loadBoundPayload(
      model,
      repo ?? AttachmentUploadTaskRepo(),
      keyStore,
      uid,
      current,
    );
  } on Object {
    // Missing/corrupt local evidence retains the normal encrypted failure path.
    return null;
  }
}

Future<Map<String, dynamic>?> _loadBoundPayload(
  MessageModel model,
  AttachmentUploadTaskRepo tasks,
  UploadKeyStore? keyStore,
  String uid,
  bool Function() current,
) async {
  final rows = (await tasks.findByAnchor(
    model.id,
    uid,
  )).where((r) => r.businessIntent != null).toList();
  if (!current() || rows.isEmpty) return null;
  final intents = rows
      .map((r) => jsonDecode(r.businessIntent!) as Map<String, dynamic>)
      .toList();
  for (var i = 0; i < rows.length; i++) {
    if (!_matchesJournal(rows[i], intents[i], model, uid, rows.length)) {
      return null;
    }
  }
  final uploader = ResumableAttachmentUploader(repo: tasks, keyStore: keyStore);
  final template = await uploader.restoreMessageTemplate(rows.first);
  if (!current() || template['id'] != model.id || template['authorId'] != uid) {
    return null;
  }
  final message = ResumableAttachmentUploader.messageFromPendingTemplate(
    template,
  );
  final binding = AttachmentUploadTaskRepo.projectionBinding(
    model,
    message.toJson(),
  );
  if (intents.any((i) => i['local_projection_binding'] != binding)) {
    return null;
  }
  final projection = MessageModel.fromMessage(message, currentUid: uid);
  if (projection.msgType != model.msgType) return null;
  return current() ? projection.payloadMap : null;
}

bool _matchesJournal(
  AttachmentUploadTask row,
  Map<String, dynamic> intent,
  MessageModel model,
  String uid,
  int count,
) =>
    row.userId == uid &&
    row.anchorMsgId == model.id &&
    row.stage == AttachmentUploadStage.confirmed &&
    intent['message_id'] == model.id &&
    intent['author_id'] == uid &&
    intent['peer_id'].toString() == model.toId.toString() &&
    intent['chat_type'].toString().toUpperCase() == model.type &&
    intent['conversation_uk3'] == model.conversationUk3 &&
    intent['attachment_kind'] == model.msgType &&
    intent['expected_objects'] == count &&
    {
      'outbox_ready',
      'dispatch_reserved_v2',
      'dispatch_intent',
      'commit_unknown',
      'committed',
    }.contains(intent['state']) &&
    intent['local_projection_binding'] is String;
