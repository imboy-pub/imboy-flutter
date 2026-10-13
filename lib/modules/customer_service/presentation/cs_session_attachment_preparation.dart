import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' as mime;

class CsUnsupportedSeatAttachment implements Exception {}

class CsPreparedSeatAttachment {
  final String mime, fileName;
  final Uint8List bytes;
  const CsPreparedSeatAttachment(this.mime, this.fileName, this.bytes);
}

/// Attachment preparation stops at every asynchronous boundary before any write.
class CsSessionAttachmentPreparation {
  CsSessionAttachmentPreparation({
    Future<List<PlatformFile>> Function()? pickFiles,
    Future<Uint8List> Function(File)? readHead,
    Future<Uint8List> Function(File)? readBytes,
  }) : _pick = pickFiles ?? _pickFiles,
       _head = readHead ?? _readHead,
       _bytes = readBytes ?? _readBytes;
  final Future<List<PlatformFile>> Function() _pick;
  final Future<Uint8List> Function(File) _head, _bytes;

  Future<CsPreparedSeatAttachment?> prepare({
    required bool Function() canWrite,
  }) async {
    if (!canWrite()) return null;
    final files = await _pick();
    if (!canWrite() || files.length != 1 || files.single.path == null) {
      return null;
    }
    final picked = files.single, file = File(files.single.path!);
    final header = await _head(file);
    if (!canWrite()) return null;
    final detected = mime.lookupMimeType(picked.path!, headerBytes: header);
    if (detected == null || detected.isEmpty) {
      throw CsUnsupportedSeatAttachment();
    }
    final bytes = await _bytes(file);
    if (!canWrite()) return null;
    return CsPreparedSeatAttachment(detected, picked.name, bytes);
  }

  static Future<List<PlatformFile>> _pickFiles() =>
      FilePicker.pickFiles(type: FileType.any);
  static Future<Uint8List> _readBytes(File file) => file.readAsBytes();
  static Future<Uint8List> _readHead(File file) async {
    final length = await file.length();
    if (length <= 0) return Uint8List(0);
    final raf = await file.open(mode: FileMode.read);
    try {
      return await raf.read(length > 64 ? 64 : length);
    } finally {
      await raf.close();
    }
  }
}
