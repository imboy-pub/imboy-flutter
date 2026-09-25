/// CS-APP-03 — 企业自助客服治理 API 客户端契约单测（mock adapter）。
///
/// 契约依据（后端 imboy_router.erl 2139-2146 / cs_actions.erl 448-462 /
/// cs_http.erl 已核对，候选 67e18677 集成面）：
/// - `GET/PUT /api/v1/cs/organizations/:org_id/seat-limit`（CS-BE-06，
///   enterprise_owner_admin 治理权限；PUT body `{"seat_limit": n}`，缺省
///   = 清除 → unlimited）；
/// - `GET /api/v1/cs/organizations/:org_id/seats?after_id=&limit=`（键集
///   分页，行投影 organization_id/business_identity_id/function_key/
///   enabled/max_concurrent/active_count）；
/// - `POST .../seats/:id/suspend|resume`（enabled 治理）。
///
/// 红线（token 纪律）：全部请求**不得**命中 `/api/adm`（平台 Admin 面），
/// 也不得命中 Seat JWT 专属端点（heartbeat/presence）——compile-time +
/// runtime 双重钉住。
///
/// 错误 envelope（elib_response）：`{code, msg, payload}`（code = HTTP
/// 状态、msg = 服务端 tag）——分型按 msg tag（governance_insufficient /
/// seat_limit_exceeded / invalid_seat_limit）。
///
/// TSID lossless：后端 encode_entity 把 `*_id` 出站编码为十进制字符串
/// （19 位超 double 精度），模型全链 String 保真；int 形态兼容入参。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_governance_api.dart';
import 'package:imboy/service/storage.dart';

/// 19 位 TSID（> 2^53，double 精度边界外）——string 形态必须逐字保真。
const String orgId = '7266418340025468901';
const String identityA = '7266418340025468902';
const String identityB = '7266418340025468912';
const String cursor = '7266418340025468930';

/// 记录请求并恒返指定 statusCode + JSON envelope 的出口。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  /// 每次请求的 (method, path, data, queryParameters, uri)。
  final List<(String, String, Object?, Map<String, dynamic>, String)> requests =
      [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      options.method,
      options.uri.path,
      options.data,
      Map<String, dynamic>.from(options.queryParameters),
      options.uri.toString(),
    ));
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

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

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  _RecordingAdapter useAdapter(int statusCode, Map<String, dynamic> body) {
    final adapter = _RecordingAdapter(statusCode, body);
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    return adapter;
  }

  /// token 纪律：全部出站请求不触碰平台 Admin 面 / Seat JWT 专属端点。
  void expectTokenDiscipline(_RecordingAdapter adapter) {
    for (final (_, _, _, _, uri) in adapter.requests) {
      expect(
        uri,
        isNot(contains('/api/adm')),
        reason: '治理客户端禁止请求平台 Admin Cookie 面',
      );
      expect(
        uri,
        isNot(contains('heartbeat')),
        reason: '治理客户端不消费 Seat JWT 专属端点',
      );
      expect(uri, isNot(contains('presence')));
    }
  }

  group('seat-limit 视图与调整（CS-BE-06）', () {
    test('seatLimitView：GET 路径精确、无 query；解析 n|unlimited + used', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {'organization_id': orgId, 'seat_limit': 5, 'used': 3},
        ),
      );
      final api = CsGovernanceApi();
      final view = await api.seatLimitView(orgId);

      final (method, path, data, query, _) = adapter.requests.single;
      expect(method, 'GET');
      expect(path, '/api/v1/cs/organizations/$orgId/seat-limit');
      expect(data, isNull);
      expect(query, isEmpty);
      expectTokenDiscipline(adapter);

      expect(view.organizationId, orgId, reason: 'TSID string 逐字保真');
      expect(view.isUnlimited, false);
      expect(view.limitValue, 5);
      expect(view.used, 3);
      expect(view.isAtCapacity, false);
    });

    test(
      'seatLimitView：seat_limit="unlimited" → isUnlimited 且 isAtCapacity=false',
      () async {
        useAdapter(
          200,
          okEnvelope(
            payload: {
              'organization_id': orgId,
              'seat_limit': 'unlimited',
              'used': 12,
            },
          ),
        );
        final view = await CsGovernanceApi().seatLimitView(orgId);
        expect(view.isUnlimited, true);
        expect(view.limitValue, isNull);
        expect(view.used, 12);
        expect(view.isAtCapacity, false, reason: '无限额度无上限语义');
      },
    );

    test('setSeatLimit(n)：PUT body 携带 seat_limit；回显新视图（额度变化）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {'organization_id': orgId, 'seat_limit': 2, 'used': 2},
        ),
      );
      final view = await CsGovernanceApi().setSeatLimit(orgId, 2);

      final (method, path, data, query, _) = adapter.requests.single;
      expect(method, 'PUT');
      expect(path, '/api/v1/cs/organizations/$orgId/seat-limit');
      expect(query, isEmpty);
      expect(data, <String, dynamic>{'seat_limit': 2});
      expectTokenDiscipline(adapter);

      expect(view.limitValue, 2);
      expect(view.used, 2);
      expect(view.isAtCapacity, true, reason: 'used == limit 达上限');
    });

    test('setSeatLimit(null)：body 缺省键 = 清除 → unlimited 契约', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'organization_id': orgId,
            'seat_limit': 'unlimited',
            'used': 2,
          },
        ),
      );
      await CsGovernanceApi().setSeatLimit(orgId, null);

      final (_, _, data, _, _) = adapter.requests.single;
      expect(data, <String, dynamic>{}, reason: 'null = 缺省键（清除 → unlimited）');
    });

    test('403 governance_insufficient：isForbidden 诚实分型（member 负例）', () async {
      final adapter = useAdapter(
        403,
        errEnvelope(403, 'governance_insufficient'),
      );
      try {
        await CsGovernanceApi().seatLimitView(orgId);
        fail('应抛 CsGovernanceApiException');
      } on CsGovernanceApiException catch (e) {
        expect(e.isForbidden, true);
        expect(e.message, 'governance_insufficient');
      }
      expectTokenDiscipline(adapter);
    });

    test('seat_limit_exceeded：tag 分型不依赖 HTTP 码（可解释冲突）', () async {
      // 后端 classify 未显式登记该 tag 时状态码可能漂移（500 而非 409）——
      // 客户端以 envelope tag 为准。
      final adapter = useAdapter(500, errEnvelope(500, 'seat_limit_exceeded'));
      try {
        await CsGovernanceApi().resumeSeat(orgId, identityA);
        fail('应抛 CsGovernanceApiException');
      } on CsGovernanceApiException catch (e) {
        expect(e.isSeatLimitExceeded, true, reason: 'tag 命中即超额冲突');
        expect(e.isConflict, false);
      }
      expectTokenDiscipline(adapter);
    });

    test('invalid_seat_limit：422 取值不成立分型', () async {
      useAdapter(422, errEnvelope(422, 'invalid_seat_limit'));
      try {
        await CsGovernanceApi().setSeatLimit(orgId, -1);
        fail('应抛 CsGovernanceApiException');
      } on CsGovernanceApiException catch (e) {
        expect(e.isInvalidSeatLimit, true);
      }
    });
  });

  group('seat 列表与启停治理', () {
    test('seatsPage：GET 路径 + after_id/limit query；行投影解析', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'seats': [
              {
                'organization_id': orgId,
                'business_identity_id': identityA,
                'function_key': 'customer_service',
                'enabled': true,
                'max_concurrent': 3,
                'active_count': 1,
              },
              {
                'organization_id': orgId,
                'business_identity_id': identityB,
                'function_key': 'customer_service',
                'enabled': false,
                'max_concurrent': 1,
                'active_count': 0,
              },
            ],
            'next_after_id': cursor,
          },
        ),
      );
      final page = await CsGovernanceApi().seatsPage(
        orgId,
        afterId: cursor,
        limit: 50,
      );

      final (method, path, _, query, _) = adapter.requests.single;
      expect(method, 'GET');
      expect(path, '/api/v1/cs/organizations/$orgId/seats');
      expect(query, <String, dynamic>{'after_id': cursor, 'limit': 50});
      expectTokenDiscipline(adapter);

      expect(page.rows, hasLength(2));
      expect(page.rows.first.businessIdentityId, identityA, reason: 'TSID 保真');
      expect(page.rows.first.enabled, true);
      expect(page.rows.first.maxConcurrent, 3);
      expect(page.rows.first.activeCount, 1);
      expect(page.rows.last.enabled, false);
      expect(page.nextAfterId, cursor);
      expect(page.hasMore, true);
    });

    test('seatsPage：next_after_id null → hasMore=false（分页终点）', () async {
      useAdapter(
        200,
        okEnvelope(
          payload: {'seats': <Map<String, dynamic>>[], 'next_after_id': null},
        ),
      );
      final page = await CsGovernanceApi().seatsPage(orgId);
      expect(page.rows, isEmpty);
      expect(page.hasMore, false);
    });

    test('suspendSeat：POST 路径 + reason body', () async {
      final adapter = useAdapter(200, okEnvelope(payload: <String, dynamic>{}));
      await CsGovernanceApi().suspendSeat(orgId, identityA, reason: '休假');

      final (method, path, data, _, _) = adapter.requests.single;
      expect(method, 'POST');
      expect(path, '/api/v1/cs/organizations/$orgId/seats/$identityA/suspend');
      expect(data, <String, dynamic>{'reason': '休假'});
      expectTokenDiscipline(adapter);
    });

    test('resumeSeat：POST 路径 + 空 body', () async {
      final adapter = useAdapter(200, okEnvelope(payload: <String, dynamic>{}));
      await CsGovernanceApi().resumeSeat(orgId, identityB);

      final (method, path, data, _, _) = adapter.requests.single;
      expect(method, 'POST');
      expect(path, '/api/v1/cs/organizations/$orgId/seats/$identityB/resume');
      expect(data, <String, dynamic>{});
      expectTokenDiscipline(adapter);
    });

    test('suspendSeat 403（cross_org）：isForbidden 负例', () async {
      useAdapter(403, errEnvelope(403, 'cross_org'));
      try {
        await CsGovernanceApi().suspendSeat(orgId, identityA);
        fail('应抛 CsGovernanceApiException');
      } on CsGovernanceApiException catch (e) {
        expect(e.isForbidden, true);
      }
    });

    test('seat_disabled 403：tag 透传（诚实展示面）', () async {
      useAdapter(403, errEnvelope(403, 'seat_disabled'));
      try {
        await CsGovernanceApi().resumeSeat(orgId, identityA);
        fail('应抛 CsGovernanceApiException');
      } on CsGovernanceApiException catch (e) {
        expect(e.isForbidden, true);
        expect(e.message, 'seat_disabled');
      }
    });
  });

  group('TSID lossless', () {
    test('organization_id int wire 形态兼容且转 String 保真（19 位）', () async {
      useAdapter(
        200,
        okEnvelope(
          payload: {
            'organization_id': 7266418340025468901, // int 兼容形态
            'seat_limit': 'unlimited',
            'used': 0,
          },
        ),
      );
      final view = await CsGovernanceApi().seatLimitView(orgId);
      expect(view.organizationId, '7266418340025468901');
      expect(view.organizationId.length, 19, reason: '超 double 精度 TSID 不丢位');
    });

    test('seat 行 identity TSID 逐字保真（string wire 主形态）', () async {
      useAdapter(
        200,
        okEnvelope(
          payload: {
            'seats': [
              {
                'organization_id': orgId,
                'business_identity_id': identityA,
                'function_key': 'customer_service',
                'enabled': true,
                'max_concurrent': 1,
                'active_count': 0,
              },
            ],
            'next_after_id': null,
          },
        ),
      );
      final page = await CsGovernanceApi().seatsPage(orgId);
      expect(page.rows.single.businessIdentityId, identityA);
    });
  });
}
