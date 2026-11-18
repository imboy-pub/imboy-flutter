import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void Function() listenWebAttachmentInput({
  required bool Function(num x, num y) containsPoint,
  required bool Function() acceptsPaste,
  required bool Function() Function() captureInput,
  required Future<void> Function(String, int, Future<Uint8List> Function())
  onFile,
}) {
  Future<void> receive(web.FileList files) async {
    final isCurrent = captureInput();
    final selected = <web.File>[];
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file != null) selected.add(file);
    }
    for (final file in selected) {
      if (!isCurrent()) return;
      await onFile(file.name, file.size, () async {
        final buffer = await file.arrayBuffer().toDart;
        return buffer.toDart.asUint8List();
      });
    }
  }

  final over = ((web.Event raw) {
    final event = raw as web.DragEvent;
    if (containsPoint(event.clientX, event.clientY) &&
        event.dataTransfer?.types.toDart.any((x) => x.toDart == 'Files') ==
            true) {
      event.preventDefault();
    }
  }).toJS;
  final drop = ((web.Event raw) {
    final event = raw as web.DragEvent;
    final files = event.dataTransfer?.files;
    if (files == null ||
        files.length == 0 ||
        !containsPoint(event.clientX, event.clientY)) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    unawaited(receive(files));
  }).toJS;
  final paste = ((web.Event raw) {
    final event = raw as web.ClipboardEvent;
    final files = event.clipboardData?.files;
    if (!acceptsPaste() || files == null || files.length == 0) return;
    event.preventDefault();
    event.stopPropagation();
    unawaited(receive(files));
  }).toJS;
  web.document.addEventListener('dragover', over);
  web.document.addEventListener('drop', drop);
  web.document.addEventListener('paste', paste);
  return () {
    web.document.removeEventListener('dragover', over);
    web.document.removeEventListener('drop', drop);
    web.document.removeEventListener('paste', paste);
  };
}

void revokePickedAttachmentUri(Uri uri) {
  if (uri.scheme == 'blob') web.URL.revokeObjectURL(uri.toString());
}
