@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show serviceContainer;
import 'package:imboy/page/channel/channel_edit_avatar.dart';
import 'package:imboy/service/migrations/upgrade_edges_v33.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UploadPaths extends PathProviderPlatform {
  _UploadPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class _RejectRegister implements app_http.HttpClient {
  final bodies = <Map<String, dynamic>>[];
  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    dynamic options,
    dynamic cancelToken,
    dynamic onSendProgress,
    dynamic onReceiveProgress,
    dynamic httpTransformer,
  }) async {
    expect(uri, '/api/v1/attachment/direct/register');
    bodies.add(Map<String, dynamic>.from(data! as Map));
    return IMBoyHttpResponse.failure(
      errMsg: 'synthetic register unavailable',
      errCode: 503,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected upload network operation');
}

void main() {
  test('avatar registration binds actual channel; invalid IDs never read or upload', () async {
    await StorageService.to.setString(Keys.currentUid, 'uiux-channel-owner');
    final temp = await Directory.systemTemp.createTemp('channel-avatar-scope-');
    final file = File('${temp.path}/avatar.png');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      ),
    );
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final sql in kUpgradeEdgesV33.single.sql.split(';')) {
      if (sql.trim().isNotEmpty) await db.execute(sql);
    }
    SqliteService.setDbForTest(db);
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _UploadPaths(temp.path);
    final previousClient = serviceContainer.isRegistered<app_http.HttpClient>()
        ? serviceContainer.get<app_http.HttpClient>()
        : null;
    final client = _RejectRegister();
    serviceContainer.put<app_http.HttpClient>(client);
    final container = ProviderContainer();
    addTearDown(() async {
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
      PathProviderPlatform.instance = previousPaths;
      if (previousClient != null) {
        serviceContainer.put<app_http.HttpClient>(previousClient);
      } else {
        serviceContainer.clear();
      }
      await StorageService.to.remove(Keys.currentUid);
      await temp.delete(recursive: true);
    });
    final upload = container.read(channelEditAvatarUploadProvider);
    for (final id in ['', '0', '-1', 'owned-alias', '9223372036854775808']) {
      expect(await upload(File('${temp.path}/missing.png'), id), isNull);
    }
    expect(client.bodies, isEmpty);
    expect(await upload(file, '9007199254740993'), isNull);
    expect(client.bodies, hasLength(1));
    expect(client.bodies.single['scope'], 'channel');
    expect(client.bodies.single['scope_ref'], '9007199254740993');
    expect(client.bodies.single['purpose'], 'attachment');
  });
}
