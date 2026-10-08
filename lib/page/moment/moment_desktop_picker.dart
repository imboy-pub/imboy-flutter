import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/upload/batch_upload_controller.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'moment_interactions.dart';

bool momentFileIsVideo(PlatformFile file) => const {
  'mp4',
  'mov',
  'm4v',
  'webm',
  'mkv',
  'avi',
  '3gp',
}.contains(file.extension?.toLowerCase());

MomentMediaValidationResult validateMomentFiles(
  List<UploadItem<Map<String, dynamic>>> existing,
  List<PlatformFile> selected,
) => validateMediaSelection([
  for (final item in existing)
    {
      'type': item.isVideoFile || item.asset?.type == AssetType.video
          ? 'video'
          : 'image',
    },
  for (final file in selected)
    {'type': momentFileIsVideo(file) ? 'video' : 'image'},
]);

Future<void> pickMomentDesktopMedia(
  BuildContext context,
  BatchUploadController<Map<String, dynamic>> uploads,
) async {
  List<PlatformFile> result;
  try {
    result = await FilePicker.pickFiles(type: FileType.media);
  } catch (_) {
    if (context.mounted) {
      AppLoading.showError(context.t.common.selectImageFailed);
    }
    return;
  }
  if (!context.mounted || result.isEmpty) return;
  if (result.any((file) => file.path == null || file.path!.isEmpty)) {
    AppLoading.showError(context.t.common.selectImageFailed);
    return;
  }
  final validation = validateMomentFiles(uploads.items, result);
  if (!validation.ok) {
    final t = context.t;
    AppLoading.showInfo(switch (validation.error) {
      momentMediaErrorMixed => t.chat.momentsMediaMixedImageAndVideo,
      momentMediaErrorTooManyVideos => t.chat.momentsMediaTooManyVideos,
      _ => t.chat.momentsMediaTooManyImages,
    });
    return;
  }
  await uploads.addFilesAndUpload([
    for (final file in result) File(file.path!),
  ], isVideo: momentFileIsVideo(result.first));
  if (context.mounted && uploads.hasFailed) {
    AppLoading.showError(context.t.common.momentsUploadFailed);
  }
}
