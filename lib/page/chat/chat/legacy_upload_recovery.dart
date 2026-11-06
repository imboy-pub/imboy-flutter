import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';

/// Only the original plaintext may be selected for a legacy upload retry.
bool matchesLegacyUpload(AttachmentUploadTask task, Uint8List bytes) =>
    bytes.length == task.plainSize &&
    sha256.convert(bytes).toString() == task.plainSha256;

/// 原记录保留；用户核对后可主动选择文件发起新消息。
Future<void> showLegacyUploadRecovery(
  BuildContext context,
  AttachmentUploadTask task, {
  required bool outboxMayExist,
  required Future<void> Function() selectAndSend,
}) async {
  final select = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t.common.legacyUploadRecoveryTitle),
      content: Text(
        outboxMayExist
            ? t.common.legacyUploadOutboxCheck
            : '${t.common.legacyUploadRecoveryBody}\n${task.fileName}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(t.common.cancel),
        ),
        if (!outboxMayExist)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.common.legacyUploadSelectOriginal),
          ),
      ],
    ),
  );
  if (select != true || !context.mounted) return;
  try {
    await selectAndSend();
  } on LegacyOutboxConflict {
    if (context.mounted) AppLoading.showError(t.common.legacyUploadOutboxCheck);
  } on Object {
    if (context.mounted) AppLoading.showError(t.common.uploadFailed);
  }
}
