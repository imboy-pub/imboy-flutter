/// Local upload receipts contain no audio keys and never authorize access.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'talk_record_local_binding.dart';

class TalkRecordUploadCheckpoint {
  TalkRecordUploadCheckpoint({
    required this.identity,
    required this.sourceHash,
    Map<String, dynamic>? parts,
    Map<String, dynamic>? events,
    List<String>? marks,
    this.completeKey = '',
    this.completeEtag = '',
    this.completeHash = '',
    this.completeConsentFingerprint = '',
    this.submitted = false,
  }) : parts = parts ?? {},
       events = events ?? {},
       marks = marks ?? [];
  final String identity, sourceHash;
  final Map<String, dynamic> parts, events;
  final List<String> marks;
  String completeKey, completeEtag, completeHash, completeConsentFingerprint;
  bool submitted;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'identity': identity,
    'source_hash': sourceHash,
    'parts': parts,
    'events': events,
    'marks': marks,
    'complete_key': completeKey,
    'complete_etag': completeEtag,
    'complete_hash': completeHash,
    'complete_consent_fingerprint': completeConsentFingerprint,
    'submitted': submitted,
  };
}

class TalkRecordUploadCheckpointStore {
  TalkRecordUploadCheckpointStore(this.directory);
  final Directory directory;
  File get file => File('${directory.path}/upload-checkpoint.json');
  static String identity(TalkRecordLocalBinding b) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            b.account.storageKey,
            b.clientRecordingId,
            b.sessionId,
            b.context.toQuery(),
            b.recordId,
            b.captureId,
            b.deviceSessionId,
          ]),
        ),
      )
      .toString();
  Future<TalkRecordUploadCheckpoint> load(
    TalkRecordLocalBinding binding,
    String hash,
  ) async {
    final expected = identity(binding);
    if (!await file.exists()) {
      return TalkRecordUploadCheckpoint(identity: expected, sourceHash: hash);
    }
    final json = Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    if (json['version'] != 1 ||
        json['identity'] != expected ||
        json['source_hash'] != hash) {
      throw StateError('Upload checkpoint ownership or source changed');
    }
    return TalkRecordUploadCheckpoint(
      identity: expected,
      sourceHash: hash,
      parts: Map<String, dynamic>.from(json['parts'] as Map),
      events: Map<String, dynamic>.from(json['events'] as Map),
      marks: List<String>.from(json['marks'] as List),
      completeKey: json['complete_key'] as String,
      completeEtag: json['complete_etag'] as String,
      completeHash: json['complete_hash'] as String,
      completeConsentFingerprint:
          json['complete_consent_fingerprint'] as String? ?? '',
      submitted: json['submitted'] as bool,
    );
  }

  Future<void> save(TalkRecordUploadCheckpoint checkpoint) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(checkpoint.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}
