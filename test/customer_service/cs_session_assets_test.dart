import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

class DeferredAssetApi extends CsApi {
  final uploaded = Completer<EnterpriseAsset>();
  final downloaded = Completer<CsVerifiedAssetContent>();
  int downloadCalls = 0;
  @override
  Future<CsVerifiedAssetContent> fetchAssetContent(
    String org,
    String id, {
    required String workspaceId,
  }) {
    downloadCalls++;
    return downloaded.future;
  }

  @override
  Future<EnterpriseAsset> uploadEnterpriseAsset(
    String orgId, {
    required String workspaceId,
    required String conversationId,
    required String mime,
    required Uint8List bytes,
    String fileName = '',
    CsAssetUploadOperation? operation,
  }) => uploaded.future;
}

void main() {
  CsSessionFlow flow(DeferredAssetApi api, {bool Function()? current}) =>
      CsSessionFlow(
        orgId: '1',
        sessionId: '3',
        identityId: '6',
        workspaceId: '2',
        conversationId: '4',
        csApi: api,
        scopeCurrent: current,
      );
  CsVerifiedAssetContent content() => CsVerifiedAssetContent.fromResponse(
    Response(
      requestOptions: RequestOptions(path: '/synthetic'),
      statusCode: 200,
      data: Uint8List.fromList([65]),
      headers: Headers.fromMap({
        'x-asset-id': ['9'],
        'x-asset-sha256': [
          sha256.convert([65]).toString(),
        ],
        'content-length': ['1'],
        'content-type': ['text/plain'],
      }),
    ),
    '9',
  );
  test('late download cannot return bytes into another auth scope', () async {
    var current = true;
    final api = DeferredAssetApi();
    final active = flow(api, current: () => current);
    final pending = active.fetchAssetBytes('9');
    await Future<void>.delayed(Duration.zero);
    current = false;
    api.downloaded.complete(content());
    expect(await pending, isNull);
    active.dispose();
  });
  for (final status in [401, 403]) {
    test('current download $status revokes displayed read facts', () async {
      final api = DeferredAssetApi(), active = flow(api);
      active.messageReadAt = {'8': DateTime.utc(2026)};
      final pending = active.fetchAssetBytes('9');
      await Future<void>.delayed(Duration.zero);
      api.downloaded.completeError(
        EnterpriseApiException(status, 'synthetic refusal'),
      );
      expect(await pending, isNull);
      expect(active.readRevoked, isTrue);
      expect(active.messageReadAt, isEmpty);
      expect(active.messageAssets, isEmpty);
      active.dispose();
    });
    test('old download $status cannot revoke new scope', () async {
      var current = true;
      final api = DeferredAssetApi(),
          active = flow(api, current: () => current);
      final pending = active.fetchAssetBytes('9');
      await Future<void>.delayed(Duration.zero);
      current = false;
      api.downloaded.completeError(
        EnterpriseApiException(status, 'synthetic refusal'),
      );
      expect(await pending, isNull);
      expect(active.readRevoked, isFalse);
      active.dispose();
    });
  }
  test('closed session still permits authorized verified download', () async {
    final api = DeferredAssetApi(), active = flow(api);
    active.machine.markClosed();
    final pending = active.fetchAssetBytes('9');
    await Future<void>.delayed(Duration.zero);
    api.downloaded.complete(content());
    expect(await pending, [65]);
    active.dispose();
  });
  test(
    'send and another upload cannot interleave with active upload',
    () async {
      final api = DeferredAssetApi(), active = flow(api);
      final pending = active.uploadAsset(
        mime: 'text/plain',
        bytes: Uint8List.fromList([65]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await active.send('must not dispatch'), isFalse);
      expect(
        await active.uploadAsset(
          mime: 'text/plain',
          bytes: Uint8List.fromList([65]),
        ),
        isEmpty,
      );
      api.uploaded.complete(
        const EnterpriseAsset(id: '9', organizationId: '1'),
      );
      expect(await pending, '9');
      active.dispose();
    },
  );

  test(
    'late confirmed attachment cannot become new scope send input',
    () async {
      var current = true;
      final api = DeferredAssetApi();
      final flow = CsSessionFlow(
        orgId: '1',
        sessionId: '3',
        identityId: '6',
        workspaceId: '2',
        conversationId: '4',
        csApi: api,
        scopeCurrent: () => current,
      );
      final pending = flow.uploadAsset(
        mime: 'text/plain',
        bytes: Uint8List.fromList([65]),
      );
      await Future<void>.delayed(Duration.zero);
      current = false;
      api.uploaded.complete(
        const EnterpriseAsset(id: '9', organizationId: '1'),
      );
      expect(await pending, isEmpty);
      flow.dispose();
    },
  );
}
