import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_asset_put_transport.dart';

final data = Uint8List.fromList([65, 66]);
final digest = sha256.convert(data).toString();
const memberUrl =
    'https://api.invalid/api/v1/enterprise/organizations/1/assets/presign?workspace_id=2&upload_ref=synthetic-ref';

class PutAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object? result;
  bool fail = false;
  PutAdapter()
    : result = {
        'code': 0,
        'payload': {
          'asset_id': '9',
          'status': 'pending_confirm',
          'object_hash': digest,
          'size_bytes': 2,
          'mime': 'text/plain',
        },
      };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (fail) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> member(
  CsAssetPutTransport transport, {
  String url = memberUrl,
  String? authorization = 'synthetic-auth',
  String org = '1',
  String workspace = '2',
  String asset = '9',
}) => transport.putMember(
  url: url,
  apiOrigin: Uri.parse('https://api.invalid'),
  organizationId: org,
  workspaceId: workspace,
  uploadRef: 'synthetic-ref',
  assetId: asset,
  mime: 'text/plain',
  bytes: data,
  objectHash: digest,
  authenticatedHeaders: {
    'authorization': ?authorization,
    'cookie': 'must-not-copy',
    'x-unrelated': 'must-not-copy',
  },
);
void main() {
  for (final field in ['org', 'workspace', 'asset']) {
    test('signed64 overflow $field performs zero requests', () async {
      const overflow = '9223372036854775808';
      final adapter = PutAdapter();
      final transport = CsAssetPutTransport(adapter: adapter);
      await expectLater(
        member(
          transport,
          org: field == 'org' ? overflow : '1',
          workspace: field == 'workspace' ? overflow : '2',
          asset: field == 'asset' ? overflow : '9',
          url:
              'https://api.invalid/api/v1/enterprise/organizations/${field == 'org' ? overflow : '1'}/assets/presign?workspace_id=${field == 'workspace' ? overflow : '2'}&upload_ref=synthetic-ref',
        ),
        throwsA(isA<CsAssetPutException>()),
      );
      expect(adapter.requests, isEmpty);
      transport.close();
    });
  }

  test(
    'member carries only explicit presign authorization and byte header',
    () async {
      final adapter = PutAdapter(),
          transport = CsAssetPutTransport(adapter: adapter);
      await member(transport);
      final req = adapter.requests.single;
      expect(req.headers['authorization'], 'synthetic-auth');
      expect(
        req.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('cookie')),
      );
      expect(
        req.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-unrelated')),
      );
      expect(req.followRedirects, isFalse);
      expect(req.maxRedirects, 0);
      transport.close();
    },
  );
  for (final url in [
    memberUrl.replaceFirst('api.invalid', 'outside.invalid'),
    memberUrl.replaceFirst('/organizations/1/', '/organizations/8/'),
    memberUrl.replaceFirst('workspace_id=2', 'workspace_id=3'),
    '$memberUrl&workspace_id=2',
    '$memberUrl&extra=bad',
    '$memberUrl#bad',
    memberUrl.replaceFirst('https://', 'https://user@'),
    memberUrl.replaceFirst('/assets/presign', '/assets/confirm'),
    memberUrl.replaceFirst('synthetic-ref', 'other-ref'),
  ]) {
    test('unbound target refuses with zero request', () async {
      final adapter = PutAdapter(),
          transport = CsAssetPutTransport(adapter: adapter);
      await expectLater(
        member(transport, url: url),
        throwsA(isA<CsAssetPutException>()),
      );
      expect(adapter.requests, isEmpty);
      transport.close();
    });
  }
  test('missing member credential refuses before sending', () async {
    final adapter = PutAdapter(),
        transport = CsAssetPutTransport(adapter: adapter);
    await expectLater(
      member(transport, authorization: null),
      throwsA(isA<CsAssetPutException>()),
    );
    expect(adapter.requests, isEmpty);
    transport.close();
  });
  for (final payload in [
    {'code': 1},
    {
      'code': 0,
      'payload': {'asset_id': '8'},
    },
    {
      'code': 0,
      'payload': {
        'asset_id': '9',
        'status': 'pending_confirm',
        'object_hash': digest.replaceFirst('a', 'b'),
        'mime': 'text/plain',
        'size_bytes': 2,
      },
    },
  ]) {
    test('HTTP200 alone never proves member PUT accepted', () async {
      final adapter = PutAdapter()..result = payload;
      final transport = CsAssetPutTransport(adapter: adapter);
      await expectLater(member(transport), throwsA(isA<CsAssetPutException>()));
      expect(adapter.requests.length, 1);
      transport.close();
    });
  }
  for (final rawId in ['9223372036854775808', 9.0]) {
    test('invalid acknowledgement ID type or range is refused', () async {
      final adapter = PutAdapter();
      final result = adapter.result as Map;
      (result['payload'] as Map)['asset_id'] = rawId;
      final transport = CsAssetPutTransport(adapter: adapter);
      await expectLater(member(transport), throwsA(isA<CsAssetPutException>()));
      expect(adapter.requests.length, 1);
      transport.close();
    });
  }
  test('redirect and network failure never automatically retry', () async {
    final adapter = PutAdapter()..status = 302;
    final transport = CsAssetPutTransport(adapter: adapter);
    await expectLater(member(transport), throwsA(isA<CsAssetPutException>()));
    expect(adapter.requests.length, 1);
    adapter.fail = true;
    await expectLater(member(transport), throwsA(isA<CsAssetPutException>()));
    expect(adapter.requests.length, 2);
    transport.close();
  });
  test('explicit trusted object origin has no authentication and cannot target elsewhere', () async {
    final adapter = PutAdapter(),
        transport = CsAssetPutTransport(adapter: adapter);
    await transport.putObject(
      url: 'https://objects.invalid/owned',
      permittedOrigin: Uri.parse('https://objects.invalid'),
      bytes: data,
    );
    expect(
      adapter.requests.single.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
    await expectLater(
      transport.putObject(
        url: 'https://elsewhere.invalid/owned',
        permittedOrigin: Uri.parse('https://objects.invalid'),
        bytes: data,
      ),
      throwsA(isA<CsAssetPutException>()),
    );
    expect(adapter.requests.length, 1);
    transport.close();
  });
  test('pre-cancelled operation performs zero requests', () async {
    final adapter = PutAdapter(),
        transport = CsAssetPutTransport(adapter: adapter);
    final token = CancelToken()..cancel('synthetic cancellation');
    await expectLater(
      transport.putMember(
        url: memberUrl,
        apiOrigin: Uri.parse('https://api.invalid'),
        organizationId: '1',
        workspaceId: '2',
        uploadRef: 'synthetic-ref',
        assetId: '9',
        mime: 'text/plain',
        bytes: data,
        objectHash: digest,
        authenticatedHeaders: {'authorization': 'synthetic-auth'},
        cancelToken: token,
      ),
      throwsA(isA<CsAssetPutException>()),
    );
    expect(adapter.requests, isEmpty);
    transport.close();
  });
  test('mixed-case duplicate authorization is refused', () async {
    final adapter = PutAdapter(),
        transport = CsAssetPutTransport(adapter: adapter);
    await expectLater(
      transport.putMember(
        url: memberUrl,
        apiOrigin: Uri.parse('https://api.invalid'),
        organizationId: '1',
        workspaceId: '2',
        uploadRef: 'synthetic-ref',
        assetId: '9',
        mime: 'text/plain',
        bytes: data,
        objectHash: digest,
        authenticatedHeaders: {
          'authorization': 'synthetic-a',
          'Authorization': 'synthetic-b',
        },
      ),
      throwsA(isA<CsAssetPutException>()),
    );
    expect(adapter.requests, isEmpty);
    transport.close();
  });
  for (final status in [301, 201]) {
    test(
      'unexpected HTTP$status cannot prove member acknowledgement',
      () async {
        final adapter = PutAdapter()..status = status;
        final transport = CsAssetPutTransport(adapter: adapter);
        await expectLater(
          member(transport),
          throwsA(isA<CsAssetPutException>()),
        );
        expect(adapter.requests.length, 1);
        transport.close();
      },
    );
  }
}
