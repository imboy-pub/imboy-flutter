/// W04.d.g 受理合同客户端侧测试（channel-group-ux-v2.2 §6.4 C1）。
///
/// 离线合成：Env 钉 loopback（unit_test test_config）、SharedPreferences
/// mock、HttpClient.adapterForTest 拦截 HTTP。零真实网络、零真实用户、
/// 零外发。覆盖：
/// - J27.d/e 合同能力门精度（恰为整数 1）；
/// - J24.a 24h 客户端派发窗口时钟向量（含精确边界与时钟倒退）；
/// - J24.b 两个时钟独立（client 24h 派发 × server 7d 结果）；
/// - J24.c 同键规范等价与不换键（顺序/重复成员/改名/5463 只查未见/
///   受理完成后旧键不再外发）；
/// - 受理响应解析（稳定符号 5462-5465、信封拒绝 vs 传输未知）；
/// - 意图持久化 roundtrip / 隔离 / 损坏安全缺省 / 清除生命周期；
/// - GroupApi.createGroupWithReceipt 载荷契约（键不剥、recover_only、
///   scope/workspace_id 条件字段）；
/// - GroupCreationReceiptService 生命周期（意图先存后发、成功清除、
///   冲突保留、过期清除、无能力不剥键）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_contract.dart';
import 'package:imboy/service/creation_receipt/channel_creation_receipt_service.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';
import 'package:imboy/service/creation_receipt/group_creation_receipt_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/api/group_api.dart';

class _FailedIntentPreferences extends InMemorySharedPreferencesStore {
  _FailedIntentPreferences() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('creation_intent:')) return false;
    return super.setValue(valueType, key, value);
  }
}

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

  group('J24.b 两个时钟独立（client 24h 派发 × server 7d 结果）', () {
    test('J24.b 窗口内创建 POST（无 recover_only）遇服务器 7d 过期（5464）'
        '→ 意图保留不换键：server 年龄独立决定结果', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      // 窗口内（<24h）：相对当前时钟取 1 分钟前，避免绝对时间漂移。
      await saveCreationIntent(
        account: 'acct-j24b-window',
        operation: 'create_group',
        scopeId: 'personal',
        intent: CreationIntent(
          requestId: 'cri_j24b_w1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch - 60 * 1000,
          payload: const {
            'member_uids': ['880014'],
            'title': '原名',
          },
        ),
      );
      late Map<String, dynamic> body;
      final adapter = _ScriptedAdapter((options) async {
        body = Map<String, dynamic>.from(options.data as Map);
        // 服务器侧已过 7d：即使客户端窗口内发出创建 POST，服务端年龄
        // 独立判定过期（两个时钟分工，§6.4）。
        return _envelope({
          'code': 5464,
          'msg': 'recovery expired',
          'payload': {'gid': 9900123},
        });
      });
      HttpClient.adapterForTest = adapter;

      final outcome = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24b-window',
        workspaceId: null,
        memberUserIds: const ['880014'],
        title: '新名',
      );

      expect(outcome.ok, isFalse);
      // 服务器 5464 只是「服务器时钟下的过期」，不构成客户端可证明终态：
      // 统一 unknownPending，意图保留，绝不换键重建。
      expect(outcome.failure, CreationFlowFailure.unknownPending);
      // 窗口内仍是创建 POST：不带 recover_only。
      expect(body.containsKey('recover_only'), isFalse);
      expect(body['request_id'], 'cri_j24b_w1');
      // 客户端不因服务器过期而改载荷（服务端摘要比对负责冲突判定）。
      expect(body['title'], '原名');
      expect(
        (await loadCreationIntent(
          account: 'acct-j24b-window',
          operation: 'create_group',
          scopeId: 'personal',
        ))?.requestId,
        'cri_j24b_w1',
      );
    });

    test('J24.b 超 24h 意图 → recover_only 只查；服务器 7d 内健康受理'
        '→ replayed 成功并清意图（客户端窗口只管派发方式）', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      await saveCreationIntent(
        account: 'acct-j24b-recover',
        operation: 'create_group',
        scopeId: 'personal',
        intent: CreationIntent(
          requestId: 'cri_j24b_r1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch - _dayMs - 1,
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
          'code': 0,
          'msg': 'success',
          'payload': {
            'request_id': 'cri_j24b_r1',
            'creation_state': 'replayed',
            'group': {'id': 990077},
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      final outcome = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24b-recover',
        workspaceId: null,
        memberUserIds: const ['880014'],
        title: '无关名',
      );

      // 客户端 24h 只决定「只查派发」；服务器 7d 内且有权 → 仍返回完整
      // 受理结果（同 ID replayed），与客户端窗口无关。
      expect(outcome.ok, isTrue);
      expect(outcome.replayed, isTrue);
      expect(outcome.createdId, '990077');
      expect(body['recover_only'], isTrue);
      expect(body['request_id'], 'cri_j24b_r1');
      expect(
        await loadCreationIntent(
          account: 'acct-j24b-recover',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );
    });
  });

  group('J24.c 同键规范等价与不换键', () {
    test('J24.c 成员顺序不同/重复成员/workspace：存储原载荷原样重放，'
        '客户端不重排不去重不换载荷', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      await saveCreationIntent(
        account: 'acct-j24c-order',
        operation: 'create_group',
        scopeId: 'ws-9',
        intent: CreationIntent(
          requestId: 'cri_j24c_o1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          payload: const {
            'member_uids': ['880014', '880015'],
            'title': '原名',
            'scope': 'workspace',
            'workspace_id': 'ws-9',
          },
        ),
      );
      final bodies = <Map<String, dynamic>>[];
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        bodies.add(body);
        // 服务器按规范摘要判等价（顺序/重复成员归一）；此处 5462 冲突
        // 仅用于保持意图存活以便连续两次派发。
        return _envelope({
          'code': 5462,
          'msg': 'request id conflict',
          'payload': {'gid': 990001},
        });
      });
      HttpClient.adapterForTest = adapter;

      // 逆序成员 + 改名：客户端必须原样重放存储载荷。
      final first = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24c-order',
        workspaceId: 'ws-9',
        memberUserIds: const ['880015', '880014'],
        title: '改名',
      );
      expect(first.ok, isFalse);
      expect(first.failure, CreationFlowFailure.unknownPending);

      // 重复成员：同样原样重放存储载荷（客户端不去重、不规范化）。
      final second = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24c-order',
        workspaceId: 'ws-9',
        memberUserIds: const ['880014', '880014', '880015'],
        title: '再改名',
      );
      expect(second.ok, isFalse);

      expect(bodies, hasLength(2));
      for (final body in bodies) {
        expect(body['request_id'], 'cri_j24c_o1');
        expect(body['member_uids'], ['880014', '880015']);
        expect(body['title'], '原名');
        expect(body['scope'], 'workspace');
        expect(body['workspace_id'], 'ws-9');
      }
      expect(
        (await loadCreationIntent(
          account: 'acct-j24c-order',
          operation: 'create_group',
          scopeId: 'ws-9',
        ))?.requestId,
        'cri_j24c_o1',
      );
    });

    test('J24.c 只查未见受理（5463 create_not_accepted）→ 意图保留；'
        '再次派发仍原键（超时/断连/单次只查不构成终止证据）', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      await saveCreationIntent(
        account: 'acct-j24c-notacc',
        operation: 'create_group',
        scopeId: 'personal',
        intent: CreationIntent(
          requestId: 'cri_j24c_n1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch - _dayMs - 1,
          payload: const {
            'member_uids': ['880014'],
          },
        ),
      );
      final keys = <String?>[];
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        keys.add(body['request_id'] as String?);
        expect(body['recover_only'], isTrue);
        // 只查未见受理：仅表示查询时未见，不是终态证明（§6.4）。
        return _envelope({
          'code': 5463,
          'msg': 'create not accepted',
          'payload': <String, dynamic>{},
        });
      });
      HttpClient.adapterForTest = adapter;

      final first = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24c-notacc',
        workspaceId: null,
        memberUserIds: const ['880014'],
      );
      expect(first.ok, isFalse);
      expect(first.failure, CreationFlowFailure.unknownPending);
      expect(
        (await loadCreationIntent(
          account: 'acct-j24c-notacc',
          operation: 'create_group',
          scopeId: 'personal',
        ))?.requestId,
        'cri_j24c_n1',
      );

      // 单次只查未见后再次派发：仍用原键，绝不生成新键重建。
      final second = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24c-notacc',
        workspaceId: null,
        memberUserIds: const ['880014'],
      );
      expect(second.ok, isFalse);
      expect(keys, ['cri_j24c_n1', 'cri_j24c_n1']);
    });

    test('J24.c 迟到受理（replayed）成功后意图清除，旧键不再外发'
        '（同原键最多受理一次的客户端侧观察）', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      final keys = <String>[];
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        keys.add(body['request_id'] as String);
        return _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            'request_id': body['request_id'],
            'creation_state': 'replayed',
            'group': {'id': 990077},
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      final first = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24c-clear',
        workspaceId: null,
        memberUserIds: const ['880014'],
        title: '原名',
      );
      expect(first.ok, isTrue);
      expect(first.replayed, isTrue);
      expect(
        await loadCreationIntent(
          account: 'acct-j24c-clear',
          operation: 'create_group',
          scopeId: 'personal',
        ),
        isNull,
      );

      // 受理证据落地（意图已清）后，用户显式重新发起 → 新键，旧键不再外发。
      final second = await GroupCreationReceiptService().createOrRecoverGroup(
        account: 'acct-j24c-clear',
        workspaceId: null,
        memberUserIds: const ['880014'],
        title: '原名',
      );
      expect(second.ok, isTrue);
      expect(keys, hasLength(2));
      expect(keys[0], startsWith('cri_'));
      expect(keys[1], isNot(keys[0]));
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
      expect(outcome.failure, CreationFlowFailure.capabilityMissing);
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

      expect(outcome.failure, CreationFlowFailure.capabilityMissing);
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
      expect(outcome.createdId, '990077');
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
      // 保守合同：5462 也可能是代理伪造，统一 unknownPending、意图保留。
      expect(outcome.failure, CreationFlowFailure.unknownPending);
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

    test('>24h 意图 → recover_only 派发；5464 过期 → 意图保留不透传终态', () async {
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
      // 保守合同：5464 不可证明终态（可能为代理伪造），意图保留。
      expect(outcome.failure, CreationFlowFailure.unknownPending);
      expect(body['request_id'], 'cri_old_1');
      expect(body['recover_only'], isTrue);
      expect(
        (await loadCreationIntent(
          account: 'acct-expired',
          operation: 'create_group',
          scopeId: 'personal',
        ))?.requestId,
        'cri_old_1',
      );
    });
  });

  group('ChannelApi.createChannelWithReceipt（W04.d.c 载荷契约）', () {
    test('键不剥：request_id/name 恒在；recover_only 仅只查时出现', () async {
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            ...body,
            'id': 990188,
            'request_id': body['request_id'],
            'creation_state': 'accepted',
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      final r = await ChannelApi().createChannelWithReceipt(
        requestId: 'cri_ch_1',
        fields: {
          'name': '频道A',
          'visibility': 1,
          'access_type': 0,
          'join_policy': 1,
          'scope': 'workspace',
          'workspace_id': 'ws-9',
        },
      );

      expect(r.ok, isTrue);
      expect(r.creationState, 'accepted');
      expect(r.requestId, 'cri_ch_1');
      final body = Map<String, dynamic>.from(
        adapter.requests.single.data as Map,
      );
      expect(body['request_id'], 'cri_ch_1');
      expect(body['name'], '频道A');
      expect(body['visibility'], 1);
      expect(body['scope'], 'workspace');
      expect(body['workspace_id'], 'ws-9');
      expect(body.containsKey('recover_only'), isFalse);
      expect(adapter.requests.single.uri.path, '/api/v1/channel/create');
    });

    test('5464：channel_id 核对键提取 + 信封已交换', () async {
      final adapter = _ScriptedAdapter(
        (options) async => _envelope({
          'code': 5464,
          'msg': 'recovery expired',
          'payload': {'request_id': 'cri_ch_2', 'channel_id': 990188},
        }),
      );
      HttpClient.adapterForTest = adapter;

      final r = await ChannelApi().createChannelWithReceipt(
        requestId: 'cri_ch_2',
        fields: const {'name': '频道A'},
        recoverOnly: true,
      );

      expect(r.ok, isFalse);
      expect(r.errorSymbol, 'create_recovery_expired');
      expect(r.resourceId, '990188');
      expect(r.envelopeRejection, isTrue);
      final body = Map<String, dynamic>.from(
        adapter.requests.single.data as Map,
      );
      expect(body['recover_only'], isTrue);
    });
  });

  for (final operation in ['create_group', 'create_channel']) {
    for (final failure in [
      '502',
      '504',
      '500-empty',
      'malformed',
      'disconnect',
      'invalid-success',
    ]) {
      test('$operation $failure 结果未知：保留原键和载荷并原样重试', () async {
        AppManifestService.replaceForTest({
          'group_contracts': {'create_request_id': 1},
          'channel_contracts': {'create_request_id': 1},
        });
        final account = 'failure-$operation-$failure';
        var isRetry = false;
        final adapter = _ScriptedAdapter((options) async {
          if (isRetry) {
            return _envelope({
              'code': 0,
              'msg': 'success',
              'payload': {
                'request_id': (options.data as Map)['request_id'],
                'creation_state': 'replayed',
                if (operation == 'create_group') 'group': {'id': 7001},
                if (operation == 'create_channel') 'id': 6001,
              },
            });
          }
          switch (failure) {
            case '502':
            case '504':
              return ResponseBody.fromString(
                'upstream unavailable',
                int.parse(failure),
              );
            case '500-empty':
              return ResponseBody.fromString('', 500);
            case 'malformed':
              return ResponseBody.fromString(
                '{',
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            case 'invalid-success':
              return _envelope({'code': 0, 'payload': <String, dynamic>{}});
            default:
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: const SocketException('synthetic disconnect'),
              );
          }
        });
        HttpClient.adapterForTest = adapter;
        Future<CreationFlowOutcome> create(String name) =>
            operation == 'create_group'
            ? GroupCreationReceiptService().createOrRecoverGroup(
                account: account,
                workspaceId: null,
                memberUserIds: const ['880014'],
                title: name,
              )
            : ChannelCreationReceiptService().createOrRecoverChannel(
                account: account,
                name: name,
              );

        final first = await create('原名称');
        expect(first.ok, isFalse);
        expect(first.failure, CreationFlowFailure.unknownPending);
        final saved = await loadCreationIntent(
          account: account,
          operation: operation,
          scopeId: 'personal',
        );
        expect(saved, isNotNull);
        final firstBody = Map<String, dynamic>.from(
          adapter.requests.first.data as Map,
        );
        expect(firstBody['request_id'], saved!.requestId);
        isRetry = true;
        final second = await create('不应替换原载荷');
        expect(second.ok, isTrue);
        final lastBody = Map<String, dynamic>.from(
          adapter.requests.last.data as Map,
        );
        expect(lastBody, firstBody);
        expect(
          await loadCreationIntent(
            account: account,
            operation: operation,
            scopeId: 'personal',
          ),
          isNull,
        );
      });
    }
  }

  for (final operation in ['create_group', 'create_channel']) {
    test('$operation 意图持久化返回 false 时不发送 POST', () async {
      final previous = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailedIntentPreferences();
      addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
        'channel_contracts': {'create_request_id': 1},
      });
      final adapter = _ScriptedAdapter((_) async => _envelope({'code': 0}));
      HttpClient.adapterForTest = adapter;
      final future = operation == 'create_group'
          ? GroupCreationReceiptService().createOrRecoverGroup(
              account: 'write-fail-$operation',
              workspaceId: null,
              memberUserIds: const ['880014'],
            )
          : ChannelCreationReceiptService().createOrRecoverChannel(
              account: 'write-fail-$operation',
              name: '频道A',
            );
      await expectLater(future, throwsStateError);
      expect(adapter.requests, isEmpty);
    });
  }

  test('同一作用域并发创建串行，同一次失败重用原键', () async {
    final gate = Completer<CreationReceiptResult>();
    final called = Completer<void>();
    final requests = <String>[];
    Future<CreationFlowOutcome> create() => runCreationReceiptFlow(
      account: 'serial-account',
      operation: 'create_channel',
      scopeId: 'serial',
      capabilityEnabled: true,
      newPayload: const {'name': '原名称'},
      extractCreatedId: (p) => p['id']?.toString(),
      dispatch:
          ({required requestId, required storedPayload, required recoverOnly}) {
            requests.add(requestId);
            if (requests.length == 1) {
              called.complete();
              return gate.future;
            }
            return Future.value(const CreationReceiptResult(ok: false));
          },
    );
    final first = create();
    await called.future;
    final second = create();
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(1));
    gate.complete(const CreationReceiptResult(ok: false));
    await first;
    await second;
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
  });

  test('迟到结果不能清除已替换的意图', () async {
    final gate = Completer<CreationReceiptResult>();
    final called = Completer<void>();
    final first = runCreationReceiptFlow(
      account: 'late-account',
      operation: 'create_channel',
      scopeId: 'late',
      capabilityEnabled: true,
      newPayload: const {'name': '原名称'},
      extractCreatedId: (p) => p['id']?.toString(),
      dispatch:
          ({required requestId, required storedPayload, required recoverOnly}) {
            called.complete();
            return gate.future;
          },
    );
    await called.future;
    final original = await loadCreationIntent(
      account: 'late-account',
      operation: 'create_channel',
      scopeId: 'late',
    );
    expect(original, isNotNull);
    const replacement = CreationIntent(
      requestId: 'replacement-y',
      createdAtMs: 1,
      payload: {'name': '新意图'},
    );
    await saveCreationIntent(
      account: 'late-account',
      operation: 'create_channel',
      scopeId: 'late',
      intent: replacement,
    );
    gate.complete(
      CreationReceiptResult(
        ok: true,
        requestId: original!.requestId,
        creationState: 'accepted',
        payload: const {'id': 6001},
      ),
    );
    await first;
    final saved = await loadCreationIntent(
      account: 'late-account',
      operation: 'create_channel',
      scopeId: 'late',
    );
    expect(saved?.requestId, replacement.requestId);
    expect(saved?.payload, replacement.payload);
  });

  group('ChannelCreationReceiptService（W04.d.c 生命周期）', () {
    test('成功受理：意图键 create_channel 隔离，先存后发，成功后清除', () async {
      AppManifestService.replaceForTest({
        'channel_contracts': {'create_request_id': 1},
      });
      String? inFlightRequestId;
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        inFlightRequestId = body['request_id'] as String;
        final saved = await loadCreationIntent(
          account: 'acct-ch-ok',
          operation: 'create_channel',
          scopeId: 'ws-9',
        );
        expect(saved?.requestId, inFlightRequestId);
        expect(saved?.payload['name'], '频道A');
        return _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            'id': 990188,
            'name': '频道A',
            'scope': 'workspace',
            'request_id': inFlightRequestId,
            'creation_state': 'replayed',
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      final outcome = await ChannelCreationReceiptService()
          .createOrRecoverChannel(
            account: 'acct-ch-ok',
            name: '频道A',
            visibility: 1,
            accessType: 0,
            joinPolicy: 1,
            workspace: true,
            workspaceId: 'ws-9',
          );

      expect(outcome.ok, isTrue);
      expect(outcome.replayed, isTrue);
      expect(outcome.createdId, '990188');
      expect(inFlightRequestId, startsWith('cri_'));
      // 群路意图不得被频道路波及（operation 隔离）。
      expect(
        await loadCreationIntent(
          account: 'acct-ch-ok',
          operation: 'create_group',
          scopeId: 'ws-9',
        ),
        isNull,
      );
      expect(
        await loadCreationIntent(
          account: 'acct-ch-ok',
          operation: 'create_channel',
          scopeId: 'ws-9',
        ),
        isNull,
      );
    });

    test('群能力开启但频道能力关闭 → 频道路 capabilityMissing，零 HTTP', () async {
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });
      final adapter = _ScriptedAdapter(
        (options) async => _envelope({
          'code': 0,
          'msg': 'success',
          'payload': <String, dynamic>{},
        }),
      );
      HttpClient.adapterForTest = adapter;

      final outcome = await ChannelCreationReceiptService()
          .createOrRecoverChannel(account: 'acct-ch-gate', name: '频道A');

      expect(outcome.failure, CreationFlowFailure.capabilityMissing);
      expect(outcome.pendingIntentBlocked, isFalse);
      expect(adapter.requests, isEmpty);
    });

    test('工作区频道路 5462 冲突：原键原载荷重放，意图保留', () async {
      AppManifestService.replaceForTest({
        'channel_contracts': {'create_request_id': 1},
      });
      await saveCreationIntent(
        account: 'acct-ch-conflict',
        operation: 'create_channel',
        scopeId: 'ws-9',
        intent: CreationIntent(
          requestId: 'cri_ch_replay',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          payload: const {
            'name': '原名',
            'visibility': 1,
            'access_type': 0,
            'join_policy': 1,
            'scope': 'workspace',
            'workspace_id': 'ws-9',
          },
        ),
      );
      late Map<String, dynamic> body;
      final adapter = _ScriptedAdapter((options) async {
        body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 5462,
          'msg': 'request id conflict',
          'payload': {'channel_id': 990188},
        });
      });
      HttpClient.adapterForTest = adapter;

      // 调用方传入不同名称也不得换载荷（同键绝不换载荷）。
      final outcome = await ChannelCreationReceiptService()
          .createOrRecoverChannel(
            account: 'acct-ch-conflict',
            name: '改名频道',
            visibility: 1,
            workspace: true,
            workspaceId: 'ws-9',
          );

      expect(outcome.ok, isFalse);
      // 保守合同：5462 也可能是代理伪造，统一 unknownPending、意图保留。
      expect(outcome.failure, CreationFlowFailure.unknownPending);
      expect(body['request_id'], 'cri_ch_replay');
      expect(body['name'], '原名');
      expect(body['scope'], 'workspace');
      expect(body['workspace_id'], 'ws-9');
      expect(body.containsKey('recover_only'), isFalse);
      expect(
        (await loadCreationIntent(
          account: 'acct-ch-conflict',
          operation: 'create_channel',
          scopeId: 'ws-9',
        ))?.requestId,
        'cri_ch_replay',
      );
    });

    test('J24.c 频道同键改名与 5463 只查未见：原载荷原样重放，'
        '意图保留不换键（单次只查不是终止证据）', () async {
      AppManifestService.replaceForTest({
        'channel_contracts': {'create_request_id': 1},
      });
      await saveCreationIntent(
        account: 'acct-ch-j24c',
        operation: 'create_channel',
        scopeId: 'ws-9',
        intent: CreationIntent(
          requestId: 'cri_ch_j24c_1',
          createdAtMs: DateTime.now().millisecondsSinceEpoch - _dayMs - 1,
          payload: const {
            'name': '原名',
            'scope': 'workspace',
            'workspace_id': 'ws-9',
          },
        ),
      );
      final bodies = <Map<String, dynamic>>[];
      final adapter = _ScriptedAdapter((options) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        bodies.add(body);
        return _envelope({
          'code': 5463,
          'msg': 'create not accepted',
          'payload': <String, dynamic>{},
        });
      });
      HttpClient.adapterForTest = adapter;

      // 调用方传新名：仍按存储载荷只查（同键绝不换载荷）。
      final first = await ChannelCreationReceiptService()
          .createOrRecoverChannel(
            account: 'acct-ch-j24c',
            name: '改名频道',
            workspace: true,
            workspaceId: 'ws-9',
          );
      expect(first.ok, isFalse);
      expect(first.failure, CreationFlowFailure.unknownPending);

      // 单次只查未见后再派发：仍原键原载荷。
      final second = await ChannelCreationReceiptService()
          .createOrRecoverChannel(
            account: 'acct-ch-j24c',
            name: '改名频道',
            workspace: true,
            workspaceId: 'ws-9',
          );
      expect(second.ok, isFalse);

      expect(bodies, hasLength(2));
      for (final body in bodies) {
        expect(body['request_id'], 'cri_ch_j24c_1');
        expect(body['name'], '原名');
        expect(body['scope'], 'workspace');
        expect(body['workspace_id'], 'ws-9');
        expect(body['recover_only'], isTrue);
      }
      expect(
        (await loadCreationIntent(
          account: 'acct-ch-j24c',
          operation: 'create_channel',
          scopeId: 'ws-9',
        ))?.requestId,
        'cri_ch_j24c_1',
      );
    });
  });
}
