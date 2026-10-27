/// W04.d.g 受理合同客户端侧测试（channel-group-ux-v2.2 §6.4 C1）。
///
/// 离线合成：Env 钉 loopback（unit_test test_config）、SharedPreferences
/// mock、HttpClient.adapterForTest 拦截 HTTP。零真实网络、零真实用户、
/// 零外发。覆盖：
/// - J27.d/e 合同能力门精度（恰为整数 1）；
/// - J24.a 24h 客户端派发窗口时钟向量（含精确边界与时钟倒退）；
/// - 受理响应解析（稳定符号 5462-5465、信封拒绝 vs 传输未知）；
/// - 意图持久化 roundtrip / 隔离 / 损坏安全缺省 / 清除生命周期；
/// - GroupApi.createGroupWithReceipt 载荷契约（键不剥、recover_only、
///   scope/workspace_id 条件字段）；
/// - GroupCreationReceiptService 生命周期（意图先存后发、成功清除、
///   冲突保留、过期清除、无能力不剥键）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_contract.dart';
import 'package:imboy/service/creation_receipt/group_creation_receipt_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/group_api.dart';

/// 捕获请求并按回调回应的合成 adapter。
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  Map<String, dynamic> get lastBody {
    final data = requests.last.data;
    assert(data is Map, 'expected JSON body map, got ${data.runtimeType}');
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _envelope(Map<String, dynamic> body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const int _dayMs = 24 * 60 * 60 * 1000;

void main() {
  setUp(() {
    AppManifestService.replaceForTest(<String, dynamic>{});
    // 安全存储通道 mock 为「无数据」：read→null 使 accessToken='' 且不抛
    // 异常，避免 token_decryption_failed 标记把请求拦在 _setDefaultConfig
    // （不发出请求 → 被判为传输失败），该标记会跨用例泄漏导致交替失败。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    // 清除此前任何用例/套件遗留的解密失败标记（quitLogin 内部读取也会置位）。
    StorageService.to.setBool('token_decryption_failed', false);
  });

  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  group('createReceiptContractEnabled（J27.d/e 门精度）', () {
    test('恰为整数 1 才启用', () {
      expect(createReceiptContractEnabled(null), isFalse);
      expect(createReceiptContractEnabled(const {}), isFalse);
      expect(
        createReceiptContractEnabled(const {'create_request_id': 1}),
        isTrue,
      );
    });

    test('true / "1" / 2 / 0 / 1.0 等一律不启用（绝不激进解释）', () {
      for (final raw in const [
        true,
        '1',
        2,
        0,
        1.0,
        'create_request_id',
        <String, dynamic>{},
      ]) {
        expect(
          createReceiptContractEnabled({'create_request_id': raw}),
          isFalse,
          reason: 'create_request_id=$raw (${raw.runtimeType}) 不应启用',
        );
      }
    });
  });

  group('decideCreationDispatch（J24.a 时钟向量）', () {
    test('无意图 → 可创建（首次受理）', () {
      final d = decideCreationDispatch(intentCreatedAtMs: null, nowMs: 1);
      expect(d.mayCreate, isTrue);
      expect(d.recoverOnly, isFalse);
      expect(d.clockUntrusted, isFalse);
    });

    test('窗口内（23:59:59.999）→ 仍可原键创建', () {
      const created = 1750000000000;
      final d = decideCreationDispatch(
        intentCreatedAtMs: created,
        nowMs: created + _dayMs - 1,
      );
      expect(d.mayCreate, isTrue);
      expect(d.recoverOnly, isFalse);
      expect(d.clockUntrusted, isFalse);
    });

    test('24h 精确边界（含）→ 仅 recover_only，不剥键', () {
      const created = 1750000000000;
      final exact = decideCreationDispatch(
        intentCreatedAtMs: created,
        nowMs: created + _dayMs,
      );
      expect(exact.mayCreate, isFalse);
      expect(exact.recoverOnly, isTrue);
      expect(exact.clockUntrusted, isFalse);

      final beyond = decideCreationDispatch(
        intentCreatedAtMs: created,
        nowMs: created + _dayMs + 1,
      );
      expect(beyond.mayCreate, isFalse);
      expect(beyond.recoverOnly, isTrue);
    });

    test('时钟倒退 → 仅 recover_only 且 clockUntrusted', () {
      const created = 1750000000000;
      final d = decideCreationDispatch(
        intentCreatedAtMs: created,
        nowMs: created - 1,
      );
      expect(d.mayCreate, isFalse);
      expect(d.recoverOnly, isTrue);
      expect(d.clockUntrusted, isTrue);
    });
  });

  group('creationErrorSymbol（5462-5465 稳定符号）', () {
    test('合同码映射，非合同码为 null', () {
      expect(creationErrorSymbol(5462), 'request_id_conflict');
      expect(creationErrorSymbol(5463), 'create_not_accepted');
      expect(creationErrorSymbol(5464), 'create_recovery_expired');
      expect(creationErrorSymbol(5465), 'create_resource_unavailable');
      expect(creationErrorSymbol(0), isNull);
      expect(creationErrorSymbol(1), isNull);
      expect(creationErrorSymbol(500), isNull);
    });
  });

  group('parseCreationReceiptResponse（信封解析）', () {
    test('成功：accepted / replayed 及增量字段缺失（旧后端）不致命', () {
      final accepted = parseCreationReceiptResponse(
        ok: true,
        code: 0,
        msg: 'success',
        payload: {
          'request_id': 'cri_x',
          'creation_state': 'accepted',
          'group': {'id': 990077},
        },
        extractResourceId: (p) => '${p['group']['id']}',
      );
      expect(accepted.ok, isTrue);
      expect(accepted.creationState, 'accepted');
      expect(accepted.requestId, 'cri_x');
      expect(accepted.errorSymbol, isNull);
      expect(accepted.envelopeRejection, isFalse);

      final legacy = parseCreationReceiptResponse(
        ok: true,
        code: 0,
        msg: 'success',
        payload: <String, dynamic>{},
        extractResourceId: (_) => null,
      );
      expect(legacy.ok, isTrue);
      expect(legacy.creationState, isNull);
      expect(legacy.requestId, isNull);
    });

    test('5462 冲突：稳定符号 + 核对 ID + 信封已交换', () {
      final r = parseCreationReceiptResponse(
        ok: false,
        code: 5462,
        msg: 'request id conflict',
        payload: {'gid': 9900123},
        extractResourceId: (p) => p['gid']?.toString(),
      );
      expect(r.ok, isFalse);
      expect(r.errorSymbol, 'request_id_conflict');
      expect(r.errorText, 'request id conflict');
      expect(r.resourceId, '9900123');
      expect(r.envelopeRejection, isTrue);
    });

    test('非合同信封拒绝：无符号但仍视为已交换', () {
      final r = parseCreationReceiptResponse(
        ok: false,
        code: 500,
        msg: 'boom',
        payload: <String, dynamic>{},
        extractResourceId: (_) => null,
      );
      expect(r.ok, isFalse);
      expect(r.errorSymbol, isNull);
      expect(r.envelopeRejection, isTrue);
    });
  });

  group('CreationIntentStore（roundtrip / 隔离 / 损坏安全缺省）', () {
    const intent = CreationIntent(
      requestId: 'cri_unit_1',
      createdAtMs: 1750000000000,
      payload: {
        'member_uids': ['880014'],
        'title': '群名',
      },
    );

    test('save → load 原样恢复，载荷不剥键', () async {
      await saveCreationIntent(
        account: 'acct-roundtrip',
        operation: 'create_group',
        scopeId: 'personal',
        intent: intent,
      );
      final loaded = await loadCreationIntent(
        account: 'acct-roundtrip',
        operation: 'create_group',
        scopeId: 'personal',
      );
      expect(loaded?.requestId, 'cri_unit_1');
      expect(loaded?.createdAtMs, 1750000000000);
      expect(loaded?.payload['member_uids'], ['880014']);
      expect(loaded?.payload['title'], '群名');
    });

    test('账号/操作/scopeId 任一不同即互不可见', () async {
      await saveCreationIntent(
        account: 'acct-iso',
        operation: 'create_group',
        scopeId: 'personal',
        intent: intent,
      );
      expect(
        await loadCreationIntent(
          account: 'acct-other',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );
      expect(
        await loadCreationIntent(
          account: 'acct-iso',
          operation: 'create_channel',
          scopeId: 'personal',
        ),
        isNull,
      );
      expect(
        await loadCreationIntent(
          account: 'acct-iso',
          operation: 'create_group',
          scopeId: 'ws-77',
        ),
        isNull,
      );
    });

    test('clear 后读不到；键不存在返回 null；坏 JSON 安全缺省 null', () async {
      await saveCreationIntent(
        account: 'acct-clear',
        operation: 'create_group',
        scopeId: 'personal',
        intent: intent,
      );
      await clearCreationIntent(
        account: 'acct-clear',
        operation: 'create_group',
        scopeId: 'personal',
      );
      expect(
        await loadCreationIntent(
          account: 'acct-clear',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );

      // 直接写坏 JSON 验证损坏安全缺省（沿用 rename_pending_store 先例）。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        creationIntentStorageKey('acct-bad', 'create_group', 'personal'),
        '{not-json',
      );
      expect(
        await loadCreationIntent(
          account: 'acct-bad',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );
    });

    test('generateCreationRequestId 格式与唯一性', () {
      final a = generateCreationRequestId();
      final b = generateCreationRequestId();
      expect(a, startsWith('cri_'));
      expect(a.length, greaterThan(10));
      expect(a, isNot(b));
    });
  });

  group('GroupApi.createGroupWithReceipt（载荷契约）', () {
    test('键不剥：request_id/member_uids 恒在；条件字段按需出现', () async {
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            'request_id': body['request_id'],
            'creation_state': 'accepted',
            'group': {'id': 990077},
            'member_list': <Map<String, dynamic>>[],
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      final r = await GroupApi().createGroupWithReceipt(
        requestId: 'cri_api_1',
        memberUserIds: const ['880014'],
        title: '标题',
        workspaceId: 'ws-9',
      );

      expect(r.ok, isTrue);
      expect(r.creationState, 'accepted');
      expect(r.requestId, 'cri_api_1');
      final body = Map<String, dynamic>.from(
        adapter.requests.single.data as Map,
      );
      expect(body['request_id'], 'cri_api_1');
      expect(body['member_uids'], ['880014']);
      expect(body['title'], '标题');
      expect(body['scope'], 'workspace');
      expect(body['workspace_id'], 'ws-9');
      expect(body.containsKey('recover_only'), isFalse);
      expect(adapter.requests.single.uri.path, API.groupAdd);
    });

    test('recover_only=true 时携带标志；title/scope 缺省不发送', () async {
      late Map<String, dynamic> body;
      final adapter = _ScriptedAdapter((options) async {
        body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 5464,
          'msg': 'recovery expired',
          'payload': {'gid': 9900123},
        });
      });
      HttpClient.adapterForTest = adapter;

      final r = await GroupApi().createGroupWithReceipt(
        requestId: 'cri_api_2',
        memberUserIds: const ['880014'],
        recoverOnly: true,
      );

      expect(r.ok, isFalse);
      expect(r.errorSymbol, 'create_recovery_expired');
      expect(r.resourceId, '9900123');
      expect(r.envelopeRejection, isTrue);
      expect(body['recover_only'], isTrue);
      expect(body.containsKey('title'), isFalse);
      expect(body.containsKey('scope'), isFalse);
      expect(body.containsKey('workspace_id'), isFalse);
    });

    test('传输失败 → envelopeRejection=false（结果未知，意图必须保留）', () async {
      final adapter = _ScriptedAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      HttpClient.adapterForTest = adapter;

      final r = await GroupApi().createGroupWithReceipt(
        requestId: 'cri_api_3',
        memberUserIds: const ['880014'],
      );

      expect(r.ok, isFalse);
      expect(r.errorSymbol, isNull);
      expect(r.envelopeRejection, isFalse);
    });
  });

  group('GroupCreationReceiptService（意图生命周期）', () {
    test('无能力且无意图 → capabilityMissing，零 HTTP，可走旧路径', () async {
      final adapter = _ScriptedAdapter(
        (options) async => _envelope({
          'code': 0,
          'msg': 'success',
          'payload': <String, dynamic>{},
        }),
      );
      HttpClient.adapterForTest = adapter;

      final outcome = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-nocap',
        workspaceId: null,
        memberUserIds: const ['880014'],
        title: 'x',
      );

      expect(outcome.ok, isFalse);
      expect(outcome.failure, GroupCreationFailure.capabilityMissing);
      expect(outcome.pendingIntentBlocked, isFalse);
      expect(adapter.requests, isEmpty);
      expect(
        await loadCreationIntent(
          account: 'acct-nocap',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );
    });

    test('无能力但已有未知意图 → pendingIntentBlocked（绝不剥键走旧 POST）', () async {
      final adapter = _ScriptedAdapter(
        (options) async => _envelope({
          'code': 0,
          'msg': 'success',
          'payload': <String, dynamic>{},
        }),
      );
      HttpClient.adapterForTest = adapter;
      await saveCreationIntent(
        account: 'acct-blocked',
        operation: 'create_group',
        scopeId: 'personal',
        intent: CreationIntent(
          requestId: 'cri_pre_1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          payload: const {
            'member_uids': ['880014'],
          },
        ),
      );

      final outcome = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-blocked',
        workspaceId: null,
        memberUserIds: const ['880014'],
      );

      expect(outcome.failure, GroupCreationFailure.capabilityMissing);
      expect(outcome.pendingIntentBlocked, isTrue);
      expect(adapter.requests, isEmpty);
      // 意图保留，不得清除。
      expect(
        (await loadCreationIntent(
          account: 'acct-blocked',
          operation: 'create_group',
          scopeId: 'personal',
        ))?.requestId,
        'cri_pre_1',
      );
    });

    test('成功受理：意图先存后发、request_id 进载荷、成功后清除', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      String? inFlightRequestId;
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        inFlightRequestId = body['request_id'] as String;
        // 请求发出时意图必须已持久化（先存后发，§6.4）。
        final saved = await loadCreationIntent(
          account: 'acct-ok',
          operation: 'create_group',
          scopeId: 'personal',
        );
        expect(saved?.requestId, inFlightRequestId);
        return _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            'request_id': inFlightRequestId,
            'creation_state': 'accepted',
            'group': {'id': 990077},
            'member_list': <Map<String, dynamic>>[],
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      final outcome = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-ok',
        workspaceId: null,
        memberUserIds: const ['880014'],
        title: '新群',
      );

      expect(outcome.ok, isTrue);
      expect(outcome.replayed, isFalse);
      expect(outcome.gid, '990077');
      expect(inFlightRequestId, startsWith('cri_'));
      expect(
        await loadCreationIntent(
          account: 'acct-ok',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );
    });

    test('5462 冲突：同键原载荷重放，意图保留', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      await saveCreationIntent(
        account: 'acct-conflict',
        operation: 'create_group',
        scopeId: 'personal',
        intent: CreationIntent(
          requestId: 'cri_replay_1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          payload: const {
            'member_uids': ['880014'],
            'title': '原名',
          },
        ),
      );
      late Map<String, dynamic> body;
      final adapter = _ScriptedAdapter((options) async {
        body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 5462,
          'msg': 'request id conflict',
          'payload': {'gid': 990001},
        });
      });
      HttpClient.adapterForTest = adapter;

      // 调用方传入不同成员/标题也不得换载荷（同键绝不换载荷）。
      final outcome = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-conflict',
        workspaceId: null,
        memberUserIds: const ['999999'],
        title: '改名',
      );

      expect(outcome.ok, isFalse);
      expect(outcome.failure, GroupCreationFailure.conflict);
      expect(body['request_id'], 'cri_replay_1');
      // 重放用存储载荷，不是调用方新载荷。
      expect(body['member_uids'], ['880014']);
      expect(body['title'], '原名');
      expect(body.containsKey('recover_only'), isFalse);
      expect(
        (await loadCreationIntent(
          account: 'acct-conflict',
          operation: 'create_group',
          scopeId: 'personal',
        ))?.requestId,
        'cri_replay_1',
      );
    });

    test('>24h 意图 → recover_only 派发；5464 过期 → 意图清除 + 核对 ID', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      await saveCreationIntent(
        account: 'acct-expired',
        operation: 'create_group',
        scopeId: 'personal',
        intent: CreationIntent(
          requestId: 'cri_old_1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch - _dayMs - 1,
          payload: const {
            'member_uids': ['880014'],
          },
        ),
      );
      late Map<String, dynamic> body;
      final adapter = _ScriptedAdapter((options) async {
        body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 5464,
          'msg': 'recovery expired',
          'payload': {'gid': 9900123},
        });
      });
      HttpClient.adapterForTest = adapter;

      final outcome = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-expired',
        workspaceId: null,
        memberUserIds: const ['880014'],
      );

      expect(outcome.ok, isFalse);
      expect(outcome.failure, GroupCreationFailure.recoveryExpired);
      expect(outcome.resourceId, '9900123');
      expect(body['request_id'], 'cri_old_1');
      expect(body['recover_only'], isTrue);
      expect(
        await loadCreationIntent(
          account: 'acct-expired',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );
    });
  });
}
