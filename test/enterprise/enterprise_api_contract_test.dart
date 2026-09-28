/// APP-A03 — 企业 API 客户端契约单测（mock adapter）
///
/// 契约依据（plan §5.1 + amendment §2.1/2.5 + PR-W2-C01 八项对齐）：
/// - 路径严格 `/api/v1/enterprise/organizations/{orgId}/...`，
///   orgId 绑定进路径（EB-D03：organization_id 是资源 owner/租户条件）；
/// - 组织列表走组织域 `GET /api/v1/organizations/mine`（enterprise 面
///   无 bare organizations 路由——V1.2 D1）；
/// - 面级 workspace 门（eb_tenant_handler → eb_enterprise_http
///   workspace_id/2）：GET 查询串 / 写正文必带 workspace_id，缺一即 422，
///   SDK 前置同码同语义镜像（V1.2 D3a/c/d/e）；
/// - sendMessage 提交面 = 动作表 append_message 白名单
///   {client_msg_id, sender_type, body, asset_ids?}（V1.2 D2）；
/// - conversations 路径唯一动作 open_conversation 是 POST：GET 列表
///   前置镜像 405，网络能力由 openConversation 提供（V1.2 D4）；
/// - ACK 为 delivery-only POST：只确认投递，无删除语义、无 DELETE 调用；
/// - 附件下载仅经企业 content 鉴权代理路径（查询串带 workspace_id），
///   客户端不接收/不拼接 presigned GET 参数（EB-D06）；
/// - 错误映射：401 未授权 / 403 禁止 / 409 offboarding_required。
///
/// 测试原理（镜像 fail_open_contract_test）：注入"记录请求 + 恒返指定
/// 响应"的 HttpClientAdapter；adapterForTest 只对**之后构造**的实例生效，
/// 故每个用例先换 adapter、用例内现建 EnterpriseApi、用例结束恢复。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/enterprise/public.dart';
import 'package:imboy/service/storage.dart';

const String orgId = '7266418340025468930';
const String convId = '7266418340025468933';
const String workspaceId = '7266418340025468931';

/// 记录请求并恒返指定 statusCode + JSON envelope 的出口。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  /// 每次请求的 (method, path, data, queryParameters)
  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

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

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 401 分支会触发 auth-expired → quitLogin → StorageService 写清理，
    // 未初始化会抛异常成为未处理异步错误
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  /// 换出口 + 用例结束恢复；返回记录型 adapter 供断言。
  _RecordingAdapter useAdapter(int statusCode, Map<String, dynamic> body) {
    final adapter = _RecordingAdapter(statusCode, body);
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    return adapter;
  }

  void expectSingleRequest(
    _RecordingAdapter adapter, {
    required String method,
    required String path,
    Object? body,
    Map<dynamic, dynamic> query = const {},
  }) {
    expect(adapter.requests, hasLength(1));
    final req = adapter.requests.single;
    expect(req.$1, method);
    expect(req.$2, path);
    if (body != null) {
      expect(req.$3, body);
    }
    expect(req.$4, equals(query));
  }

  group('APP-A03 企业 API 契约（PR-W2-C01 对齐后）', () {
    test(
      'myOrganizations：组织域 GET /api/v1/organizations/mine（V1.2 D1）',
      () async {
        final adapter = useAdapter(
          200,
          okEnvelope(
            payload: {
              'list': [
                {
                  'id': 7266418340025468930,
                  'name': '示例企业',
                  'owner_id': 7266418340025468901,
                  'status': 'active',
                },
              ],
              'count': 1,
            },
          ),
        );
        final api = EnterpriseApi();

        final orgs = await api.myOrganizations();

        // 契约：enterprise 面 bare organizations 端点不存在（必 404），
        // 组织列表由组织域 /api/v1/organizations/mine 提供。
        expectSingleRequest(
          adapter,
          method: 'GET',
          path: '/api/v1/organizations/mine',
        );
        expect(orgs, hasLength(1));
        expect(orgs.single.id, orgId);
        expect(orgs.single.name, '示例企业');
      },
    );

    test(
      'businessIdentities：GET org 绑定路径 + workspace_id 门（F-LAY-10）',
      () async {
        final adapter = useAdapter(
          200,
          okEnvelope(
            payload: {
              'list': [
                {
                  'id': 7266418340025468931,
                  'organization_id': 7266418340025468930,
                  'display_name': '客服甲',
                  'function_key': 'customer_service',
                  'status': 'active',
                },
              ],
            },
          ),
        );
        final api = EnterpriseApi();

        final identities = await api.businessIdentities(
          orgId,
          workspaceId: workspaceId,
        );

        expectSingleRequest(
          adapter,
          method: 'GET',
          path: '/api/v1/enterprise/organizations/$orgId/business-identities',
          query: {'workspace_id': workspaceId},
        );
        expect(identities, hasLength(1));
        expect(identities.single.id, '7266418340025468931');
        expect(identities.single.organizationId, orgId);

        // 面级门镜像：缺 workspace_id 前置 422，不发网络请求。
        final gateAdapter = useAdapter(
          200,
          okEnvelope(payload: <String, dynamic>{'list': <dynamic>[]}),
        );
        final gateApi = EnterpriseApi();
        final e = await _capture(() => gateApi.businessIdentities(orgId));
        expect((e! as EnterpriseApiException).code, 422);
        expect((e as EnterpriseApiException).message, 'missing_workspace_id');
        expect(gateAdapter.requests, isEmpty, reason: '门在前置层拦截，不发必败请求');
      },
    );

    test('messages：GET workspace_id 门 + after_id/limit 完整键集分页（V1.2 D3c）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'list': [
              {
                'id': 7266418340025468934,
                'conversation_id': 7266418340025468933,
                'organization_id': 7266418340025468930,
                'sender_type': 'contact',
                'sender_contact_id': 7266418340025468932,
                'content': 'hello',
                'created_at': '1789000000000',
              },
            ],
          },
        ),
      );
      final api = EnterpriseApi();

      final messages = await api.messages(
        orgId,
        convId,
        afterId: '100',
        workspaceId: workspaceId,
        limit: 50,
      );

      expectSingleRequest(
        adapter,
        method: 'GET',
        path:
            '/api/v1/enterprise/organizations/$orgId/conversations/$convId/messages',
        query: {'workspace_id': workspaceId, 'after_id': '100', 'limit': 50},
      );
      expect(messages.single.id, '7266418340025468934');

      // 首拉（无游标/无 limit）：仍必带 workspace_id，分页键缺省不携带。
      final firstAdapter = useAdapter(
        200,
        okEnvelope(payload: <String, dynamic>{'list': <dynamic>[]}),
      );
      final firstApi = EnterpriseApi();
      await firstApi.messages(orgId, convId, workspaceId: workspaceId);
      expectSingleRequest(
        firstAdapter,
        method: 'GET',
        path:
            '/api/v1/enterprise/organizations/$orgId/conversations/$convId/messages',
        query: {'workspace_id': workspaceId},
      );

      // 门镜像：缺 workspace_id 前置 422。
      final e = await _capture(() => EnterpriseApi().messages(orgId, convId));
      expect((e! as EnterpriseApiException).code, 422);
    });

    test('contacts：GET workspace_id 门（V1.2 D3a）+ 可选分页键', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(payload: <String, dynamic>{'list': <dynamic>[]}),
      );
      final api = EnterpriseApi();

      await api.contacts(
        orgId,
        workspaceId: workspaceId,
        afterId: '200',
        limit: 20,
      );

      expectSingleRequest(
        adapter,
        method: 'GET',
        path: '/api/v1/enterprise/organizations/$orgId/contacts',
        query: {'workspace_id': workspaceId, 'after_id': '200', 'limit': 20},
      );

      // 门镜像：缺 workspace_id 前置 422（后端真 HTTP a04 实证同码）。
      final e = await _capture(() => EnterpriseApi().contacts(orgId));
      expect((e! as EnterpriseApiException).code, 422);
      expect((e as EnterpriseApiException).message, 'missing_workspace_id');
    });

    test(
      'conversations：GET 列表前置镜像 405；openConversation 是唯一网络形状（V1.2 D4）',
      () async {
        // 后端该路径唯一动作 open_conversation（POST）；GET 由后端 405 拒绝
        // （eb_route_contract_tests a03_405 真 HTTP 守护）。SDK 前置同码同语义。
        final adapter = useAdapter(
          200,
          okEnvelope(payload: <String, dynamic>{'list': <dynamic>[]}),
        );
        final api = EnterpriseApi();
        final e = await _capture(() => api.conversations(orgId));
        expect((e! as EnterpriseApiException).code, 405);
        expect(adapter.requests, isEmpty, reason: '不发必败 GET');

        // POST 正形状：contact_id + business_identity_id（动作表 required）
        // + workspace_id（面级门，正文）。
        final postAdapter = useAdapter(
          200,
          okEnvelope(
            payload: {
              'id': 7266418340025468933,
              'organization_id': 7266418340025468930,
              'contact_id': 7266418340025468932,
              'business_identity_id': 7266418340025468931,
              'updated_at': '1789000000000',
            },
          ),
        );
        // adapterForTest 只对之后构造的实例生效（confirm 用例同款注释）：
        // 换出口后必须用新实例发 POST。
        final postApi = EnterpriseApi();
        final conv = await postApi.openConversation(
          orgId,
          workspaceId: workspaceId,
          contactId: '7266418340025468932',
          businessIdentityId: '7266418340025468931',
        );
        expectSingleRequest(
          postAdapter,
          method: 'POST',
          path: '/api/v1/enterprise/organizations/$orgId/conversations',
          body: {
            'workspace_id': workspaceId,
            'contact_id': '7266418340025468932',
            'business_identity_id': '7266418340025468931',
          },
        );
        expect(conv.id, '7266418340025468933');
      },
    );

    test('sendMessage：POST 消息路径 + append_message 白名单形状（V1.2 D2）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'id': 7266418340025468934,
            'conversation_id': 7266418340025468933,
            'organization_id': 7266418340025468930,
            'sender_type': 'business_identity',
            'sender_business_identity_id': 7266418340025468931,
            'sender_business_identity_name': '客服甲',
            'content': 'reply',
            'created_at': '1789000000001',
          },
        ),
      );
      final api = EnterpriseApi();

      final sent = await api.sendMessage(
        orgId,
        convId,
        content: 'reply',
        clientMsgId: 'cmid-1',
      );

      expectSingleRequest(
        adapter,
        method: 'POST',
        path:
            '/api/v1/enterprise/organizations/$orgId/conversations/$convId/messages',
        body: {
          'client_msg_id': 'cmid-1',
          'sender_type': 'business_identity',
          'body': 'reply',
        },
      );
      expect(sent.id, '7266418340025468934');
      expect(sent.senderType, EnterpriseSenderType.businessIdentity);
    });

    test('sendMessage 提交面键白名单（W2 新合同 + PR-W2-C01 D2 形状）', () async {
      // 动作表 append_message 白名单：{client_msg_id, sender_type, body,
      // asset_ids?}——旧键形 {content, asset_id} 是表外键（服务端忽略），
      // 已废。任何密文形键（key_ref / *_cipher / *_key）不得回归。
      Future<Map<String, dynamic>> captureBody({
        required String content,
        EntityId assetId = '',
        String clientMsgId = '',
      }) async {
        final adapter = useAdapter(
          200,
          okEnvelope(
            payload: {
              'id': 7266418340025468934,
              'conversation_id': 7266418340025468933,
              'organization_id': 7266418340025468930,
              'sender_type': 'business_identity',
              'content': content,
              'created_at': '1789000000002',
            },
          ),
        );
        final api = EnterpriseApi();
        await api.sendMessage(
          orgId,
          convId,
          content: content,
          assetId: assetId,
          clientMsgId: clientMsgId,
        );
        expect(adapter.requests, hasLength(1));
        return Map<String, dynamic>.from(adapter.requests.single.$3 as Map);
      }

      // 分支一：显式 client_msg_id 的纯文本（asset_ids 留空不得出现）。
      final bodyText = await captureBody(content: 'hi', clientMsgId: 'cmid-2');
      expect(bodyText['client_msg_id'], 'cmid-2');
      expect(bodyText['sender_type'], 'business_identity');
      expect(bodyText['body'], 'hi');
      expect(bodyText.containsKey('asset_ids'), isFalse);
      expect(
        bodyText.containsKey('content'),
        isFalse,
        reason: '旧表外键 content 不得回归',
      );

      // 分支二：client_msg_id 缺省 → SDK 自动生成（幂等键客户端职责）。
      final bodyGen = await captureBody(content: 'hi');
      expect(
        (bodyGen['client_msg_id'] as String).isNotEmpty,
        isTrue,
        reason: '后端 required：缺省必须由 SDK 生成而非缺键',
      );

      // 分支三：带附件（动作表 asset_ids 是 TSID string 数组/list 传输形态）。
      final bodyAsset = await captureBody(
        content: 'see file',
        assetId: 'a1',
        clientMsgId: 'cmid-3',
      );
      expect(bodyAsset['asset_ids'], equals(['a1']));
      expect(
        bodyAsset.containsKey('asset_id'),
        isFalse,
        reason: '旧单键 asset_id 是表外键，不得回归',
      );

      // 显式负例（防回归钉死新合同）：任何密文形键不得出现。
      for (final body in [bodyText, bodyAsset]) {
        expect(body.containsKey('key_ref'), isFalse);
        expect(body.containsKey('profile_cipher'), isFalse);
        expect(body.containsKey('profile_key_version'), isFalse);
        expect(
          body.keys.where((k) => k.endsWith('_cipher') || k.endsWith('_key')),
          isEmpty,
        );
      }
    });

    test('ackDelivered：workspace_id 门 + recipient_ref 必填（V1.2 D3d）', () async {
      final adapter = useAdapter(200, okEnvelope());
      final api = EnterpriseApi();

      await api.ackDelivered(
        orgId,
        convId,
        '7266418340025468934',
        workspaceId: workspaceId,
        recipientRef: 'contact:7266418340025468932',
        deviceId: 'dev-1',
      );

      expectSingleRequest(
        adapter,
        method: 'POST',
        path:
            '/api/v1/enterprise/organizations/$orgId/conversations/$convId/messages/7266418340025468934/ack',
        body: {
          'workspace_id': workspaceId,
          'recipient_ref': 'contact:7266418340025468932',
          'device_id': 'dev-1',
        },
      );
      // 反向防误读：ACK 不得产生任何 DELETE 请求（delivery-only，
      // canonical message 真源只在服务端，客户端亦不得本地删除——A02 已断言）
      expect(adapter.requests.every((r) => r.$1 != 'DELETE'), isTrue);

      // 门镜像：缺 workspace_id / recipient_ref 均前置 422，不发网络请求。
      final gateAdapter = useAdapter(200, okEnvelope());
      final gateApi = EnterpriseApi();
      final eWs = await _capture(
        () => gateApi.ackDelivered(
          orgId,
          convId,
          '7266418340025468934',
          recipientRef: 'r1',
        ),
      );
      expect((eWs! as EnterpriseApiException).code, 422);
      final eRef = await _capture(
        () => gateApi.ackDelivered(
          orgId,
          convId,
          '7266418340025468934',
          workspaceId: workspaceId,
        ),
      );
      expect((eRef! as EnterpriseApiException).code, 422);
      expect((eRef as EnterpriseApiException).message, 'missing_recipient_ref');
      expect(gateAdapter.requests, isEmpty);
    });

    test('fetchAssetContent：workspace_id 门（V1.2 D3e）', () async {
      // bytes 版：透传 transformer 出口（非 JSON envelope 由断言侧简化为
      // JSON亦可——这里只断言请求形状）。
      final adapter = useAdapter(200, okEnvelope(payload: {'text': 'preview'}));
      final api = EnterpriseApi();

      await api.fetchAssetContentText(
        orgId,
        '7266418340025468935',
        workspaceId: workspaceId,
      );

      expectSingleRequest(
        adapter,
        method: 'GET',
        path:
            '/api/v1/enterprise/organizations/$orgId/assets/7266418340025468935/content',
        query: {'workspace_id': workspaceId},
      );

      // 门镜像：bytes 版与 text 版同门（fetchAssetContentText 同形状）。
      final gateAdapter = useAdapter(200, okEnvelope(payload: {'text': ''}));
      final gateApi = EnterpriseApi();
      final eText = await _capture(
        () => gateApi.fetchAssetContentText(orgId, '7266418340025468935'),
      );
      expect((eText! as EnterpriseApiException).code, 422);
      final eBytes = await _capture(
        () => gateApi.fetchAssetContentBytes(orgId, '7266418340025468935'),
      );
      expect((eBytes! as EnterpriseApiException).code, 422);
      expect(gateAdapter.requests, isEmpty);
    });

    test('presign/confirm：冻结契约请求体（CSX-01）+ 嵌套 upload 投影解析', () async {
      // CSX-01 冻结响应（eb_asset_app:presign_view）：asset_id + upload_ref
      // + 嵌套 upload{method, token, url?...}；企业面 url 恒缺省。
      final presignAdapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'asset_id': 7266418340025468935,
            'upload_ref': 'opaque-upload-ref',
            'object_hash': 'a'.padRight(64, 'a'),
            'mime': 'text/plain',
            'size_bytes': 42,
            'file_name': 'note.txt',
            'retain_until': null,
            'expires_at': 1789000100,
            'upload': {
              'method': 'PUT',
              'token': 'opaque-upload-ref',
              'expires_at': 1789000100,
              'adapter': 'local_private_object_store',
              'rule': 'opaque_token_no_url_no_object_key',
              // widget 代理面才补 url；这里给出以验证嵌套解析路径。
              'url': 'https://upload.example.internal/put?ref=abc',
            },
          },
        ),
      );
      final api = EnterpriseApi();

      final presign = await api.presignAsset(
        orgId,
        workspaceId: '7266418340025468931',
        conversationId: '7266418340025468933',
        mime: 'text/plain',
        sizeBytes: 42,
        objectHash: 'a'.padRight(64, 'a'),
        fileName: 'note.txt',
      );

      // 冻结请求体键白名单：旧键形 {file_name, mime, size}（缺
      // conversation_id/size_bytes/object_hash/workspace_id）必 422。
      expectSingleRequest(
        presignAdapter,
        method: 'POST',
        path: '/api/v1/enterprise/organizations/$orgId/assets/presign',
        body: {
          'workspace_id': '7266418340025468931',
          'conversation_id': '7266418340025468933',
          'mime': 'text/plain',
          'size_bytes': 42,
          'object_hash': 'a'.padRight(64, 'a'),
          'file_name': 'note.txt',
        },
      );
      expect(presign.assetId, '7266418340025468935');
      expect(presign.uploadRef, 'opaque-upload-ref');
      expect(presign.uploadUrl, 'https://upload.example.internal/put?ref=abc');
      expect(presign.hasUploadTarget, isTrue);

      final confirmAdapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            // public_asset_view：主键投影为 asset_id。
            'asset_id': 7266418340025468935,
            'status': 'active',
            'object_hash': 'a'.padRight(64, 'a'),
            'mime': 'text/plain',
            'size_bytes': 42,
            'file_name': 'note.txt',
            'hold_count': 0,
          },
        ),
      );
      // adapterForTest 只对之后构造的实例生效（同 billing 测试注释）：
      // confirm 必须用新实例，验证 confirm 是独立的重新鉴权请求
      final confirmApi = EnterpriseApi();

      final asset = await confirmApi.confirmAsset(
        orgId,
        workspaceId: '7266418340025468931',
        uploadRef: presign.uploadRef,
      );

      // confirm 是独立的重新鉴权 POST（EB-D06）；入参 upload_ref（非 asset_id）。
      expectSingleRequest(
        confirmAdapter,
        method: 'POST',
        path: '/api/v1/enterprise/organizations/$orgId/assets/confirm',
        body: {
          'workspace_id': '7266418340025468931',
          'upload_ref': 'opaque-upload-ref',
        },
      );
      expect(asset.id, '7266418340025468935');
      expect(asset.isPending, isFalse, reason: 'confirm 回显 status=active');
      expect(asset.size, 42);
    });

    test('presign 嵌套 upload 无 url（企业面合同形状）→ hasUploadTarget=false', () async {
      useAdapter(
        200,
        okEnvelope(
          payload: {
            'asset_id': 7266418340025468935,
            'upload_ref': 'opaque-upload-ref',
            'expires_at': 1789000100,
            'upload': {
              'method': 'PUT',
              'token': 'opaque-upload-ref',
              'adapter': 'local_private_object_store',
              'rule': 'opaque_token_no_url_no_object_key',
            },
          },
        ),
      );
      final api = EnterpriseApi();

      final presign = await api.presignAsset(
        orgId,
        workspaceId: '7266418340025468931',
        conversationId: '7266418340025468933',
        mime: 'text/plain',
        sizeBytes: 42,
        objectHash: 'a'.padRight(64, 'a'),
      );

      expect(presign.uploadUrl, isEmpty);
      expect(presign.hasUploadTarget, isFalse, reason: 'fail-closed：不自造端点');
    });

    test('附件 URL：仅经企业 content 鉴权代理，无 presigned 参数', () {
      final api = EnterpriseApi();

      final path = api.assetContentPath(orgId, '7266418340025468935');

      expect(
        path,
        '/api/v1/enterprise/organizations/$orgId/assets/7266418340025468935/content',
      );
      // 安全负例（EB-D06）：客户端不拼接 object key / storage endpoint /
      // presigned GET 参数
      expect(path.contains('X-Amz'), isFalse);
      expect(path.contains('token='), isFalse);
      expect(path.contains('sign='), isFalse);
      expect(path.contains('http'), isFalse);
    });

    test('错误映射：401/403/409(offboarding_required)', () async {
      // 401 → isUnauthorized
      useAdapter(401, {'code': 401, 'msg': 'unauthorized'});
      var api = EnterpriseApi();
      var e401 = await _capture(
        () => api.businessIdentities(orgId, workspaceId: workspaceId),
      );
      expect(e401, isA<EnterpriseApiException>());
      expect((e401! as EnterpriseApiException).isUnauthorized, isTrue);

      // 403 → isForbidden
      useAdapter(403, {'code': 403, 'msg': 'forbidden'});
      api = EnterpriseApi();
      var e403 = await _capture(
        () => api.businessIdentities(orgId, workspaceId: workspaceId),
      );
      expect((e403! as EnterpriseApiException).isForbidden, isTrue);

      // 409 → isOffboardingRequired（envelope code 与 HTTP status 双通道）
      useAdapter(409, {'code': 409, 'msg': 'offboarding_required'});
      api = EnterpriseApi();
      var e409 = await _capture(
        () => api.businessIdentities(orgId, workspaceId: workspaceId),
      );
      expect((e409! as EnterpriseApiException).isOffboardingRequired, isTrue);
    });
  });
}

/// 捕获业务异常（fail-closed 契约：失败必须抛而非空兜底）
Future<Object?> _capture(Future<Object?> Function() fn) async {
  try {
    final r = await fn();
    return StateError('expected throw, got $r');
  } on Object catch (e) {
    return e;
  }
}
