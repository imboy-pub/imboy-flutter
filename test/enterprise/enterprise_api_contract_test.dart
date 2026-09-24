/// APP-A03 — 企业 API 客户端契约单测（mock adapter）
///
/// 契约依据（plan §5.1 + amendment §2.1/2.5）：
/// - 路径严格 `/api/v1/enterprise/organizations/{orgId}/...`，
///   orgId 绑定进路径（EB-D03：organization_id 是资源 owner/租户条件）；
/// - ACK 为 delivery-only POST：只确认投递，无删除语义、无 DELETE 调用；
/// - 附件下载仅经企业 content 鉴权代理路径，客户端不接收/不拼接
///   presigned GET 参数（EB-D06）；
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

  group('APP-A03 企业 API 契约', () {
    test('businessIdentities：GET org 绑定路径，解析 TSID 为 string', () async {
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

      final identities = await api.businessIdentities(orgId);

      expectSingleRequest(
        adapter,
        method: 'GET',
        path: '/api/v1/enterprise/organizations/$orgId/business-identities',
      );
      expect(identities, hasLength(1));
      expect(identities.single.id, '7266418340025468931');
      expect(identities.single.organizationId, orgId);
    });

    test('messages：GET after_id 增量查询参数', () async {
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

      final messages = await api.messages(orgId, convId, afterId: '100');

      expectSingleRequest(
        adapter,
        method: 'GET',
        path:
            '/api/v1/enterprise/organizations/$orgId/conversations/$convId/messages',
        query: {'after_id': '100'},
      );
      expect(messages.single.id, '7266418340025468934');
    });

    test('sendMessage：POST 消息路径 + body 形状', () async {
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

      final sent = await api.sendMessage(orgId, convId, content: 'reply');

      expectSingleRequest(
        adapter,
        method: 'POST',
        path:
            '/api/v1/enterprise/organizations/$orgId/conversations/$convId/messages',
        body: {'content': 'reply'},
      );
      expect(sent.id, '7266418340025468934');
      expect(sent.senderType, EnterpriseSenderType.businessIdentity);
    });

    test('sendMessage 提交面键白名单（W2 新合同：禁止 key_ref，密文不上链提交面）', () async {
      // W2-APP 消费的合同（contracts-w2.md）：CS 访客发消息不再接受 key_ref
      // （提交即 422 unexpected_argument.key_ref）；profile PATCH 不再接受
      // profile_cipher/profile_key_version。客户端提交面必须保持
      // {content, asset_id?} 白名单——任何键漂移（如加回 key_ref）即回归。
      Future<Map<String, dynamic>?> captureBody({
        required String content,
        EntityId assetId = '',
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
        );
        expect(adapter.requests, hasLength(1));
        return Map<String, dynamic>.from(adapter.requests.single.$3 as Map);
      }

      // 分支一：纯文本（asset_id 留空不得出现在提交面）
      final bodyText = await captureBody(content: 'hi');
      expect(bodyText!.keys.toSet(), {'content'});

      // 分支二：带附件
      final bodyAsset = await captureBody(content: 'see file', assetId: 'a1');
      expect(bodyAsset!.keys.toSet(), {'content', 'asset_id'});

      // 显式负例（防回归钉死新合同）：两个分支的提交面都不得含
      // key_ref / profile_cipher / profile_key_version 或任何密文形键
      // （bodyText/bodyAsset 经上方断言后已被流分析提升为非空）
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

    test('ackDelivered：delivery-only POST，无 DELETE 语义', () async {
      final adapter = useAdapter(200, okEnvelope());
      final api = EnterpriseApi();

      await api.ackDelivered(orgId, convId, '7266418340025468934');

      expectSingleRequest(
        adapter,
        method: 'POST',
        path:
            '/api/v1/enterprise/organizations/$orgId/conversations/$convId/messages/7266418340025468934/ack',
      );
      // 反向防误读：ACK 不得产生任何 DELETE 请求（delivery-only，
      // canonical message 真源只在服务端，客户端亦不得本地删除——A02 已断言）
      expect(adapter.requests.every((r) => r.$1 != 'DELETE'), isTrue);
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
      var e401 = await _capture(() => api.businessIdentities(orgId));
      expect(e401, isA<EnterpriseApiException>());
      expect((e401! as EnterpriseApiException).isUnauthorized, isTrue);

      // 403 → isForbidden
      useAdapter(403, {'code': 403, 'msg': 'forbidden'});
      api = EnterpriseApi();
      var e403 = await _capture(() => api.businessIdentities(orgId));
      expect((e403! as EnterpriseApiException).isForbidden, isTrue);

      // 409 → isOffboardingRequired（envelope code 与 HTTP status 双通道）
      useAdapter(409, {'code': 409, 'msg': 'offboarding_required'});
      api = EnterpriseApi();
      var e409 = await _capture(() => api.businessIdentities(orgId));
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
