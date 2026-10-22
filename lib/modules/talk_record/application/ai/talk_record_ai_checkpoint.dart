import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/e2ee/attachment_chunk_codec.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

class TalkRecordAiCheckpointStore {
  TalkRecordAiCheckpointStore(this.directory, this.keys, this.identity);
  final Directory directory;
  final TalkRecordKeyStore keys;
  final String identity;
  String get keyId => 'talk-ai-${sha256.convert(utf8.encode(identity))}';
  File get file => File('${directory.path}/$keyId.enc');
  static const maxBytes = 16 * 1024 * 1024;

  Future<Uint8List> _key({required bool create}) async {
    final stored = await keys.readRecordKey(keyId);
    if (stored != null && stored.length == 32) {
      return Uint8List.fromList(stored);
    }
    if (!create || stored != null) {
      throw StateError('AI checkpoint key unavailable');
    }
    final generated = TalkRecordSegmentCrypto.generateRecordKey();
    await keys.writeRecordKey(keyId, generated);
    return generated;
  }

  Future<Map<String, dynamic>?> load() async {
    if (!await file.exists()) return null;
    final size = await file.length();
    if (size < 28 || size > maxBytes + 28) {
      throw const FormatException('AI checkpoint size');
    }
    final key = await _key(create: false);
    try {
      final bytes = await file.readAsBytes();
      final plain = AttachmentChunkCodec.decryptChunk(
        sealed: Uint8List.sublistView(bytes, 12),
        contentKey: key,
        baseNonce: Uint8List.sublistView(bytes, 0, 12),
        bindingHash: TalkRecordSegmentCrypto.bindingHashFor(identity),
        attachmentId: keyId,
        chunkIndex: 0,
        chunkCount: 1,
      );
      try {
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map);
      } finally {
        plain.fillRange(0, plain.length, 0);
      }
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<void> save(Map<String, dynamic> value) async {
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    if (plain.length > maxBytes) {
      throw const FormatException('AI checkpoint size');
    }
    final key = await _key(create: !await file.exists());
    final nonce = Uint8List.fromList(
      List.generate(12, (_) => Random.secure().nextInt(256)),
    );
    try {
      final sealed = AttachmentChunkCodec.encryptChunk(
        plaintext: plain,
        contentKey: key,
        baseNonce: nonce,
        bindingHash: TalkRecordSegmentCrypto.bindingHashFor(identity),
        attachmentId: keyId,
        chunkIndex: 0,
        chunkCount: 1,
      );
      await directory.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes([...nonce, ...sealed], flush: true);
      await temporary.rename(file.path);
    } finally {
      plain.fillRange(0, plain.length, 0);
      key.fillRange(0, key.length, 0);
    }
  }
}
