// Synthetic, in-memory governance fixtures; no real backend traffic.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:imboy/modules/customer_service/presentation/cs_governance_page.dart';

import '../ux_matrix/ux_harness.dart';

const String orgA = '7266418340025468901';
const String orgB = '7266418340025468999';
const String identityA = '7266418340025468902';
const String identityB = '7266418340025468912';

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

Map<String, dynamic> errEnvelope(int status, String tag) => {
  'code': status,
  'msg': tag,
  'payload': <String, dynamic>{},
};

Map<String, dynamic> limitPayload(
  String org, {
  dynamic seatLimit = 5,
  int used = 3,
}) => okEnvelope(
  payload: {'organization_id': org, 'seat_limit': seatLimit, 'used': used},
);

Map<String, dynamic> seatsPayload({
  List<Map<String, dynamic>>? seats,
  dynamic nextAfterId,
}) => okEnvelope(
  payload: {
    'seats': seats ?? <Map<String, dynamic>>[],
    'next_after_id': nextAfterId,
  },
);

Map<String, dynamic> seatRow(
  String org,
  String identity, {
  bool enabled = true,
}) => {
  'organization_id': org,
  'business_identity_id': identity,
  'function_key': 'customer_service',
  'enabled': enabled,
  'max_concurrent': 3,
  'active_count': 1,
};

/// 按 `METHOD fragment` 复合键路由的桩（contains 匹配 path）；响应按序
/// 消耗、耗尽停留最后一个。记录命中序列供路径断言。
class GovRouterAdapter implements HttpClientAdapter {
  GovRouterAdapter(this.routes, {this.beforeResponse});

  final Map<String, List<(int, Map<String, dynamic>)>> routes;
  final Future<void> Function(String key)? beforeResponse;
  final List<String> hits = [];
  final Map<String, List<Object?>> bodies = {};
  final Map<String, List<Map<String, dynamic>>> queries = {};
  final Map<String, int> _cursor = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final key in routes.keys) {
      final method = key.substring(0, key.indexOf(' '));
      final fragment = key.substring(key.indexOf(' ') + 1);
      if (options.method == method && options.uri.path.contains(fragment)) {
        hits.add(key);
        queries.putIfAbsent(key, () => []).add(Map.of(options.queryParameters));
        await beforeResponse?.call(key);
        bodies.putIfAbsent(key, () => []).add(options.data);
        final queue = routes[key]!;
        // 按序消费、耗尽停留最后一个（首次 index 0，之后逐帧前进）。
        final i = _cursor.putIfAbsent(key, () => 0);
        _cursor[key] = (i + 1).clamp(0, queue.length - 1);
        final (status, body) = queue[i];
        return ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode(okEnvelope(payload: <String, dynamic>{})),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget governanceHost(String orgId) =>
    uxHost(CsGovernancePage(orgId: orgId), const UxCombo(kUxMediumViewport));
