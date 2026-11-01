// J01.a / J03.a — 工作区建群语义单元测试（plan-v2.2 §9）。
//
// plan §9 落点 AG（test/unit_test/api/group_api_test.dart 为 live-API 合同
// 文件，需要真实后端与本机写入授权）。本文件是同一 AG 目录下的离线合成
// 通道：零真实网络、零真实用户，语义断言与本仓既有受理合同套件同源
// （HttpClient.adapterForTest 拦截 HTTP）。live-API 正例（真实服务端
// 归属/成员/进群效果）由 integration_test/workspace/j01a_* 设备脚本承担。
//
// 断言映射：
// - J01.a 归属：scope=workspace + workspace_id 进请求（服务端按 scope
//   校验归属，客户端不预判）；
// - J01.a 成员集合：member_uids 按所选原样透传（1 人 / 多人向量）；
// - J01.a 成功进同群（客户端可观察面）：成功应答提取 group.id，失败时
//   error 非空且 gid 空（进群效果本身属服务端，设备脚本验证）；
// - J01.a 不偷改单聊：工作区建群全程仅 group/add 一条请求（无 C2C/
//   conversation 端点被触碰）；个人域建群（workspaceId=null 的受理链）
//   载荷绝不携带 scope/workspace_id 键——两域互不串写；
// - J03.a 按钮/深链同口：无资格（guest）被服务端拒绝时客户端拿到可
//   展示 error，单次请求无副作用链（无重试风暴、无二次写端点）；
// - J03.a 合同路径：业务拒绝 → unknownPending、意图保留，下一次调用
//   同键同载荷重试（不产生新资源/新受理/新成员副作用）。

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';
import 'package:imboy/service/creation_receipt/group_creation_receipt_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/group_api.dart';

const MethodChannel _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// 捕获请求并按回调回应的合成 adapter（与受理合同套件同款）。
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  Map<String, dynamic> bodyAt(int index) =>
      Map<String, dynamic>.from(requests[index].data as Map);

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

const String _account = 'j01a-synthetic-account';

void main() {
  // 纯 dart test（无 widget pump）也需显式初始化 binding：
  // MethodChannel mock（secure_storage）依赖 TestDefaultBinaryMessenger。
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 安全存储通道 mock 为「无数据」：read→null 使 accessToken='' 且不抛
    // 异常，避免 token_decryption_failed 标记把请求拦在 _setDefaultConfig
    // （不发出请求 → 被判为传输失败），该标记会跨用例泄漏导致交替失败。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
    StorageService.to.setBool('token_decryption_failed', false);
  });

  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  group('J01.a 工作区建群（owner/member；选择1人/多人）', () {
    test('J01.a-1 归属：scope=workspace + workspace_id 进请求（1 人向量）', () async {
      late Map<String, dynamic> body;
      final adapter = _ScriptedAdapter((options) async {
        body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            'group': {'id': '130619900000000901'},
            'member_list': <Map<String, dynamic>>[],
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      final r = await GroupApi().createWorkspaceGroup(
        workspaceId: '120619900000000004',
        memberUserIds: const ['880101'],
      );

      expect(r.error, isNull, reason: '成功路径不应带 error');
      expect(r.gid, '130619900000000901');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri.path, '/api/v1/group/add');
      // 归属三键：服务端按 scope 校验归属；客户端只透传不预判。
      expect(body['scope'], 'workspace');
      expect('${body['workspace_id']}', '120619900000000004');
      // TSID 精度：workspace_id 不得经 int 回转。
      expect(
        body['workspace_id'] is String,
        isTrue,
        reason: 'workspace_id 必须保字符串 TSID 精度',
      );
      expect(body['member_uids'], ['880101']);
    });

    test('J01.a-2 成员集合：多人向量按所选原样、保序全量透传', () async {
      late Map<String, dynamic> body;
      final adapter = _ScriptedAdapter((options) async {
        body = Map<String, dynamic>.from(options.data as Map);
        return _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            'group': {'id': '130619900000000902'},
            'member_list': <Map<String, dynamic>>[],
          },
        });
      });
      HttpClient.adapterForTest = adapter;

      const members = ['880101', '880102', '880103', '880104'];
      final r = await GroupApi().createWorkspaceGroup(
        workspaceId: '120619900000000004',
        memberUserIds: members,
      );

      expect(r.error, isNull);
      expect(r.gid, '130619900000000902');
      expect(body['member_uids'], members, reason: '成员集合必须按所选原样（不重排/不去重/不增删）');
    });

    test('J01.a-3 客户端可观察面：成功提取 group.id；失败 error 原样、gid 空', () async {
      // 成功形状：group.id 缺失/空 → 明确错误，绝不静默假成功。
      final emptyIdAdapter = _ScriptedAdapter(
        (options) async => _envelope({
          'code': 0,
          'msg': 'success',
          'payload': {
            'group': <String, dynamic>{},
            'member_list': <Map<String, dynamic>>[],
          },
        }),
      );
      HttpClient.adapterForTest = emptyIdAdapter;
      final badShape = await GroupApi().createWorkspaceGroup(
        workspaceId: '120619900000000004',
        memberUserIds: const ['880101'],
      );
      expect(badShape.error, isNotNull, reason: '缺群 ID 必须报错，不得假成功');
      expect(badShape.gid, isEmpty);

      // 服务端拒绝（无资格）：业务错误原样透出为 error（客户端解释面）。
      final rejectAdapter = _ScriptedAdapter(
        (options) async => _envelope({'code': 10403, 'msg': '无工作区创建权限'}),
      );
      HttpClient.adapterForTest = rejectAdapter;
      final rejected = await GroupApi().createWorkspaceGroup(
        workspaceId: '120619900000000004',
        memberUserIds: const ['880101'],
      );
      expect(rejected.gid, isEmpty);
      expect(rejected.error, contains('无工作区创建权限'), reason: '服务端文案应原样透出供客户端解释');
    });

    test(
      'J01.a-4 不偷改单聊：工作区建群仅一条 group/add；个人域受理载荷无 scope/workspace_id 键',
      () async {
        // (a) 工作区建群全程只有 group/add 一条请求，无任何 C2C/conversation
        //     端点被触碰（单聊不受影响由请求面保证）。
        final wsAdapter = _ScriptedAdapter(
          (options) async => _envelope({
            'code': 0,
            'msg': 'success',
            'payload': {
              'group': {'id': '130619900000000903'},
              'member_list': <Map<String, dynamic>>[],
            },
          }),
        );
        HttpClient.adapterForTest = wsAdapter;
        await GroupApi().createWorkspaceGroup(
          workspaceId: '120619900000000004',
          memberUserIds: const ['880101'],
        );
        expect(wsAdapter.requests, hasLength(1));
        expect(wsAdapter.requests.single.uri.path, '/api/v1/group/add');
        expect(
          wsAdapter.requests.map((r) => r.uri.path),
          everyElement(contains('/api/v1/group/add')),
          reason: '工作区建群不得触碰单聊/会话端点',
        );

        // (b) 个人域建群（workspaceId=null，发起聊天同链）：受理载荷只有
        //     成员（+可选初始名），绝不携带 scope/workspace_id —— 域隔离，
        //     工作区归属键不得泄入个人域请求。
        final personalAdapter = _ScriptedAdapter((options) async {
          final incoming = Map<String, dynamic>.from(options.data as Map);
          return _envelope({
            'code': 0,
            'msg': 'success',
            'payload': {
              // 受理合同：服务端必须回显客户端生成的 request_id。
              'request_id': incoming['request_id'],
              'creation_state': 'accepted',
              'group': {'id': '990880'},
              'member_list': <Map<String, dynamic>>[],
            },
          });
        });
        HttpClient.adapterForTest = personalAdapter;
        // 受理合同路径需要 manifest 能力门开启（门精度由 J27.d/e 套件承担）。
        AppManifestService.replaceForTest({
          'group_contracts': {'create_request_id': 1},
        });
        final outcome = await GroupCreationReceiptService()
            .createOrRecoverGroup(
              account: _account,
              workspaceId: null,
              memberUserIds: const ['880101'],
              title: '个人域群',
            );
        AppManifestService.replaceForTest(<String, dynamic>{});
        expect(outcome.ok, isTrue, reason: '能力门开启且受理成功 → ok');
        final body = Map<String, dynamic>.from(
          personalAdapter.requests.single.data as Map,
        );
        expect(body.containsKey('scope'), isFalse, reason: '个人域建群不得携带 scope 键');
        expect(
          body.containsKey('workspace_id'),
          isFalse,
          reason: '个人域建群不得携带 workspace_id 键',
        );
        expect(body['member_uids'], ['880101']);
        expect(personalAdapter.requests, hasLength(1));
      },
    );
  });

  group('J03.a guest/无资格创建工作区资源（按钮与深链同口拒绝、无副作用）', () {
    test('J03.a-1 键less 回退路径：服务端拒绝 → error 原样、单请求无副作用链', () async {
      final adapter = _ScriptedAdapter(
        (options) async => ResponseBody.fromString(
          jsonEncode({'code': 10403, 'msg': '仅工作区成员可创建'}),
          403,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      HttpClient.adapterForTest = adapter;

      final r = await GroupApi().createWorkspaceGroup(
        workspaceId: '120619900000000004',
        memberUserIds: const ['880101'],
      );

      // 客户端解释：error 原样可展示，不吞错不假成功。
      expect(r.gid, isEmpty);
      expect(r.error, contains('仅工作区成员可创建'));
      // 无副作用：恰好一条创建请求，无重试风暴、无后续成员/编辑端点。
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri.path, '/api/v1/group/add');
    });

    test('J03.a-2 合同路径：业务拒绝 → unknownPending 意图保留，重试同键同载荷（无新受理副作用）', () async {
      final adapter = _ScriptedAdapter(
        (options) async => _envelope({'code': 10403, 'msg': '无工作区创建权限'}),
      );
      HttpClient.adapterForTest = adapter;
      // 受理合同路径需要 manifest 能力门开启（拒绝向量本身由服务端给出）。
      AppManifestService.replaceForTest({
        'group_contracts': {'create_request_id': 1},
      });

      // 第一次（按钮）：意图先存后发，被服务端拒绝 → unknownPending、
      // 意图保留（不提供换键恢复，§6.4）。
      final first = await GroupCreationReceiptService().createOrRecoverGroup(
        account: _account,
        workspaceId: '120619900000000004',
        memberUserIds: const ['880101'],
        title: 'guest 试图建的群',
      );
      expect(first.ok, isFalse);
      expect(first.failure, CreationFlowFailure.unknownPending);
      expect(adapter.requests, hasLength(1));
      final firstBody = Map<String, dynamic>.from(
        adapter.requests.single.data as Map,
      );
      final storedRequestId = firstBody['request_id'];

      // 意图保留：未产生资源/受理成功痕迹。
      final intent = await loadCreationIntent(
        account: _account,
        operation: 'create_group',
        scopeId: '120619900000000004',
      );
      expect(intent, isNotNull, reason: '拒绝后意图必须保留供安全恢复');
      expect(intent?.requestId, storedRequestId);

      // 第二次（深链/再点）：同键同载荷重试，绝不生成新键新载荷——
      // 无资格账号反复尝试也不会产生第二个受理。
      final second = await GroupCreationReceiptService().createOrRecoverGroup(
        account: _account,
        workspaceId: '120619900000000004',
        memberUserIds: const ['999999'],
        title: '换了名字也没用',
      );
      expect(second.ok, isFalse);
      expect(second.failure, CreationFlowFailure.unknownPending);
      expect(adapter.requests, hasLength(2), reason: '第二次仍只发一条请求');
      final secondBody = Map<String, dynamic>.from(
        adapter.requests.last.data as Map,
      );
      expect(
        secondBody['request_id'],
        storedRequestId,
        reason: '重试必须同键（同 request_id）',
      );
      expect(secondBody['member_uids'], [
        '880101',
      ], reason: '重试必须用存储载荷（同键绝不换载荷）');
      expect(secondBody['title'], 'guest 试图建的群');
      expect(
        (await loadCreationIntent(
          account: _account,
          operation: 'create_group',
          scopeId: '120619900000000004',
        ))?.requestId,
        storedRequestId,
        reason: '意图在重试后依旧保留（未被拒绝清除）',
      );
    });
  });
}
