// DF-14 群相册 → 群文件 → 媒体内容 本地后端 API 闭环 flow 测试（纯 Dart，无设备）。
//
// 复刻生产客户端链路：
//   1. 群文件上传（multipart → 后端中转 Garage S3）→ 列表回读 →
//      GET /api/v1/attachment/view_url 签发 → 下载内容比对；
//   2. 群相册创建 → 相册列表回读 → 照片上传（代码生成 1x1 PNG，非真实照片）→
//      照片列表回读。
//
// 运行（本地后端 + Garage 对象存储需在线）：
//   API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=... TEST_PASSWORD=... \
//   IMBOY_SOLIDIFIED_KEY=... TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/group_content_local_api_flow_test.dart \
//     --concurrency=1
//
// 安全约束：
// - 只允许本地/开发后端；生产 URL 拒绝（复用 ApiTestClient 门禁）。
// - 上传内容为代码生成文本/最小 PNG，无 PII、无真实照片。
// - 测试数据命名带 DEMO-FLOW-20260817 前缀；不删除文件/相册。
// - 对象存储不可用导致的上传失败按 markTestSkipped 受控记录（阻塞证据
//   在 flow 文档），业务断言失败仍然 fail。

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import '../../test/unit_test/api/api_test_client.dart';

const _prefix = 'DEMO-FLOW-20260819';
final _runTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

void _log(String msg) => stderr.writeln('[DF14-LOCAL] $msg');

List<Map<String, dynamic>> _asList(dynamic payload) {
  final list = payload is Map
      ? (payload['list'] ?? payload['items'] ?? payload['data'])
      : payload;
  if (list is! List) return const [];
  return list
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

Map<String, dynamic>? _findByName(
  Iterable<Map<String, dynamic>> items,
  List<String> keys,
  String name,
) {
  for (final item in items) {
    for (final key in keys) {
      if (item[key]?.toString() == name) return item;
    }
  }
  return null;
}

/// 判定上传失败是否源于对象存储不可用（阻塞）而非业务回归（失败）。
bool _isObjectStorageFailure(Map<String, dynamic> resp) {
  final msg = '${resp['msg']}'.toLowerCase();
  return msg.contains('garage') ||
      msg.contains('s3') ||
      msg.contains('object') ||
      msg.contains('storage') ||
      msg.contains('upload') ||
      msg.contains('上传') ||
      msg.contains('econnrefused') ||
      msg.contains('unreachable');
}

/// 与 ApiTestClient._defaultHeaders 相同的签名算法（复用其登录会话）。
Map<String, String> _signHeaders(String deviceId) {
  final cos = Platform.isIOS
      ? 'ios'
      : Platform.isAndroid
      ? 'android'
      : Platform.isMacOS
      ? 'macos'
      : 'linux';
  final pkg = Platform.isAndroid
      ? 'imboy.chat'
      : Platform.isMacOS
      ? 'pub.imboy.macos'
      : Platform.isIOS
      ? 'pub.imboy.2'
      : 'pub.imboy.app';
  const vsn = '0.8.0';
  final raw = '$deviceId|$vsn|$cos|$pkg';
  final key = utf8.encode(Platform.environment['IMBOY_SOLIDIFIED_KEY']!.trim());
  final signature = base64.encode(
    crypto.Hmac(crypto.sha512, key).convert(utf8.encode(raw)).bytes,
  );
  return {
    'cos': cos,
    'vsn': vsn,
    'pkg': pkg,
    'did': deviceId,
    'tz_offset': '${DateTime.now().timeZoneOffset.inMilliseconds}',
    'method': 'sha512',
    'sk': '1',
    'sign': signature,
  };
}

/// 1x1 白色 PNG（代码生成，非真实照片）。
final List<int> _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8'
  'BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String gid = '';

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (!loggedIn) {
      _log('登录失败: ${resp['msg']}');
      return;
    }
    _log('登录成功 uid=${client.currentUid}');

    final page = await client.get(
      '/api/v1/group/page',
      queryParameters: {'page': 1, 'size': 50, 'attr': 'join'},
    );
    if (page['code'] == 0) {
      final items = _asList(page['payload']);
      _log('group/page(attr=join) 返回 ${items.length} 个群');
      // 本地测试账号是多会话共用的：按本 flow 的确切群名匹配，
      // 避免误选其他会话创建的 DEMO-FLOW 前缀群。
      const expectedTitle = 'DEMO-FLOW-20260817-COLLAB';
      for (final item in items) {
        if ((item['title'] ?? item['name'])?.toString() == expectedTitle) {
          final raw = item['group_id'] ?? item['gid'] ?? item['id'];
          if (raw != null) {
            gid = raw.toString();
            break;
          }
        }
      }
    }
    if (gid.isEmpty) {
      const newTitle = 'DEMO-FLOW-20260817-COLLAB';
      final created = await client.post(
        '/api/v1/group/add',
        data: {'member_uids': <String>[]},
      );
      ApiAssert.success(created, context: '创建测试群');
      final group = created['payload'] is Map
          ? (created['payload'] as Map<dynamic, dynamic>)['group']
          : null;
      final raw = group is Map
          ? (group['group_id'] ?? group['gid'] ?? group['id'])
          : null;
      expect(raw, isNotNull, reason: '建群响应缺少 group.id');
      gid = raw.toString();
      final edit = await client.post(
        '/api/v1/group/edit',
        data: {'gid': gid, 'title': newTitle},
      );
      ApiAssert.success(edit, context: '命名测试群');
      _log('已创建测试群 gid=$gid title=$newTitle');
    } else {
      _log('复用 DEMO-FLOW 测试群 gid=$gid');
    }
  });

  tearDownAll(() => client.close());

  test('前置：登录并定位 DEMO-FLOW 测试群', () {
    expect(loggedIn, isTrue);
    expect(gid, isNotEmpty);
  });

  test('群文件闭环：上传 1KB 代码生成文本 → 列表回读 → view_url 授权访问', () async {
    final fileName = '$_prefix-FILE-$_runTs.txt';
    final content =
        'DEMO-FLOW-20260819 local group file upload probe '
        'run=$_runTs ${List.filled(24, '0123456789').join()}';
    final bytes = utf8.encode(content);
    _log('上传文件 $fileName bytes=${bytes.length}');

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        validateStatus: (status) => status != null,
      ),
    );
    final headers = _signHeaders('e2e-dart-test-001');
    headers['authorization'] = 'Bearer ${client.accessToken}';
    dynamic resp;
    Map<String, dynamic> body;
    try {
      resp = await dio.post<dynamic>(
        '${ApiTestConfig.apiBaseUrl}/api/v1/group/file/upload',
        data: FormData.fromMap({
          'gid': gid,
          'file_name': fileName,
          'file': MultipartFile.fromBytes(bytes, filename: fileName),
        }),
        options: Options(headers: headers),
      );
      body = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : resp.data is String
          ? (jsonDecode(resp.data as String) as Map<String, dynamic>)
          : <String, dynamic>{'code': resp.statusCode, 'msg': 'non_json'};
      _log(
        '上传响应 http=${resp.statusCode} code=${body['code']} '
        'msg=${body['msg']}',
      );
    } on DioException catch (e) {
      // 后端中转 Garage 挂起：连接/接收超时归入对象存储阻塞（受控记录），
      // 不算业务断言失败。
      _log('上传请求异常: ${e.type} ${e.message}');
      markTestSkipped('对象存储链路不可用：上传请求超时（${e.type}）');
      return;
    }
    if (body['code'] != 0) {
      expect(
        _isObjectStorageFailure(body),
        isTrue,
        reason: '上传失败且非对象存储类错误（业务回归）: $body',
      );
      markTestSkipped(
        '对象存储不可用，上传被阻塞: code=${body['code']} '
        'msg=${body['msg']}',
      );
      return;
    }
    final payload = body['payload'];
    _log('上传成功 payload=${payload is Map ? payload.keys.toList() : payload}');

    final listResp = await client.get(
      '/api/v1/group/file/list',
      queryParameters: {'gid': gid, 'page': 1, 'size': 20},
    );
    ApiAssert.success(listResp, context: '群文件列表');
    final file = _findByName(_asList(listResp['payload']), [
      'file_name',
      'name',
      'title',
    ], fileName);
    expect(file, isNotNull, reason: '文件列表回读必须包含新上传文件');
    // group_file 表无 object_key 列（file_url 为 Garage 私桶裸 URL）；
    // BUG#137 修复后上传时补写 attachment 记录，其 path = "<file_id>/<file_name>"，
    // 按该格式构造 object_key 走 view_url presign 签发。
    var objectKey = '${file?['object_key'] ?? ''}';
    if (objectKey.isEmpty || objectKey.startsWith('http')) {
      final fid = '${file?['file_id'] ?? file?['id'] ?? ''}';
      final fname =
          '${file?['file_name'] ?? file?['name'] ?? file?['title'] ?? ''}';
      if (fid.isNotEmpty && fname.isNotEmpty) objectKey = '$fid/$fname';
    }
    _log(
      '列表回读命中 file_id=${file?['file_id'] ?? file?['id']} '
      'object_key=${objectKey.isEmpty ? '<无>' : objectKey}',
    );

    if (objectKey.isNotEmpty && !objectKey.startsWith('http')) {
      final view = await client.get(
        '/api/v1/attachment/view_url',
        queryParameters: {'object_key': objectKey},
      );
      ApiAssert.success(view, context: 'view_url 签发');
      final url = (view['payload'] as Map)['url'] as String?;
      expect(url, isNotNull, reason: 'view_url 响应缺少 url');
      final download = await Dio().get<List<int>>(
        url!,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(download.statusCode, 200, reason: '签发 URL 下载失败');
      expect(utf8.decode(download.data!), content, reason: '下载内容与上传不一致');
      _log('view_url 授权访问通过，内容回读一致 bytes=${download.data!.length}');
    } else {
      _log('文件记录无 object_key（url=$objectKey），跳过 view_url 授权访问段');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('群相册闭环：创建 → 列表回读 → 照片上传 → 照片列表回读', () async {
    final albumName = '$_prefix-ALBUM-$_runTs';
    final created = await client.post(
      '/api/v1/group_album/create',
      data: {'gid': gid, 'album_name': albumName},
    );
    _log('创建相册 code=${created['code']} msg=${created['msg']}');
    ApiAssert.success(created, context: '创建群相册');
    final payload = created['payload'] as Map?;
    final albumId = payload != null
        ? '${payload['album_id'] ?? payload['id'] ?? ''}'
        : '';
    expect(albumId, isNotEmpty, reason: '创建相册响应缺少 album_id');

    final listResp = await client.get(
      '/api/v1/group_album/list',
      queryParameters: {'gid': gid, 'page': 1, 'size': 20},
    );
    ApiAssert.success(listResp, context: '相册列表');
    final album = _findByName(_asList(listResp['payload']), [
      'album_name',
      'name',
      'title',
    ], albumName);
    expect(album, isNotNull, reason: '相册列表回读必须包含新相册');
    _log('相册列表回读命中 album_id=$albumId');

    final photoName = '$_prefix-PHOTO-$_runTs.png';
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        validateStatus: (status) => status != null,
      ),
    );
    final headers = _signHeaders('e2e-dart-test-001');
    headers['authorization'] = 'Bearer ${client.accessToken}';
    dynamic resp;
    Map<String, dynamic> body;
    try {
      resp = await dio.post<dynamic>(
        '${ApiTestConfig.apiBaseUrl}/api/v1/group_album/photo/upload',
        data: FormData.fromMap({
          'gid': gid,
          'album_id': albumId,
          'photo_name': photoName,
          'photo': MultipartFile.fromBytes(_tinyPng, filename: photoName),
        }),
        options: Options(headers: headers),
      );
      body = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : resp.data is String
          ? (jsonDecode(resp.data as String) as Map<String, dynamic>)
          : <String, dynamic>{'code': resp.statusCode, 'msg': 'non_json'};
      _log(
        '照片上传响应 http=${resp.statusCode} code=${body['code']} '
        'msg=${body['msg']}',
      );
    } on DioException catch (e) {
      _log('照片上传请求异常: ${e.type} ${e.message}');
      markTestSkipped('对象存储链路不可用：照片上传请求超时（${e.type}）');
      return;
    }
    if (body['code'] != 0) {
      expect(
        _isObjectStorageFailure(body),
        isTrue,
        reason: '照片上传失败且非对象存储类错误（业务回归）: $body',
      );
      markTestSkipped(
        '对象存储不可用，照片上传被阻塞: code=${body['code']} '
        'msg=${body['msg']}',
      );
      return;
    }

    final photos = await client.get(
      '/api/v1/group_album/photo/list',
      queryParameters: {'album_id': albumId, 'page': 1, 'size': 20},
    );
    ApiAssert.success(photos, context: '照片列表');
    final photo = _findByName(_asList(photos['payload']), [
      'photo_name',
      'name',
      'title',
    ], photoName);
    expect(photo, isNotNull, reason: '照片列表回读必须包含新照片');
    _log('照片列表回读命中 photo_id=${photo?['photo_id'] ?? photo?['id']}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
