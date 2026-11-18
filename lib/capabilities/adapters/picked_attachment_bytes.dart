import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Native files and browser Blob-backed picks share the picker byte stream.
/// The caller supplies its existing business limit and session/owner guard.
Future<Uint8List> readPickedAttachmentBytes(
  PlatformFile file, {
  required int maxBytes,
  required void Function() requireCurrent,
  bool knownLengthOnly = false,
}) async {
  if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  requireCurrent();
  // Web selection must not call a length fallback that buffers an unknown file.
  final declaredLength = knownLengthOnly
      ? file.lengthSync()
      : await file.length();
  requireCurrent();
  if (declaredLength != null &&
      (declaredLength <= 0 || declaredLength > maxBytes)) {
    throw StateError('attachment source size is not allowed');
  }
  final builder = BytesBuilder();
  var size = 0;
  await for (final chunk in file.readAsByteStream()) {
    requireCurrent();
    if (chunk.length > maxBytes - size) {
      throw StateError('attachment source exceeds size limit');
    }
    builder.add(chunk);
    size += chunk.length;
  }
  requireCurrent();
  if (size == 0 || (declaredLength != null && declaredLength != size)) {
    throw StateError('attachment source length changed or is empty');
  }
  return builder.takeBytes();
}
