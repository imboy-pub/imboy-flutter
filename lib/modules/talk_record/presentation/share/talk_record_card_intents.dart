/// One user-confirmed share intent may retry pending delivery, never a prior send.
library;

import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';

import 'talk_record_share_service.dart';

class TalkRecordCardIntents {
  TalkRecordCardIntents({String Function()? nextId})
    : _nextId = nextId ?? TalkRecordIds.newUuidV4;
  final String Function() _nextId;
  final _retryable = <String, String>{};

  String begin(String ownerKey, String recordId) =>
      _retryable.putIfAbsent('$ownerKey:$recordId', _nextId);

  bool finish(
    String ownerKey,
    String recordId,
    String intent,
    TalkRecordCardSendResult result,
  ) {
    if (!{
      TalkRecordCardSendResult.sent,
      TalkRecordCardSendResult.cancelled,
      TalkRecordCardSendResult.stale,
    }.contains(result)) {
      return false;
    }
    final key = '$ownerKey:$recordId';
    if (_retryable[key] != intent) return false;
    _retryable.remove(key);
    return true;
  }
}
