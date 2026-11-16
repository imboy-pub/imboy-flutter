import 'dart:typed_data';

void Function() listenWebAttachmentInput({
  required bool Function(num x, num y) containsPoint,
  required bool Function() acceptsPaste,
  required bool Function() Function() captureInput,
  required Future<void> Function(String, int, Future<Uint8List> Function())
  onFile,
}) => () {};

void revokePickedAttachmentUri(Uri uri) {}
