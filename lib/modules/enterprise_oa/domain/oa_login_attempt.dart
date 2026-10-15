import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The verifier stays on this device; external callbacks supply only ticket/state.
class OaLoginAttempt {
  OaLoginAttempt({
    required this.state,
    required this.verifier,
    required this.intent,
    required this.createdAt,
    this.backend = "",
    this.deviceId = "",
    this.applicationKey = "",
    this.pendingToken,
    this.expiresAt,
  });
  final String backend;
  final String deviceId;
  final String applicationKey;
  final String state;
  final String verifier;
  final String intent;
  final DateTime createdAt;
  String? pendingToken;
  DateTime? expiresAt;
  factory OaLoginAttempt.create(
    String intent, {
    String backend = "",
    String deviceId = "",
    String applicationKey = "",
  }) {
    if (!['login', 'link'].contains(intent)) throw ArgumentError('intent');
    final random = Random.secure();
    String nonce() =>
        base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
            .replaceAll('=', '');
    return OaLoginAttempt(
      backend: backend,
      deviceId: deviceId,
      applicationKey: applicationKey,
      state: nonce(),
      verifier: nonce(),
      intent: intent,
      createdAt: DateTime.now(),
    );
  }
  void requireContext(String currentBackend, String currentDevice) {
    if (backend.isEmpty ||
        deviceId.isEmpty ||
        backend != currentBackend ||
        deviceId != currentDevice) {
      throw const FormatException('OA context changed');
    }
  }

  String get challenge =>
      base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
  bool validAt(DateTime now) =>
      !now.isBefore(createdAt) &&
      (expiresAt == null || now.isBefore(expiresAt!)) &&
      now.difference(createdAt) < const Duration(minutes: 10);
  String callbackTicket(Uri uri, DateTime now) {
    final query = uri.queryParametersAll;
    final ticket = query['ticket'];
    if (!validAt(now) ||
        uri.path != '/oa/login' ||
        uri.hasFragment ||
        (uri.hasScheme && uri.scheme != 'imboy') ||
        (uri.hasAuthority && uri.host != 'imboy.pub') ||
        query['state']?.length != 1 ||
        query['state']!.single != state ||
        ticket?.length != 1 ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(ticket!.single) ||
        query.containsKey('code_verifier')) {
      throw const FormatException('Invalid OA callback');
    }
    return ticket.single;
  }

  Uri launchUri(Uri start) => start.replace(
    queryParameters: {
      ...start.queryParameters,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'intent': intent,
      'redirect_uri': 'imboy://imboy.pub/oa/login',
    },
  );
  Map<String, dynamic> toJson() => {
    'backend': backend,
    'did': deviceId,
    'application_key': applicationKey,
    'state': state,
    'verifier': verifier,
    'intent': intent,
    'created_at': createdAt.toUtc().toIso8601String(),
    'pending_token': pendingToken,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
  };
  factory OaLoginAttempt.fromJson(Map<String, dynamic> json) => OaLoginAttempt(
    backend: json['backend'] as String,
    deviceId: json['did'] as String,
    applicationKey: json['application_key'] as String,
    state: json['state'] as String,
    verifier: json['verifier'] as String,
    intent: json['intent'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    pendingToken: json['pending_token'] as String?,
    expiresAt: json['expires_at'] == null
        ? null
        : DateTime.parse(json['expires_at'] as String),
  );
}
