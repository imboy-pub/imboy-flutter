import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/app_core/feature_flags/runtime_feature_recovery.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/storage.dart';

Map<String, bool> flags(bool baseline) => {
  for (final key in compiledProductFeatures) key: false,
  'core': true,
  'moment': baseline,
  'location': baseline,
};

Map<String, dynamic> manifest() => {
  'manifest_hash': productFeatureManifestHash,
  'manifest_schema_version': productFeatureSchemaVersion,
  'compiled_features': compiledProductFeatures,
  'app_entries': ['moment_tab'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClient client;
  setUp(() async {
    RuntimeFeatureRecovery.dispose();
    SharedPreferences.setMockInitialValues({Keys.currentUid: 'A'});
    await StorageService.init();
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    FlutterSecureStorage.setMockInitialValues({
      'secure_token':
          '${encode({'alg': 'none'})}.${encode({'exp': 4102444800, 'uid': 'A'})}.synthetic',
    });
    AppFeatureRegistry.bindScope(endpoint: Env().apiBaseUrl, uid: 'A');
    await AppFeatureRegistry.clear();
    EncryptionModeService.debugFetcher = null;
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
    client = HttpClient();
    serviceContainer.put<HttpClient>(client);
  });
  tearDown(() {
    RuntimeFeatureRecovery.dispose();
    client.dio.close(force: true);
    serviceContainer.clear();
  });

  test(
    'partial real HTTP flags cannot finish recovery; full phase1 flags can',
    () async {
      var complete = false;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            final path = request.uri.path;
            final data = path.endsWith('/manifest')
                ? manifest()
                : {
                    'code': 0,
                    'msg': 'success',
                    'payload': path.endsWith('/features')
                        ? (complete
                              ? flags(true)
                              : {'moment': true, 'project': false})
                        : {
                            'capabilities': {
                              'storage_mode': 'archived',
                              'e2ee_mode': 'disabled',
                            },
                          },
                  };
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: data,
              ),
            );
          },
        ),
      );
      expect(await RuntimeFeatureRecovery.refreshNow(), isFalse);
      expect(AppFeatureRegistry.isEnabled('moment'), isTrue);
      expect(AppFeatureRegistry.isComplete, isFalse);
      expect(EncryptionModeService.isInitialized, isTrue);
      complete = true;
      expect(await RuntimeFeatureRecovery.refreshNow(), isTrue);
      expect(AppFeatureRegistry.isEnabled('location'), isTrue);
      expect(AppFeatureRegistry.isEnabled('project'), isFalse);
      expect(AppFeatureRegistry.isComplete, isTrue);
    },
  );

  test('old A HTTP cannot continue into B policy or replace B flags', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var featureRequests = 0;
    var policyRequests = 0;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          final path = request.uri.path;
          final old = path.endsWith('/features') && ++featureRequests == 1;
          if (old) {
            entered.complete();
            await release.future;
          }
          if (path.endsWith('/policy')) policyRequests++;
          final data = path.endsWith('/manifest')
              ? manifest()
              : {
                  'code': 0,
                  'msg': 'success',
                  'payload': path.endsWith('/features')
                      ? flags(old)
                      : {
                          'capabilities': {
                            'storage_mode': 'archived',
                            'e2ee_mode': 'disabled',
                          },
                        },
                };
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              statusCode: 200,
              data: data,
            ),
          );
        },
      ),
    );
    final old = RuntimeFeatureRecovery.refreshNow();
    await entered.future;
    await StorageService.to.setString(Keys.currentUid, 'B');
    AppFeatureRegistry.bindScope(endpoint: Env().apiBaseUrl, uid: 'B');
    expect(await RuntimeFeatureRecovery.refreshNow(), isTrue);
    release.complete();
    expect(await old, isFalse);
    expect(AppFeatureRegistry.isEnabled('moment'), isFalse);
    expect(policyRequests, 1);
  });
  test(
    'manifest event while real HTTP policy waits closes revoked entry',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var enabled = true;
      var policyCount = 0;
      var featureCount = 0;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            final path = request.uri.path;
            if (path.endsWith('/features')) featureCount++;
            if (path.endsWith('/policy') && ++policyCount == 1) {
              entered.complete();
              await release.future;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: path.endsWith('/manifest')
                    ? manifest()
                    : {
                        'code': 0,
                        'msg': 'success',
                        'payload': path.endsWith('/features')
                            ? {...flags(false), 'project': enabled}
                            : {
                                'capabilities': {
                                  'storage_mode': 'archived',
                                  'e2ee_mode': 'disabled',
                                },
                              },
                      },
              ),
            );
          },
        ),
      );
      final first = RuntimeFeatureRecovery.refreshNow();
      await entered.future;
      expect(AppFeatureRegistry.isEnabled('project'), isTrue);
      enabled = false;
      for (var i = 0; i < 100; i++) {
        RuntimeFeatureRecovery.refreshNow();
      }
      release.complete();
      expect(await first, isTrue);
      expect(AppFeatureRegistry.isEnabled('project'), isFalse);
      expect(featureCount, 2);
      expect(policyCount, 2);
    },
  );
}
