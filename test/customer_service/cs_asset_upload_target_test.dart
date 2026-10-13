import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_asset_put_transport.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/config/const.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/service/storage.dart';

class TargetAdapter implements HttpClientAdapter {
  final methods = <String>[];
  final requests = <RequestOptions>[];
  bool bound = false;
  bool invalidAck = false;
  int? rejectedAt;
  bool disconnectConfirm = false;
  bool putCancelled = false;
  Map<String, dynamic> confirmOverrides = {};
  final uploadedBytes = <int>[];
  Completer<void>? putGate;
  final putEntered = Completer<void>();
  void Function(int)? afterResponse;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    requests.add(options);
    afterResponse?.call(requests.length);
    if (options.method == 'PUT' && stream != null) {
      await for (final chunk in stream) {
        uploadedBytes.addAll(chunk);
      }
      if (!putEntered.isCompleted) putEntered.complete();
      if (cancelFuture != null) {
        unawaited(cancelFuture.then((_) => putCancelled = true));
      }
      if (putGate != null) {
        await Future.any<void>([putGate!.future, ?cancelFuture]);
      }
    }
    if (disconnectConfirm && options.path.endsWith('/confirm')) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final rejected = requests.length == rejectedAt;
    return ResponseBody.fromString(
      jsonEncode({
        'code': rejected ? 410 : 0,
        'payload': rejected ? <String, dynamic>{} : _payload(options),
      }),
      rejected ? 410 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _payload(RequestOptions options) {
    if (bound && options.method == 'PUT') {
      return {
        'asset_id': '9',
        'status': 'pending_confirm',
        'object_hash': invalidAck ? 'invalid' : sha256.convert([65]).toString(),
        'size_bytes': 1,
        'mime': 'text/plain',
      };
    }
    if (bound && options.path.endsWith('/confirm')) {
      return {
        'asset_id': '9',
        'status': 'active',
        'object_hash': sha256.convert([65]).toString(),
        'mime': 'text/plain',
        'size_bytes': 1,
        'conversation_id': '3',
        ...confirmOverrides,
      };
    }
    final host = bound ? 'api.invalid' : 'outside.invalid';
    return {
      'asset_id': '9',
      'upload_ref': 'synthetic-ref',
      'upload': {
        'url':
            'https://$host/api/v1/enterprise/organizations/1/assets/presign?workspace_id=2&upload_ref=synthetic-ref',
      },
    };
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '7266418340025468999');
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'readAll') return <String, String>{};
            if (call.method == 'read' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              return token;
            }
            return null;
          },
        );
  });
  for (final phase in [
    CsAssetUploadStage.presigning,
    CsAssetUploadStage.confirming,
    CsAssetUploadStage.complete,
  ]) {
    for (final cancel in [true, false]) {
      test(
        'synchronous $phase callback cancel=$cancel blocks dispatch',
        () async {
          var current = true;
          final adapter = TargetAdapter()..bound = true;
          HttpClient.adapterForTest = adapter;
          addTearDown(() => HttpClient.adapterForTest = null);
          final enterprise = EnterpriseApi()
            ..dio.options.baseUrl = 'https://api.invalid';
          late CsAssetUploadOperation operation;
          operation = CsAssetUploadOperation(
            isCurrent: () => current,
            onChanged: () {
              if (operation.stage == phase) {
                if (cancel) {
                  operation.cancel();
                } else {
                  current = false;
                }
              }
            },
          );
          await expectLater(
            CsApi(
              assetApiFactory: () => enterprise,
              putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
            ).uploadEnterpriseAsset(
              '1',
              workspaceId: '2',
              conversationId: '3',
              mime: 'text/plain',
              bytes: Uint8List.fromList([65]),
              operation: operation,
            ),
            throwsA(isA<CsAssetOperationException>()),
          );
          expect(
            adapter.methods,
            phase == CsAssetUploadStage.presigning
                ? <String>[]
                : phase == CsAssetUploadStage.confirming
                ? ['POST', 'PUT']
                : ['POST', 'PUT', 'POST'],
          );
          expect(
            operation.requestStarted,
            phase != CsAssetUploadStage.presigning,
          );
          expect(
            operation.stage,
            phase == CsAssetUploadStage.presigning
                ? CsAssetUploadStage.cancelled
                : CsAssetUploadStage.unknown,
          );
        },
      );
    }
  }
  test('repeated cancel inside stage notification is idempotent', () async {
    var notifications = 0;
    final adapter = TargetAdapter()..bound = true;
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    final enterprise = EnterpriseApi()
      ..dio.options.baseUrl = 'https://api.invalid';
    late CsAssetUploadOperation operation;
    operation = CsAssetUploadOperation(
      onChanged: () {
        notifications++;
        operation.cancel();
      },
    );
    await expectLater(
      CsApi(
        assetApiFactory: () => enterprise,
        putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
      ).uploadEnterpriseAsset(
        '1',
        workspaceId: '2',
        conversationId: '3',
        mime: 'text/plain',
        bytes: Uint8List.fromList([65]),
        operation: operation,
      ),
      throwsA(isA<CsAssetOperationException>()),
    );
    expect(adapter.methods, isEmpty);
    expect(notifications, 2);
    expect(operation.requestStarted, isFalse);
    expect(operation.stage, CsAssetUploadStage.cancelled);
  });
  for (final invalid in [false, true]) {
    test(
      'public upload authenticates same presign and refuses wrong ack=$invalid',
      () async {
        final oldEnv = currentEnv;
        final adapter = TargetAdapter()
          ..bound = true
          ..invalidAck = invalid;
        HttpClient.adapterForTest = adapter;
        addTearDown(() {
          currentEnv = oldEnv;
          HttpClient.adapterForTest = null;
        });
        final enterprise = EnterpriseApi();
        enterprise.dio.options.baseUrl = 'https://api.invalid';
        final api = CsApi(
          assetApiFactory: () => enterprise,
          putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
        );
        api.dio.options.headers['authorization'] = 'must-not-inherit';
        final upload = api.uploadEnterpriseAsset(
          '1',
          workspaceId: '2',
          conversationId: '3',
          mime: 'text/plain',
          bytes: Uint8List.fromList([65]),
          fileName: 'synthetic.txt',
        );
        if (invalid) {
          await expectLater(upload, throwsA(isA<CsApiException>()));
          expect(adapter.methods, ['POST', 'PUT']);
        } else {
          final asset = await upload;
          expect(asset.id, '9');
          expect(adapter.methods, ['POST', 'PUT', 'POST']);
        }
        final auth = adapter.requests.first.headers['authorization'];
        expect(auth, isA<String>());
        expect(auth, isNot('must-not-inherit'));
        expect(adapter.requests[1].headers['authorization'], auth);
      },
    );
  }

  for (final boundary in [1, 2, 3]) {
    test('scope invalidated after phase $boundary stops next write', () async {
      var current = true;
      final adapter = TargetAdapter()..bound = true;
      adapter.afterResponse = (count) {
        if (count == boundary) current = false;
      };
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final enterprise = EnterpriseApi()
        ..dio.options.baseUrl = 'https://api.invalid';
      final api = CsApi(
        assetApiFactory: () => enterprise,
        putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
      );
      final operation = CsAssetUploadOperation(isCurrent: () => current);
      await expectLater(
        api.uploadEnterpriseAsset(
          '1',
          workspaceId: '2',
          conversationId: '3',
          mime: 'text/plain',
          bytes: Uint8List.fromList([65]),
          operation: operation,
        ),
        throwsA(isA<CsAssetOperationException>()),
      );
      expect(adapter.methods.length, boundary);
      expect(operation.canRetry, isFalse);
    });
  }
  for (final boundary in [0, 1, 2, 3]) {
    test(
      'cancel phase $boundary stops later requests without claiming rollback',
      () async {
        final operation = CsAssetUploadOperation();
        final adapter = TargetAdapter()..bound = true;
        if (boundary == 0) operation.cancel();
        adapter.afterResponse = (count) {
          if (count == boundary) operation.cancel();
        };
        HttpClient.adapterForTest = adapter;
        addTearDown(() => HttpClient.adapterForTest = null);
        final enterprise = EnterpriseApi()
          ..dio.options.baseUrl = 'https://api.invalid';
        final api = CsApi(
          assetApiFactory: () => enterprise,
          putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
        );
        await expectLater(
          api.uploadEnterpriseAsset(
            '1',
            workspaceId: '2',
            conversationId: '3',
            mime: 'text/plain',
            bytes: Uint8List.fromList([65]),
            operation: operation,
          ),
          throwsA(isA<CsAssetOperationException>()),
        );
        expect(adapter.methods.length, boundary);
        expect(
          operation.stage,
          boundary == 0
              ? CsAssetUploadStage.cancelled
              : CsAssetUploadStage.unknown,
        );
        expect(operation.canRetry, boundary == 0);
      },
    );
  }
  test('over server 25MiB limit sends zero presign', () async {
    final adapter = TargetAdapter()..bound = true;
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    await expectLater(
      CsApi().uploadEnterpriseAsset(
        '1',
        workspaceId: '2',
        conversationId: '3',
        mime: 'application/octet-stream',
        bytes: Uint8List(25 * 1024 * 1024 + 1),
        operation: CsAssetUploadOperation(),
      ),
      throwsA(isA<CsAssetOperationException>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test('expired PUT ticket is a definite rejection eligible for manual new operation', () async {
    final adapter = TargetAdapter()
      ..bound = true
      ..rejectedAt = 2;
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    final enterprise = EnterpriseApi()
      ..dio.options.baseUrl = 'https://api.invalid';
    final operation = CsAssetUploadOperation();
    final api = CsApi(
      assetApiFactory: () => enterprise,
      putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
    );
    await expectLater(
      api.uploadEnterpriseAsset(
        '1',
        workspaceId: '2',
        conversationId: '3',
        mime: 'text/plain',
        bytes: Uint8List.fromList([65]),
        operation: operation,
      ),
      throwsA(isA<CsAssetOperationException>()),
    );
    expect(adapter.methods, ['POST', 'PUT']);
    expect(operation.stage, CsAssetUploadStage.failed);
    expect(operation.canRetry, isTrue);
    operation.cancel();
    expect(operation.stage, CsAssetUploadStage.failed);
    expect(operation.canRetry, isTrue);
  });
  test('caller bytes are frozen before presign awaits', () async {
    final bytes = Uint8List.fromList([65]);
    final adapter = TargetAdapter()..bound = true;
    adapter.afterResponse = (count) {
      if (count == 1) bytes[0] = 66;
    };
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    final enterprise = EnterpriseApi()
      ..dio.options.baseUrl = 'https://api.invalid';
    final asset =
        await CsApi(
          assetApiFactory: () => enterprise,
          putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
        ).uploadEnterpriseAsset(
          '1',
          workspaceId: '2',
          conversationId: '3',
          mime: 'text/plain',
          bytes: bytes,
        );
    expect(asset.id, '9');
    expect(adapter.uploadedBytes, [65]);
  });
  test(
    'lost confirm response is unknown and never automatically repeated',
    () async {
      final adapter = TargetAdapter()
        ..bound = true
        ..disconnectConfirm = true;
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final enterprise = EnterpriseApi()
        ..dio.options.baseUrl = 'https://api.invalid';
      final operation = CsAssetUploadOperation();
      await expectLater(
        CsApi(
          assetApiFactory: () => enterprise,
          putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
        ).uploadEnterpriseAsset(
          '1',
          workspaceId: '2',
          conversationId: '3',
          mime: 'text/plain',
          bytes: Uint8List.fromList([65]),
          operation: operation,
        ),
        throwsA(isA<CsAssetOperationException>()),
      );
      expect(adapter.methods, ['POST', 'PUT', 'POST']);
      expect(operation.stage, CsAssetUploadStage.unknown);
      expect(operation.canRetry, isFalse);
    },
  );
  for (final wrong in [
    {'asset_id': '10'},
    {'conversation_id': '4'},
    {'status': 'pending_confirm'},
    {'mime': 'image/png'},
    {'size_bytes': 2},
    {'object_hash': '0' * 64},
  ]) {
    test(
      'wrong confirm binding never returns an asset for sending $wrong',
      () async {
        final adapter = TargetAdapter()
          ..bound = true
          ..confirmOverrides = wrong;
        HttpClient.adapterForTest = adapter;
        addTearDown(() => HttpClient.adapterForTest = null);
        final enterprise = EnterpriseApi()
          ..dio.options.baseUrl = 'https://api.invalid';
        final operation = CsAssetUploadOperation();
        await expectLater(
          CsApi(
            assetApiFactory: () => enterprise,
            putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
          ).uploadEnterpriseAsset(
            '1',
            workspaceId: '2',
            conversationId: '3',
            mime: 'text/plain',
            bytes: Uint8List.fromList([65]),
            operation: operation,
          ),
          throwsA(isA<CsAssetOperationException>()),
        );
        expect(adapter.methods, ['POST', 'PUT', 'POST']);
        expect(operation.stage, CsAssetUploadStage.unknown);
        expect(operation.canRetry, isFalse);
      },
    );
  }
  test(
    'dispose actively cancels an issued PUT and never starts confirm',
    () async {
      final adapter = TargetAdapter()
        ..bound = true
        ..putGate = Completer<void>();
      HttpClient.adapterForTest = adapter;
      addTearDown(() {
        HttpClient.adapterForTest = null;
        if (!adapter.putGate!.isCompleted) adapter.putGate!.complete();
      });
      final enterprise = EnterpriseApi()
        ..dio.options.baseUrl = 'https://api.invalid';
      final flow = CsSessionFlow(
        orgId: '1',
        workspaceId: '2',
        sessionId: '4',
        conversationId: '3',
        identityId: '6',
        csApi: CsApi(
          assetApiFactory: () => enterprise,
          putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
        ),
      );
      final pending = flow.uploadAsset(
        mime: 'text/plain',
        bytes: Uint8List.fromList([65]),
      );
      await adapter.putEntered.future.timeout(const Duration(seconds: 2));
      flow.dispose();
      expect(await pending.timeout(const Duration(seconds: 2)), isEmpty);
      expect(adapter.methods, ['POST', 'PUT']);
      expect(adapter.putCancelled, isTrue);
      expect(adapter.putGate!.isCompleted, isFalse);
      expect(flow.assetOperation!.stage, CsAssetUploadStage.unknown);
    },
  );
  test('unbound member target is refused before PUT or confirm', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final adapter = TargetAdapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() {
      HttpClient.adapterForTest = null;
    });
    var refused = false;
    try {
      await CsApi(
        putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
      ).uploadEnterpriseAsset(
        '1',
        workspaceId: '2',
        conversationId: '3',
        mime: 'text/plain',
        bytes: Uint8List.fromList([65]),
        fileName: 'synthetic.txt',
      );
    } on Object {
      refused = true;
    }
    expect(refused, isTrue);
    expect(adapter.methods, ['POST']);
  });
}
