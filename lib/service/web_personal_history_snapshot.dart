part of 'web_personal_history_sync.dart';

const _restoredConvSeq = '_personal_history_verified_conv_seq';
const _maxSnapshotRequests = 6;
const _snapshotPageSize = 50;

typedef _SnapshotPosition = ({int before, String? token});
typedef _SnapshotResult = ({
  List<String> texts,
  bool partial,
  _SnapshotPosition? position,
});
typedef _HistoryCopyEnvelope = ({
  String conversationId,
  String msgId,
  int actionVersion,
  int convSeq,
  int keyVersion,
  String ciphertext,
  Map<String, dynamic> envelopeMeta,
  PersonalHistoryAcceptedMessage? acceptedMessage,
});

Future<_SnapshotResult> _readRestoredText({
  required PersonalHistoryLocalStore store,
  required PersonalHistoryApiClient client,
  required PersonalHistoryStatus status,
  required String conversationId,
  required _SnapshotPosition? start,
  required void Function() requireCurrent,
  required Future<void> Function() confirmDurable,
  required Future<Map<String, dynamic>?> Function(_HistoryCopyEnvelope)
  decryptCopy,
}) async {
  final texts = <String, String>{};
  var token = start?.token;
  var durableBefore = start?.before;
  var before = start?.before ?? 0;
  var pageUpperBound = before;
  var usedFallback = false;
  var partial = false;
  for (var attempt = 0; attempt < _maxSnapshotRequests; attempt++) {
    requireCurrent();
    Map<String, dynamic> page;
    try {
      page = await client.page(
        conversationId: conversationId,
        before: token == null ? before : 0,
        pageToken: token,
      );
    } on PersonalHistoryApiException catch (error) {
      requireCurrent();
      final canRestart =
          error.httpStatus == 410 &&
          (error.code == PersonalHistoryErrorCode.pageTokenExpired ||
              error.code == PersonalHistoryErrorCode.rescanBoundExceeded);
      if (token == null || !canRestart) rethrow;
      final anchor = durableBefore;
      if (usedFallback || anchor == null) break;
      usedFallback = true;
      token = null;
      before = anchor;
      pageUpperBound = anchor;
      continue;
    }
    requireCurrent();
    final snapshot = _parseSnapshotPage(
      page,
      expectedGeneration: status.generation,
      conversationId: conversationId,
      exclusiveBefore: pageUpperBound,
      requestedToken: token,
    );
    pageUpperBound = snapshot.upperBound;
    partial = partial || snapshot.partial;
    snapshot.hidden.forEach(texts.remove);
    final local = await _readSnapshotTexts(
      store: store,
      domain: status.domain!,
      generation: status.generation,
      conversationId: conversationId,
      accepted: snapshot.accepted,
      requireCurrent: requireCurrent,
      confirmDurable: confirmDurable,
      decryptCopy: decryptCopy,
    );
    partial = partial || local.length != snapshot.accepted.length;
    for (final id in snapshot.accepted.keys) {
      final row = local[id];
      if (row == null) {
        texts.remove(id);
        continue;
      }
      texts[id] = row.text;
      if (durableBefore == null || row.convSeq < durableBefore) {
        durableBefore = row.convSeq;
      }
    }
    if (snapshot.nextToken == null) {
      return (
        texts: texts.values.toList(),
        partial: partial || texts.isEmpty,
        position: null,
      );
    }
    token = snapshot.nextToken;
  }
  final anchor = durableBefore;
  final position = anchor != null && (start == null || anchor < start.before)
      ? (before: anchor, token: pageUpperBound == anchor ? token : null)
      : start;
  return (texts: texts.values.toList(), partial: true, position: position);
}

typedef _SnapshotStamp = ({
  String msgId,
  int actionVersion,
  String previous,
  String stamped,
});
typedef _SnapshotText = ({String text, int convSeq, _SnapshotStamp? stamp});

Future<Map<String, _SnapshotText>> _readSnapshotTexts({
  required PersonalHistoryLocalStore store,
  required String domain,
  required int generation,
  required String conversationId,
  required Map<String, _HistoryCopyEnvelope> accepted,
  required void Function() requireCurrent,
  required Future<void> Function() confirmDurable,
  required Future<Map<String, dynamic>?> Function(_HistoryCopyEnvelope)
  decryptCopy,
}) async {
  final rows = await store.readRestoredRowsForPage(
    domain: domain,
    generation: generation,
    conversationId: conversationId,
    messageIds: accepted.keys.toList(),
  );
  requireCurrent();
  final local = {for (final row in rows) row['msg_id']: row};
  final texts = <String, _SnapshotText>{};
  final stamps = <_SnapshotStamp>[];
  for (final item in accepted.entries) {
    final row = await _verifySnapshotText(
      item.value,
      local[item.key],
      decryptCopy,
    );
    requireCurrent();
    if (row == null) continue;
    texts[item.key] = row;
    if (row.stamp case final stamp?) stamps.add(stamp);
  }
  if (stamps.isEmpty) return texts;
  final stamped = await store.stampRestoredRowsForPage(
    domain: domain,
    generation: generation,
    conversationId: conversationId,
    stamps: stamps,
    requireCurrent: requireCurrent,
  );
  if (stamped.isNotEmpty) await confirmDurable();
  requireCurrent();
  texts.removeWhere((id, row) => row.stamp != null && !stamped.contains(id));
  return texts;
}

Future<_SnapshotText?> _verifySnapshotText(
  _HistoryCopyEnvelope copy,
  Map<String, Object?>? row,
  Future<Map<String, dynamic>?> Function(_HistoryCopyEnvelope) decryptCopy,
) async {
  final raw = row?['row'];
  if (raw is! String || row?['action_version'] != copy.actionVersion) {
    return null;
  }
  final body = jsonDecode(raw);
  final proof = copy.acceptedMessage!;
  final payload = body is Map<String, dynamic> ? body['payload'] : null;
  final text = payload is Map ? payload['text'] : null;
  if (body is! Map<String, dynamic> ||
      body['chat_type'] != 'c2c' ||
      body['msg_id'] != copy.msgId ||
      body['msg_type'] != 'text' ||
      body['from'] != proof.fromId ||
      body['to'] != proof.toId ||
      text is! String) {
    return null;
  }
  if (body.containsKey(_restoredConvSeq)) {
    return body[_restoredConvSeq] == copy.convSeq
        ? (text: text, convSeq: copy.convSeq, stamp: null)
        : null;
  }
  final verified = await decryptCopy(copy);
  if (verified == null ||
      jsonEncode({...verified}..remove(_restoredConvSeq)) != jsonEncode(body)) {
    return null;
  }
  return (
    text: text,
    convSeq: copy.convSeq,
    stamp: (
      msgId: copy.msgId,
      actionVersion: copy.actionVersion,
      previous: raw,
      stamped: jsonEncode(verified),
    ),
  );
}

typedef _SnapshotPage = ({
  Map<String, _HistoryCopyEnvelope> accepted,
  Set<String> hidden,
  bool partial,
  int upperBound,
  String? nextToken,
});

_SnapshotPage _parseSnapshotPage(
  Map<String, dynamic> page, {
  required int expectedGeneration,
  required String conversationId,
  required int exclusiveBefore,
  required String? requestedToken,
}) {
  final generation = page['generation'];
  if (generation is int && generation != expectedGeneration) {
    throw const PersonalHistoryApiException(
      PersonalHistoryErrorCode.generationExpired,
      0,
    );
  }
  final messages = page['messages'];
  final hasMore = page['has_more'];
  final nextToken = page['page_token'];
  if (generation != expectedGeneration ||
      page['conversation_id'] != conversationId ||
      messages is! List ||
      messages.length > _snapshotPageSize ||
      hasMore is! bool ||
      (hasMore &&
          (messages.isEmpty ||
              nextToken is! String ||
              nextToken.isEmpty ||
              nextToken == requestedToken))) {
    throw const FormatException('Invalid personal history snapshot');
  }
  final accepted = <String, _HistoryCopyEnvelope>{};
  final hidden = <String>{};
  var partial = false;
  var pageUpperBound = exclusiveBefore;
  for (final value in messages) {
    if (value is! Map) {
      throw const FormatException('Invalid personal history snapshot row');
    }
    final id = value['msg_id'];
    final sequence = value['conv_seq'];
    if (id is! String ||
        id.isEmpty ||
        sequence is! int ||
        !_validSequence(sequence) ||
        (pageUpperBound > 0 && sequence >= pageUpperBound)) {
      throw const FormatException('Invalid personal history page order');
    }
    pageUpperBound = sequence;
    if (value['deleted'] == true) {
      hidden.add(id);
      continue;
    }
    final proof = parsePersonalHistoryAcceptedMessage(
      value['accepted_message'],
    );
    final keyVersion = value['key_version'];
    final ciphertext = value['ciphertext'];
    final metadata = value['envelope_meta'];
    if (value['deleted'] != false ||
        proof == null ||
        sequence != proof.sequence ||
        value['action_version'] != proof.actionVersion ||
        _c2cHistoryKey(proof.fromId, proof.toId) != conversationId ||
        keyVersion is! int ||
        keyVersion <= 0 ||
        ciphertext is! String ||
        ciphertext.isEmpty ||
        metadata is! Map<String, dynamic>) {
      hidden.add(id);
      partial = true;
      continue;
    }
    accepted[id] = (
      conversationId: conversationId,
      msgId: id,
      actionVersion: proof.actionVersion,
      convSeq: sequence,
      keyVersion: keyVersion,
      ciphertext: ciphertext,
      envelopeMeta: metadata,
      acceptedMessage: proof,
    );
  }
  return (
    accepted: accepted,
    hidden: hidden,
    partial: partial,
    upperBound: pageUpperBound,
    nextToken: hasMore ? nextToken as String : null,
  );
}
