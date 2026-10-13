import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

enum CsAttachmentSaveResult { saved, cancelled, stale, failed }

typedef CsSaveFile = Future<Uri?> Function({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
});
String csSafeAttachmentName(String raw) {
  final name = raw
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*]'), '_')
      .trim();
  if (name.isEmpty || name == '.' || name == '..') return 'attachment';
  return String.fromCharCodes(name.runes.take(180));
}

class CsAttachmentSave {
  CsAttachmentSave({CsSaveFile? saveFile}) : _save = saveFile ?? _saveFile;
  final CsSaveFile _save;
  Future<CsAttachmentSaveResult> save({
    required CsVerifiedAssetContent content,
    required String fileName,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return CsAttachmentSaveResult.stale;
    try {
      final result = await _save(
        fileName: csSafeAttachmentName(fileName),
        bytes: content.bytes,
        mimeType: content.mime,
      );
      if (!isCurrent()) return CsAttachmentSaveResult.stale;
      return result == null
          ? CsAttachmentSaveResult.cancelled
          : CsAttachmentSaveResult.saved;
    } on Object {
      return isCurrent()
          ? CsAttachmentSaveResult.failed
          : CsAttachmentSaveResult.stale;
    }
  }

  static Future<Uri?> _saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) =>
      FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
}
