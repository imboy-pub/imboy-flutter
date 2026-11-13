import 'dart:async';
import 'dart:convert';

import '../../lib/modules/messaging/application/history_bundle/history_bundle_types.dart';

/// W3-K P2 history evidence; the caller supplies the existing FlowApiClient.get.
/// No login, upload, UI, decryption or real HTTP dependency in host regressions.
class ChatMultiBundleHistory {
  ChatMultiBundleHistory({
    required this.fetchPage,
    required this.senderUid,
    required this.recipientUid,
  });

  final Future<Map<String, dynamic>> Function(Map<String, dynamic> query)
  fetchPage;
  final String senderUid;
  final String recipientUid;
  int? _baseline;
  String? _convKey;
  int _cursor = 0;
  bool _blocked = false;

  int get baselineSeq =>
      _baseline ?? (throw StateError('history baseline not captured'));

  /// Capture before sending. safe_head is the archive's safe boundary, NOT
  /// the first page's tail; an old pending gap may keep it below visible rows.
  Future<void> captureBaseline() async {
    if (_baseline != null ||
        senderUid.isEmpty ||
        recipientUid.isEmpty ||
        senderUid == recipientUid) {
      throw StateError('invalid history baseline setup');
    }
    final page = await _readPage(0, limit: 1);
    _convKey = page['conv_key'] as String;
    _baseline = _seq(page['safe_head']);
    _cursor = baselineSeq;
  }

  Future<Map<String, dynamic>> waitForBundle({
    required String messageId,
    Duration timeout = const Duration(seconds: 45),
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    final baseline = baselineSeq;
    if (messageId.isEmpty ||
        timeout <= Duration.zero ||
        pollInterval <= Duration.zero) {
      throw ArgumentError('invalid bundle history polling arguments');
    }
    final clock = Stopwatch()..start();
    TimeoutException notObserved() => TimeoutException(
      'bundle history not observed: msg_id=$messageId baseline=$baseline '
      'cursor=$_cursor blocked=$_blocked',
      timeout,
    );
    while (clock.elapsed < timeout) {
      final page = await _readPage(
        _cursor,
      ).timeout(timeout - clock.elapsed, onTimeout: () => throw notObserved());
      _blocked = page['blocked'] as bool;
      // Inspect the exact ID before advancing: a visible row may be above
      // safe_head, even while next_seq is held back by a different pending row.
      for (final raw in page['messages'] as List) {
        if (raw is! Map) throw StateError('invalid history message');
        final row = Map<String, dynamic>.from(raw);
        if (row['msg_id'] != messageId) continue;
        if (_seq(row['conv_seq']) <= baseline ||
            '${row['chat_type']}'.toLowerCase() != 'c2c' ||
            '${row['from']}' != senderUid ||
            '${row['to']}' != recipientUid ||
            row['msg_type'] != HistoryBundleContract.msgType) {
          throw StateError('bundle history identity/boundary mismatch');
        }
        return row;
      }
      final next = _seq(page['next_seq']);
      final advanced = next > _cursor;
      _cursor = next; // Never advance with max(row.conv_seq) or a timestamp.
      if (page['has_more'] == true && advanced) continue;
      final remaining = timeout - clock.elapsed;
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < pollInterval ? remaining : pollInterval,
      );
    }
    throw notObserved();
  }

  Future<Map<String, dynamic>> _readPage(int after, {int limit = 50}) async {
    final Map<String, dynamic> response;
    try {
      response = await fetchPage({
        'chat_type': 'c2c',
        'peer_id': senderUid,
        'after_seq': '$after',
        'limit': '$limit',
      });
    } on Exception catch (error) {
      // Transport errors may contain response bodies/tokens; do not echo them.
      throw StateError('history request failed (${error.runtimeType})');
    }
    if (response['code'] != 0 || response['payload'] is! Map) {
      throw StateError('history request/response contract failed');
    }
    final page = Map<String, dynamic>.from(response['payload'] as Map);
    final key = page['conv_key'];
    if (key is! String ||
        key.isEmpty ||
        (_convKey != null && key != _convKey) ||
        page['messages'] is! List ||
        page['has_more'] is! bool ||
        page['blocked'] is! bool) {
      throw StateError('invalid history page or changed conversation');
    }
    final safeHead = _seq(page['safe_head']);
    final next = _seq(page['next_seq']);
    if (next < after ||
        (next > after && next > safeHead) ||
        (page['has_more'] == true &&
            next == after &&
            page['blocked'] == false)) {
      throw StateError('invalid/non-progressing history cursor');
    }
    return page;
  }
}

int _seq(Object? value) {
  final parsed = value is int
      ? value
      : value is String
      ? int.tryParse(value)
      : null;
  if (parsed == null || parsed < 0) {
    throw StateError('missing/invalid history sequence');
  }
  return parsed;
}

Map<String, dynamic> _jsonObject(Object? value) {
  try {
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    // Do not surface FormatException.source: it may contain message content.
  }
  throw StateError('invalid bundle history JSON object');
}

/// Returns plaintext only for a plaintext row; null means an opaque E2EE row.
/// Parse outer JSON metadata only. Never decode/decrypt a ciphertext or header.
Map<String, dynamic>? bundleHistoryPlaintext(
  Map<String, dynamic> row, {
  required List<String> markers,
  bool? expectEncrypted,
}) {
  final rawEnvelope = row['e2ee'];
  final envelope = rawEnvelope == null || rawEnvelope == ''
      ? <String, dynamic>{}
      : _jsonObject(rawEnvelope);
  final encrypted = envelope.isNotEmpty;
  if (expectEncrypted != null && encrypted != expectEncrypted) {
    throw StateError('bundle history encryption mode mismatch');
  }
  if (!encrypted) return _jsonObject(row['payload']);

  final payload = row['payload'];
  if (envelope['meta_version'] == 3) {
    final devices = envelope['devices'];
    final carriers = devices is Map ? devices.values : [envelope];
    if (payload != '' ||
        carriers.isEmpty ||
        !carriers.every(
          (e) =>
              e is Map &&
              e['ciphertext'] is String &&
              (e['ciphertext'] as String).isNotEmpty,
        )) {
      throw StateError('invalid PFv3 ciphertext carrier');
    }
  } else if (envelope['e2ee'] != true ||
      payload is! String ||
      payload.isEmpty) {
    throw StateError('invalid legacy E2EE ciphertext carrier');
  }
  // Check both locations (legacy payload / PFv3 devices). Only booleans/errors
  // escape this helper, never the serialized ciphertext or envelope.
  final wire = jsonEncode({'payload': payload, 'e2ee': envelope});
  if (wire.contains('bundle_version') ||
      markers.any((marker) => marker.isNotEmpty && wire.contains(marker))) {
    throw StateError('plaintext leaked into encrypted bundle history');
  }
  return null;
}
