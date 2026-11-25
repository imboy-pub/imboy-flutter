// offline 游标恢复/重放隔离共享 fixture（拆分自 offline_cursor_recovery_test.dart，
// file_size_ratchet <800 行约束）。
//
// OfflineFixtureAdapter：镜像服务端 created_at>=cursor 且未 ACK 谓词；
// ScriptedPullAdapter：脚本化多页响应；fl04* helper：帧编码/测试库打开/token 安装。
// 本文件不含用例。

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// Mirrors the server's created_at >= cursor AND not-yet-ACKed predicate.
class OfflineFixtureAdapter implements HttpClientAdapter {
  final acknowledged = <String>{};
  final cursors = <int>[];
  bool repaired = false;

  List<Map<String, dynamic>> get frames => [
    {
      'msg_id': 'cursor-poison',
      'type': 'S2C',
      'created_at': 1000,
      'from': '200',
      'to': '100',
      'action': repaired ? 'future-compatible-control' : 'c2c_del_everyone',
      'payload': {'old_msg_id': ''},
    },
    for (final entry in [
      ('cursor-good-first', 2000),
      ('cursor-good-later', 3000),
    ])
      {
        'msg_id': entry.$1,
        'type': 'S2C',
        'created_at': entry.$2,
        'from': '200',
        'to': '100',
        'action': 'future-compatible-control',
        'payload': <String, dynamic>{},
      },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    late Map<String, dynamic> payload;
    if (options.path == API.msgOffline) {
      expect(options.queryParameters['did'], 'synthetic-cursor-device');
      final cursor = options.queryParameters['s2c_last_msg_at'] as int? ?? 0;
      cursors.add(cursor);
      final pending = frames
          .where(
            (frame) =>
                (frame['created_at'] as int) >= cursor &&
                !acknowledged.contains(frame['msg_id']),
          )
          .toList();
      final page = pending.take(2).toList();
      payload = {
        's2c': {
          'list': page,
          'has_more': pending.length > page.length,
          if (page.isNotEmpty) 'next_last_msg_at': page.last['created_at'],
        },
      };
    } else if (options.path == API.msgOfflineAck) {
      final data = options.data is Map
          ? options.data as Map
          : jsonDecode(options.data as String) as Map;
      expect(data['did'], 'synthetic-cursor-device');
      expect(data['type'], 'S2C');
      acknowledged.addAll((data['msg_ids'] as List).cast<String>());
      payload = {};
    } else {
      throw StateError('unexpected synthetic endpoint: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'payload': payload}),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 可编程离线服务（FL-04:LOCAL:01~:06 负例组）：按
/// 「服务端 created_at >= cursor AND 未按设备 ACK」谓词出页；
/// ACK 可注入失败（响应丢失/连接断）；毒帧行为与主例同构（repaired 修复）。
class ScriptedPullAdapter implements HttpClientAdapter {
  ScriptedPullAdapter({
    required this.frames,
    required this.sectionKey,
    this.pageSize = 2,
    this.poisonIds = const {},
    this.ackFailures = 0,
    this.alwaysHasMore = false,
  });

  final List<Map<String, dynamic>> frames;
  final String sectionKey; // 'c2c' | 'c2g' | 's2c'
  final int pageSize;
  final Set<String> poisonIds;
  int ackFailures;

  /// 病态服务模式：无论谓词结果恒回 has_more=true（无进展分页负例）。
  final bool alwaysHasMore;

  final acknowledged = <String>{};
  final cursors = <int>[];
  final ackBodies = <Map<String, dynamic>>[];
  final deliveredCounts = <String, int>{};
  final queryLog = <Map<String, dynamic>>[];
  bool repaired = false;

  /// 每次出页前回调（切账号/断线注入点）。
  void Function()? beforePage;

  Map<String, dynamic> _servedFrame(Map<String, dynamic> frame) {
    final id = frame['msg_id'] as String;
    final poison = poisonIds.contains(id) && !repaired;
    return {
      ...frame,
      'action': poison ? 'c2c_del_everyone' : 'future-compatible-control',
      'payload': {'old_msg_id': ''},
    };
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    late Map<String, dynamic> payload;
    if (options.path == API.msgOffline) {
      beforePage?.call();
      final query = Map<String, dynamic>.from(options.queryParameters);
      queryLog.add(query);
      final cursor = query['${sectionKey}_last_msg_at'] as int? ?? 0;
      cursors.add(cursor);
      final pending = frames
          .where(
            (frame) =>
                (frame['created_at'] as int) >= cursor &&
                !acknowledged.contains(frame['msg_id']),
          )
          .toList();
      final page = pending.take(pageSize).map(_servedFrame).toList();
      for (final frame in page) {
        final id = frame['msg_id'] as String;
        deliveredCounts[id] = (deliveredCounts[id] ?? 0) + 1;
      }
      payload = {
        sectionKey: {
          'list': page,
          'has_more': alwaysHasMore || pending.length > page.length,
          if (page.isNotEmpty)
            'next_last_msg_at': page
                .map((f) => f['created_at'] as int)
                .reduce((a, b) => a > b ? a : b),
          if (sectionKey == 'c2g')
            'next_cursor': 'tok-${cursors.length}-${page.length}',
        },
      };
    } else if (options.path == API.msgOfflineAck) {
      if (ackFailures > 0) {
        ackFailures--;
        throw DioException(
          requestOptions: options,
          error: StateError('synthetic ack connection lost'),
        );
      }
      final data = options.data is Map
          ? options.data as Map
          : jsonDecode(options.data as String) as Map;
      ackBodies.add(Map<String, dynamic>.from(data));
      acknowledged.addAll((data['msg_ids'] as List).cast<String>());
      payload = {};
    } else {
      throw StateError('unexpected synthetic endpoint: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'payload': payload}),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> fl04C2cFrame(String id, int createdAt) => {
  'msg_id': id,
  'type': 'C2C',
  'created_at': createdAt,
  'from': '200',
  'to': '100',
  'msg_type': 'text',
  'payload': {'text': 'frame-$id'},
};

Map<String, dynamic> fl04S2cFrame(String id, int createdAt) => {
  'msg_id': id,
  'type': 'S2C',
  'created_at': createdAt,
  'from': '200',
  'to': '100',
};

Future<Database> fl04OpenDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return openFixtureDatabaseAtVersion(version: kInventoryCurrentDbVersion);
}

Future<void> fl04InstallToken(int uid) async {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  FlutterSecureStorage.setMockInitialValues({
    'secure_token':
        '${encode({'alg': 'none'})}.${encode({'exp': 4102444800, 'uid': uid})}.test',
  });
}
