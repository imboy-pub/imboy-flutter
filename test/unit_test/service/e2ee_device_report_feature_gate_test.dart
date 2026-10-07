import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_api.dart';

class _ReportAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'payload': {'other_device_count': 2},
      }),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ReportAdapter adapter;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'e2ee_private_key': 'synthetic-retained-private-key',
      'e2ee_public_key': 'synthetic-retained-public-key',
      'e2ee_key_id': 'synthetic-retained-key-id',
    });
    adapter = _ReportAdapter();
    HttpClient.adapterForTest = adapter;
    AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
  });

  tearDown(() async {
    HttpClient.adapterForTest = null;
    await AppFeatureRegistry.clear();
  });

  Future<E2EEReportResult> report() => E2EEApi().reportDeviceKey(
    deviceId: 'synthetic-device',
    deviceType: 'android',
    publicKey: 'synthetic-public-key',
    keyId: 'synthetic-key-id',
  );

  test(
    'disabled report has no HTTP request or successful recovery result',
    () async {
      final result = await report();
      expect(result.ok, isFalse);
      expect(result.hasOtherDevice, isFalse);
      expect(adapter.paths, isEmpty);
    },
  );

  test(
    'disabled regeneration preserves existing historical key material',
    () async {
      final before = await StorageSecureService.to.readAll();
      expect(await E2EEKeyService.regenerateAndReportDeviceKey(), isFalse);
      expect(await StorageSecureService.to.readAll(), before);
      expect(adapter.paths, isEmpty);
    },
  );

  test('enabled report retains successful device-count contract', () async {
    AppFeatureRegistry.replaceSnapshotForTest({'e2ee': true});
    final result = await report();
    expect(result.ok, isTrue);
    expect(result.otherDeviceCount, 2);
    expect(adapter.paths.single, contains('/e2ee/report_device_key'));
  });
}
