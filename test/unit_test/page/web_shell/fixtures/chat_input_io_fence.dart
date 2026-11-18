import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart' as product;
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'chat_input_platform_fence_stub.dart'
    if (dart.library.js_interop) 'chat_input_platform_fence_web.dart';

class _ContactDatabase extends Fake implements Database {
  @override
  bool get isOpen => true;
  @override
  Future<void> close() async {}
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table != 'contact') throw StateError('Unexpected test database table');
    // Avatar metadata is always present; even the old invalid-ID implementation
    // must not fall through from an empty DB row to ContactApi.syncByUid.
    return [
      {
        'peer_id': '990001',
        'nickname': 'Synthetic contact',
        'avatar': '',
        'account': '',
        'status': 1,
        'updated_at': 1,
      },
    ];
  }
}

class _DenyAdapter implements HttpClientAdapter {
  int denied = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    denied++;
    throw StateError('Composer test forbids product adapter dispatch');
  }

  @override
  void close({bool force = false}) {}
}

class ChatInputIoFence {
  final _adapter = _DenyAdapter();
  final _platform = ChatInputPlatformFence();
  HttpClientAdapter? _previous;
  void install() {
    _previous = product.HttpClient.adapterForTest;
    product.HttpClient.adapterForTest = _adapter;
    _platform.install();
    SqliteService.setInitializerForTest((_, _, _) async => _ContactDatabase());
    SqliteService.setDbForTest(_ContactDatabase());
  }

  void verifyAndRestore() {
    try {
      expect(
        _adapter.denied,
        0,
        reason: 'Caught HTTP errors must not hide attempted dispatch',
      );
      expect(
        _platform.denied,
        0,
        reason: 'Platform transport attempted product IO',
      );
    } finally {
      // Do not release the DB-open fence while callbacks can still be scheduled.
      SqliteService.setDbUnavailableForTest();
      SqliteService.setInitializerForTest(null);
      product.HttpClient.adapterForTest = _previous;
      _platform.restore();
    }
  }
}

void isolatedChatInputTestWidgets(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(
    description,
    (tester) => runInChatInputIoZone(() => callback(tester)),
  );
}
