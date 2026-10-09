import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class NegativePhase {
  NegativePhase(this.mode) {
    if (mode != 'live' && mode != 'reconnect') {
      throw StateError('explicit negative mode required');
    }
    _endpoint = Uri.parse(const String.fromEnvironment('MC_OWNED_PHASE_URL'));
    final session = Uri.parse(
      const String.fromEnvironment('MC_OWNED_SESSION_URL'),
    );
    if (_endpoint.scheme != 'http' ||
        _endpoint.host != '127.0.0.1' ||
        _endpoint.port != session.port ||
        _endpoint.userInfo.isNotEmpty ||
        _endpoint.path != '/mc-owned/android/phase' ||
        _endpoint.hasQuery ||
        _endpoint.hasFragment ||
        _key.length < 32) {
      throw StateError('explicit independent owned phase endpoint required');
    }
  }

  final String mode;
  late final Uri _endpoint;
  static const _key = String.fromEnvironment('MC_OWNED_PHASE_KEY');
  int _sequence = -1;
  String get beforeId => 'mc22-$mode-before';
  String get afterId => 'mc22-$mode-after';
  String get offlineId => 'mc22-$mode-offline';
  String get rejectedMarker => 'mc22-$mode-reject';

  Future<Map<String, dynamic>> _request(
    String? action, [
    String? actualId,
  ]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.openUrl(
        action == null ? 'GET' : 'POST',
        _endpoint,
      );
      request.followRedirects = false;
      request.headers.set('x-mc-owned-phase', _key);
      if (action != null) {
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({'action': action, 'actual_msg_id': ?actualId}),
        );
      }
      final response = await request.close().timeout(
        const Duration(seconds: 100),
      );
      if (response.statusCode != 200) {
        throw StateError('phase request rejected');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(
        const Duration(seconds: 100),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) throw StateError('phase response oversized');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map ||
          decoded['code'] != 0 ||
          decoded['payload'] is! Map) {
        throw StateError('invalid phase envelope');
      }
      return _validate(Map<String, dynamic>.from(decoded['payload'] as Map));
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _validate(Map<String, dynamic> payload) {
    final sequence = payload['sequence'];
    final remaining = payload['deadline_remaining_ms'];
    if (payload['mode'] != mode ||
        sequence is! int ||
        sequence < _sequence ||
        remaining is! int ||
        remaining <= 0 ||
        payload['stage'] is! String ||
        payload['before_id'] != beforeId ||
        payload['after_id'] != afterId ||
        payload['offline_id'] != offlineId ||
        (payload['rejected_marker'] ?? payload['rejected_id']) !=
            rejectedMarker) {
      throw StateError('phase identity, sequence or lease mismatch');
    }
    _sequence = sequence;
    return payload;
  }

  Future<void> wait(WidgetTester tester, String stage) async {
    for (var attempt = 0; attempt < 1100; attempt++) {
      final current = await _request(null);
      if (current['stage'] == stage) return;
      await negativePump(tester);
    }
    throw StateError('owned phase deadline exceeded');
  }

  Future<void> ack(String action, {String? actualId}) async {
    const allowed = {
      'joined',
      'warm',
      'before_received',
      'disconnected',
      'queue_ready',
      'reconnected',
      'chat_denied',
      'old_intent_denied',
      'cache_denied',
      'offline_denied',
      'queued_denied',
    };
    if (!allowed.contains(action)) throw StateError('unknown app phase ack');
    if (actualId != null &&
        (!{'chat_denied', 'queued_denied'}.contains(action) ||
            !RegExp(r'^[A-Za-z0-9_-]{1,50}$').hasMatch(actualId))) {
      throw StateError('actual UI message id is outside fixed ack contract');
    }
    await _request(action, actualId);
  }
}

Future<void> negativePump(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 250));
  await Future<void>.delayed(const Duration(milliseconds: 250));
}
