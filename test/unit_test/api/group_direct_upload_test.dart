import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:imboy/store/api/group_album_api.dart';
import 'package:imboy/store/api/group_file_api.dart';

mixin _RecordingMethods {
  final methods = <String>[];
  IMBoyHttpResponse response(String method, String path, dynamic data) {
    methods.add('$method $path');
    if (path.endsWith('/register')) {
      return IMBoyHttpResponse.success({
        'object_key': 'group/3001/photo',
        'state': 'CONFIRMED',
      });
    }
    if (path.endsWith('/status') && method == 'GET') {
      return IMBoyHttpResponse.success({
        'state': 'CONFIRMED',
        'expected': {
          'sha256': crypto.sha256.convert([1, 2, 3]).toString(),
          'size_bytes': 3,
          'mime': 'image/png',
        },
      });
    }
    throw StateError('unexpected $method $path');
  }
}

class _FileMethodApi extends GroupFileApi with _RecordingMethods {
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    dynamic options,
    dynamic cancelToken,
    dynamic onReceiveProgress,
    dynamic httpTransformer,
  }) async => response('GET', uri, queryParameters);
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
  }) async => response('POST', uri, data);
}

class _AlbumMethodApi extends GroupAlbumApi with _RecordingMethods {
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    dynamic options,
    dynamic cancelToken,
    dynamic onReceiveProgress,
    dynamic httpTransformer,
  }) async => response('GET', uri, queryParameters);
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
  }) async => response('POST', uri, data);
}

/// V3-12 群文件/群相册 direct 化（Lane B3）定向测试：不触网，全 seam 注入。
///
/// 合同锚点（backend 只读核对）：
///   * group/file/bind：{gid,file_name,file_type,object_key,file_size,file_md5}
///     ——file_md5 必空串；file_type 必与 declare mime 逐字一致；file_size
///     必与 confirmed size 一致；跨群 bind → cross_subject（HTTP 403 信封）。
///   * group_album/photo/bind_batch：{gid,items:[{album_id,photo_name,
///     photo_size,mime_type,sha256,object_key}]} → {results:[{object_key,
///     status,photo?,reason?}]}，逐项结果、部分失败继续、重复 bind 幂等。
///   * direct 会话：register(scope=group,scope_ref=gid)→declare→grant→
///     s3_put PUT→finalize(CONFIRMED)。
void main() {
  test('默认 HTTP：群文件和相册恢复均用 GET status', () async {
    final dir = await Directory.systemTemp.createTemp('group-status-test');
    try {
      final file = await File('${dir.path}/a.png').writeAsBytes([1, 2, 3]);
      final fileApi = _FileMethodApi();
      final fileResult = await fileApi.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'a.png',
        mime: 'image/png',
        clientUploadId: 'f0e0d0c0-b0a0-4908-8877-665544332211',
        bindFn: (_) async => IMBoyHttpResponse.success({'file_id': 'ok'}),
      );
      expect(fileResult?['file_id'], 'ok');
      expect(fileApi.methods, [
        'POST /api/v1/attachment/direct/register',
        'GET /api/v1/attachment/direct/status',
      ]);
      final albumApi = _AlbumMethodApi();
      final outcomes = await albumApi.uploadPhotosDirect(
        groupId: '3001',
        albumId: 'album1',
        items: [
          GroupAlbumUploadItem(
            file: file,
            photoName: 'a.png',
            clientUploadId: 'f0e0d0c0-b0a0-4908-8877-665544332211',
          ),
        ],
        bindBatchFn: (_) async => IMBoyHttpResponse.success({
          'results': [
            {
              'object_key': 'group/3001/photo',
              'status': 'ok',
              'photo': {'photo_id': 'ok'},
            },
          ],
        }),
      );
      expect(outcomes.single.ok, isTrue);
      expect(albumApi.methods, [
        'POST /api/v1/attachment/direct/register',
        'GET /api/v1/attachment/direct/status',
      ]);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('v3-group-direct-test');
  });

  tearDownAll(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  File writeFile(String name, List<int> bytes) {
    final File f = File('${tmp.path}/$name');
    f.writeAsBytesSync(bytes);
    return f;
  }

  IMBoyHttpResponse ok(Map<String, dynamic> payload) =>
      IMBoyHttpResponse.success(payload);

  IMBoyHttpResponse grantPayload(String url, int attemptId) =>
      ok(<String, dynamic>{
        'state': 'GRANTED',
        'object_key': url,
        'attempt_id': attemptId,
        'grant': <String, dynamic>{
          'transport': 's3_put',
          'url': url,
          'method': 'PUT',
          'required_headers': <dynamic>[
            <dynamic>['Content-Type', 'application/octet-stream'],
            <dynamic>['x-amz-checksum-sha256', 'YQ=='],
          ],
          'expires_in': 3600,
        },
      });

  /// direct 会话 fake：register 幂等（同 client_upload_id + 同声明返回同
  /// object_key，与后端 fn_dv1_register 语义一致）；[override] 返回非 null
  /// 时替换默认响应（模拟 finalize 拒绝等）。
  DirectSessionFn directSession({
    required void Function(String action, Map<String, dynamic> body) onRequest,
    required String Function(String filename) keyOf,
    IMBoyHttpResponse? Function(String action, Map<String, dynamic> body)?
    override,
  }) {
    return (String path, {Map<String, dynamic>? body}) async {
      final String action = path.split('/').last;
      final Map<String, dynamic> b = body ?? <String, dynamic>{};
      onRequest(action, b);
      final IMBoyHttpResponse? overridden = override?.call(action, b);
      if (overridden != null) return overridden;
      switch (action) {
        case 'register':
          return ok(<String, dynamic>{
            'object_key': keyOf('${b['filename']}'),
            'state': 'RESERVED',
          });
        case 'declare':
          return ok(<String, dynamic>{
            'object_key': b['object_key'],
            'state': 'DECLARED',
          });
        case 'grant':
        case 'renew':
          return grantPayload('https://s3.example/${b['object_key']}', 1);
        case 'finalize':
          return ok(<String, dynamic>{
            'state': 'CONFIRMED',
            'attempt_id': b['attempt_id'],
            'object_key': b['object_key'],
          });
      }
      throw StateError('unexpected action $action');
    };
  }

  group('GroupFileApi.uploadFileDirect（群文件单文件 direct+bind）', () {
    final GroupFileApi api = GroupFileApi();

    test('成功旅程：direct 全链 CONFIRMED 后 JSON bind，body 合同逐字对齐', () async {
      final File file = writeFile('a.pdf', <int>[1, 2, 3]);
      final List<Map<String, dynamic>> bindBodies = <Map<String, dynamic>>[];
      final List<String> actions = <String>[];

      final Map<String, dynamic>? result = await api.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'a.pdf',
        mime: 'application/pdf',
        clientUploadId: '0aaaaaaa-bbbb-4ccc-8ddd-0123456789ab',
        sessionFn: directSession(
          keyOf: (String f) => 'u1/group/3001/$f',
          onRequest: (String a, Map<String, dynamic> b) => actions.add(a),
        ),
        putFn: (String url, File f, int length, Map<String, String> h) async {},
        bindFn: (Map<String, dynamic> body) async {
          bindBodies.add(body);
          return ok(<String, dynamic>{'file_id': 'file_tsid_1'});
        },
      );

      expect(result?['file_id'], 'file_tsid_1');
      expect(actions, <String>['register', 'declare', 'grant', 'finalize']);
      expect(bindBodies, hasLength(1));
      final Map<String, dynamic> body = bindBodies.single;
      expect(body['gid'], '3001');
      expect(body['file_name'], 'a.pdf');
      expect(body['file_type'], 'application/pdf');
      expect(body['object_key'], 'u1/group/3001/a.pdf');
      expect(body['file_size'], 3);
      // backend validate_bind_metadata：非空 file_md5 必被拒（unverifiable_file_md5）
      expect(body['file_md5'], '');
    });

    test('已确认会话恢复只绑定原文件，变更文件不得绑定', () async {
      final file = writeFile('resume.pdf', <int>[1, 2, 3]);
      final digest = await sha256OfFile(file);
      var binds = 0;
      var puts = 0;
      final actions = <String>[];
      final session = directSession(
        keyOf: (_) => 'u1/group/3001/resume.pdf',
        onRequest: (action, _) => actions.add(action),
        override: (action, _) {
          if (action == 'register') {
            return ok({
              'object_key': 'u1/group/3001/resume.pdf',
              'state': 'CONFIRMED',
            });
          }
          if (action == 'status') {
            return ok({
              'state': 'CONFIRMED',
              'expected': {
                'sha256': digest,
                'size_bytes': '3',
                'mime': 'application/pdf',
              },
            });
          }
          return null;
        },
      );
      Future<Map<String, dynamic>?> upload() => api.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'resume.pdf',
        mime: 'application/pdf',
        clientUploadId: '0aaaaaaa-bbbb-4ccc-8ddd-0123456789ab',
        sessionFn: session,
        putFn: (_, _, _, _) async {
          puts++;
        },
        bindFn: (_) async {
          binds++;
          return ok({'file_id': 'existing'});
        },
      );
      expect((await upload())?['file_id'], 'existing');
      expect(actions, ['register', 'status']);
      expect(puts, 0);
      expect(binds, 1);
      file.writeAsBytesSync([3, 2, 1]);
      await expectLater(upload(), throwsStateError);
      expect(binds, 1);
      expect(puts, 0);
    });

    test('register 带 scope=group/scope_ref=gid/client_upload_id', () async {
      final File file = writeFile('scope.txt', <int>[7]);
      final List<Map<String, dynamic>> registers = <Map<String, dynamic>>[];
      await api.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'scope.txt',
        mime: 'text/plain',
        clientUploadId: '0aaaaaaa-bbbb-4ccc-8ddd-0123456789ab',
        sessionFn: directSession(
          keyOf: (String f) => 'u1/group/3001/$f',
          onRequest: (String a, Map<String, dynamic> b) {
            if (a == 'register') registers.add(b);
          },
        ),
        putFn: (String url, File f, int l, Map<String, String> h) async {},
        bindFn: (Map<String, dynamic> b) async =>
            ok(<String, dynamic>{'file_id': 'x'}),
      );
      expect(registers.single['scope'], 'group');
      expect(registers.single['scope_ref'], '3001');
      expect(
        registers.single['client_upload_id'],
        '0aaaaaaa-bbbb-4ccc-8ddd-0123456789ab',
      );
    });

    test('PUT 校验失败（存储端拒）三轮耗尽：上抛且不 bind', () async {
      final File file = writeFile('put-fail.bin', <int>[1]);
      final List<Map<String, dynamic>> bindBodies = <Map<String, dynamic>>[];
      await expectLater(
        api.uploadFileDirect(
          groupId: '3001',
          file: file,
          fileName: 'put-fail.bin',
          mime: 'application/octet-stream',
          sessionFn: directSession(
            keyOf: (String f) => 'u1/group/3001/$f',
            onRequest: (_, _) {},
          ),
          putFn: (String url, File f, int l, Map<String, String> h) async {
            throw Exception('direct put failed: http 403');
          },
          bindFn: (Map<String, dynamic> b) async {
            bindBodies.add(b);
            return ok(<String, dynamic>{'file_id': 'x'});
          },
        ),
        throwsException,
      );
      expect(bindBodies, isEmpty, reason: 'direct 未 CONFIRMED 不得 bind');
    });

    test('finalize 恒拒（confirm 拒绝 409）三轮耗尽：上抛且不 bind', () async {
      final File file = writeFile('fin-reject.bin', <int>[2]);
      final List<Map<String, dynamic>> bindBodies = <Map<String, dynamic>>[];
      await expectLater(
        api.uploadFileDirect(
          groupId: '3001',
          file: file,
          fileName: 'fin-reject.bin',
          mime: 'application/octet-stream',
          sessionFn: directSession(
            keyOf: (String f) => 'u1/group/3001/$f',
            onRequest: (_, _) {},
            override: (String action, Map<String, dynamic> body) {
              if (action != 'finalize') return null;
              return IMBoyHttpResponse.failure(
                errMsg: 'attempt_rejected',
                errCode: 409,
              );
            },
          ),
          putFn: (String url, File f, int l, Map<String, String> h) async {},
          bindFn: (Map<String, dynamic> b) async {
            bindBodies.add(b);
            return ok(<String, dynamic>{'file_id': 'x'});
          },
        ),
        throwsException,
      );
      expect(bindBodies, isEmpty);
    });

    test('FINALIZING（封存未确认）：不 bind，返回 null', () async {
      final File file = writeFile('quarantine.bin', <int>[3]);
      final List<Map<String, dynamic>> bindBodies = <Map<String, dynamic>>[];
      final Map<String, dynamic>? result = await api.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'quarantine.bin',
        mime: 'application/octet-stream',
        sessionFn: directSession(
          keyOf: (String f) => 'u1/group/3001/$f',
          onRequest: (_, _) {},
          override: (String action, Map<String, dynamic> body) {
            if (action != 'finalize') return null;
            return ok(<String, dynamic>{
              'state': 'FINALIZING',
              'outcome': 'UNKNOWN_QUARANTINED',
              'attempt_id': body['attempt_id'],
            });
          },
        ),
        putFn: (String url, File f, int l, Map<String, String> h) async {},
        bindFn: (Map<String, dynamic> b) async {
          bindBodies.add(b);
          return ok(<String, dynamic>{'file_id': 'x'});
        },
      );
      expect(result, isNull);
      expect(bindBodies, isEmpty);
    });

    test('跨群 bind 拒绝（mock 403 cross_subject）：返回 null', () async {
      final File file = writeFile('cross.bin', <int>[4]);
      final Map<String, dynamic>? result = await api.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'cross.bin',
        mime: 'application/octet-stream',
        sessionFn: directSession(
          keyOf: (String f) => 'u1/group/other/$f',
          onRequest: (_, _) {},
        ),
        putFn: (String url, File f, int l, Map<String, String> h) async {},
        bindFn: (Map<String, dynamic> b) async =>
            IMBoyHttpResponse.failure(errMsg: '附件归属不匹配', errCode: 403),
      );
      expect(result, isNull);
    });

    test('中断重试（kill 后恢复）+ 重复 bind 幂等：同 clientUploadId 两轮全链均成功', () async {
      final File file = writeFile('resume.bin', <int>[5, 5, 5]);
      const String cuid = '0aaaaaaa-bbbb-4ccc-8ddd-0123456789ab';
      final List<Map<String, dynamic>> registers = <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> bindBodies = <Map<String, dynamic>>[];
      int bindCalls = 0;
      int putRounds = 0;

      Future<IMBoyHttpResponse> session(
        String path, {
        Map<String, dynamic>? body,
      }) => directSession(
        keyOf: (String f) => 'u1/group/3001/$f',
        onRequest: (String a, Map<String, dynamic> b) {
          if (a == 'register') registers.add(b);
        },
      )(path, body: body);
      Future<void> put(String url, File f, int l, Map<String, String> h) async {
        putRounds++;
      }

      // 第一轮：PUT 阶段模拟进程被杀（普通异常×3 轮耗尽上抛）
      await expectLater(
        api.uploadFileDirect(
          groupId: '3001',
          file: file,
          fileName: 'resume.bin',
          mime: 'application/octet-stream',
          clientUploadId: cuid,
          sessionFn: session,
          putFn: (String url, File f, int l, Map<String, String> h) async {
            throw Exception('socket closed (killed)');
          },
          bindFn: (Map<String, dynamic> b) async =>
              ok(<String, dynamic>{'file_id': 'x'}),
        ),
        throwsException,
      );
      expect(registers, hasLength(1));

      // 第二轮（重试）：同 clientUploadId；register 幂等返回同 object_key，
      // 全链 CONFIRMED；bind 重复调用返回既有 file_id（服务端幂等语义）。
      final Map<String, dynamic>? retried = await api.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        clientUploadId: cuid,
        sessionFn: session,
        putFn: put,
        bindFn: (Map<String, dynamic> b) async {
          bindCalls++;
          bindBodies.add(b);
          return ok(<String, dynamic>{'file_id': 'file_tsid_resume'});
        },
      );
      expect(retried?['file_id'], 'file_tsid_resume');
      expect(putRounds, 1);
      expect(registers, hasLength(2));
      expect(
        registers[0]['client_upload_id'],
        registers[1]['client_upload_id'],
        reason: '重试必须复用同 clientUploadId（幂等恢复会话）',
      );
      expect(bindBodies, hasLength(1));

      // 重复 bind（如 UI 误双击）：仍成功且 file_id 同值
      final Map<String, dynamic>? again = await api.uploadFileDirect(
        groupId: '3001',
        file: file,
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        clientUploadId: cuid,
        sessionFn: session,
        putFn: put,
        bindFn: (Map<String, dynamic> b) async {
          bindCalls++;
          return ok(<String, dynamic>{'file_id': 'file_tsid_resume'});
        },
      );
      expect(again?['file_id'], 'file_tsid_resume');
      expect(bindCalls, 2);
    });
  });

  group('GroupAlbumApi.uploadPhotosDirect（相册批量 direct+bind_batch）', () {
    final GroupAlbumApi api = GroupAlbumApi();

    GroupAlbumUploadItem itemOf(File f, String name, String cuid) =>
        GroupAlbumUploadItem(file: f, photoName: name, clientUploadId: cuid);

    test('成功旅程：3 张逐项 direct + 单次 bind_batch(3 items)', () async {
      final List<File> files = <File>[
        writeFile('p1.png', <int>[1, 1]),
        writeFile('p2.jpg', <int>[2, 2, 2]),
        writeFile('p3.gif', <int>[3]),
      ];
      final List<Map<String, dynamic>> batches = <Map<String, dynamic>>[];
      final List<String> actions = <String>[];

      final List<GroupAlbumUploadOutcome> outcomes = await api
          .uploadPhotosDirect(
            groupId: '3002',
            albumId: '88',
            items: <GroupAlbumUploadItem>[
              for (int i = 0; i < files.length; i++)
                itemOf(files[i], files[i].uri.pathSegments.last, 'c-$i'),
            ],
            sessionFn: directSession(
              keyOf: (String f) => 'u1/group/3002/$f',
              onRequest: (String a, Map<String, dynamic> b) => actions.add(a),
            ),
            putFn: (String url, File f, int l, Map<String, String> h) async {},
            bindBatchFn: (Map<String, dynamic> body) async {
              batches.add(body);
              final List<dynamic> items = body['items'] as List<dynamic>;
              return ok(<String, dynamic>{
                'results': <dynamic>[
                  for (final dynamic it in items)
                    <String, dynamic>{
                      'object_key': it['object_key'],
                      'status': 'ok',
                      'photo': <String, dynamic>{
                        'photo_id': 'photo_${it['object_key']}',
                      },
                    },
                ],
              });
            },
          );

      expect(outcomes, hasLength(3));
      expect(outcomes.every((o) => o.ok), isTrue);
      // 3 项 × 4 步 direct 会话 + 1 次 bind_batch
      expect(actions.where((a) => a == 'register').length, 3);
      expect(actions.where((a) => a == 'finalize').length, 3);
      expect(batches, hasLength(1));
      final List<dynamic> items = batches.single['items'] as List<dynamic>;
      expect(items, hasLength(3));
      expect(batches.single['gid'], '3002');
      for (final dynamic it in items) {
        expect(it['album_id'], '88');
        expect(it['mime_type'], anyOf('image/png', 'image/jpeg', 'image/gif'));
        expect('${it['sha256']}', isNotEmpty);
        expect(it['object_key'], startsWith('u1/group/3002/'));
      }
    });

    test('部分 direct 失败：失败项不进 bind_batch，其余照常绑定（不整批回滚）', () async {
      final File ok1 = writeFile('ok1.png', <int>[1]);
      final File bad = writeFile('bad.png', <int>[2]);
      final File ok2 = writeFile('ok2.png', <int>[3]);
      final List<Map<String, dynamic>> batches = <Map<String, dynamic>>[];

      final List<GroupAlbumUploadOutcome> outcomes = await api
          .uploadPhotosDirect(
            groupId: '3002',
            albumId: '88',
            items: <GroupAlbumUploadItem>[
              itemOf(ok1, 'ok1.png', 'c-1'),
              itemOf(bad, 'bad.png', 'c-2'),
              itemOf(ok2, 'ok2.png', 'c-3'),
            ],
            sessionFn: directSession(
              keyOf: (String f) => 'u1/group/3002/$f',
              onRequest: (_, _) {},
            ),
            putFn: (String url, File f, int l, Map<String, String> h) async {
              if (url.contains('bad')) {
                throw Exception('direct put failed: http 500');
              }
            },
            bindBatchFn: (Map<String, dynamic> body) async {
              batches.add(body);
              final List<dynamic> items = body['items'] as List<dynamic>;
              return ok(<String, dynamic>{
                'results': <dynamic>[
                  for (final dynamic it in items)
                    <String, dynamic>{
                      'object_key': it['object_key'],
                      'status': 'ok',
                      'photo': <String, dynamic>{'photo_id': 'p'},
                    },
                ],
              });
            },
          );

      expect(outcomes, hasLength(3));
      final GroupAlbumUploadOutcome failed = outcomes[1];
      expect(failed.ok, isFalse);
      expect(failed.reason, 'direct_failed');
      expect(failed.item.photoName, 'bad.png', reason: '失败项保留本地重试');
      expect(outcomes[0].ok && outcomes[2].ok, isTrue);
      expect(batches, hasLength(1));
      final List<dynamic> items = batches.single['items'] as List<dynamic>;
      expect(
        items.map((dynamic it) => it['photo_name']),
        everyElement(isNot('bad.png')),
      );
    });

    test('bind_batch 逐项 error（跨群 bind 拒绝）：对应项 failed bind_rejected', () async {
      final File a = writeFile('ra.png', <int>[1]);
      final File b = writeFile('rb.png', <int>[2]);

      final List<GroupAlbumUploadOutcome> outcomes = await api
          .uploadPhotosDirect(
            groupId: '3002',
            albumId: '88',
            items: <GroupAlbumUploadItem>[
              itemOf(a, 'ra.png', 'c-a'),
              itemOf(b, 'rb.png', 'c-b'),
            ],
            sessionFn: directSession(
              keyOf: (String f) => 'u1/group/3002/$f',
              onRequest: (_, _) {},
            ),
            putFn: (String url, File f, int l, Map<String, String> h) async {},
            bindBatchFn: (Map<String, dynamic> body) async {
              final List<dynamic> items = body['items'] as List<dynamic>;
              return ok(<String, dynamic>{
                'results': <dynamic>[
                  <String, dynamic>{
                    'object_key': items[0]['object_key'],
                    'status': 'ok',
                    'photo': <String, dynamic>{'photo_id': 'p1'},
                  },
                  <String, dynamic>{
                    'object_key': items[1]['object_key'],
                    'status': 'error',
                    'reason': 'cross_subject',
                  },
                ],
              });
            },
          );

      expect(outcomes[0].ok, isTrue);
      expect(outcomes[1].ok, isFalse);
      expect(outcomes[1].reason, 'bind_rejected');
    });

    test('bind_batch 信封失败（mock 403）：已传项落账 bind_batch_failed 可重试', () async {
      final File a = writeFile('env-fail.png', <int>[1]);

      final List<GroupAlbumUploadOutcome> outcomes = await api
          .uploadPhotosDirect(
            groupId: '3002',
            albumId: '88',
            items: <GroupAlbumUploadItem>[itemOf(a, 'env-fail.png', 'c-e')],
            sessionFn: directSession(
              keyOf: (String f) => 'u1/group/3002/$f',
              onRequest: (_, _) {},
            ),
            putFn: (String url, File f, int l, Map<String, String> h) async {},
            bindBatchFn: (Map<String, dynamic> body) async =>
                IMBoyHttpResponse.failure(errMsg: 'forbidden', errCode: 403),
          );

      expect(outcomes.single.ok, isFalse);
      expect(outcomes.single.reason, 'bind_batch_failed');
    });

    test(
      // C08（source-audit C08-album-partial）：bindBatch 传输层异常不得逃逸
      // 吞掉已回填结果——按项落账 bind_batch_failed 后整批继续。
      'bind_batch 抛异常（传输层 throw）：按项落账不丢前序结果',
      () async {
        final File a = writeFile('throw-a.png', <int>[1]);
        final File b = writeFile('throw-b.png', <int>[2]);

        final List<GroupAlbumUploadOutcome> outcomes = await api
            .uploadPhotosDirect(
              groupId: '3002',
              albumId: '88',
              items: <GroupAlbumUploadItem>[
                itemOf(a, 'throw-a.png', 'c-ta'),
                itemOf(b, 'throw-b.png', 'c-tb'),
              ],
              sessionFn: directSession(
                keyOf: (String f) => 'u1/group/3002/$f',
                onRequest: (_, _) {},
              ),
              putFn: (
                String url,
                File f,
                int l,
                Map<String, String> h,
              ) async {},
              bindBatchFn: (Map<String, dynamic> body) async {
                throw Exception('transport down');
              },
            );

        expect(outcomes, hasLength(2));
        expect(outcomes.every((GroupAlbumUploadOutcome o) => !o.ok), isTrue);
        expect(
          outcomes.map((GroupAlbumUploadOutcome o) => o.reason),
          everyElement('bind_batch_failed'),
        );
      },
    );

    test(
      '白名单外 MIME（heic）：不发起 direct，直接 failed unsupported_image_type',
      () async {
        final File heic = writeFile('photo.heic', <int>[1, 2]);
        final List<String> actions = <String>[];

        final List<GroupAlbumUploadOutcome> outcomes = await api
            .uploadPhotosDirect(
              groupId: '3002',
              albumId: '88',
              items: <GroupAlbumUploadItem>[itemOf(heic, 'photo.heic', 'c-h')],
              sessionFn: directSession(
                keyOf: (String f) => 'u1/group/3002/$f',
                onRequest: (String a, Map<String, dynamic> b) => actions.add(a),
              ),
              putFn: (
                String url,
                File f,
                int l,
                Map<String, String> h,
              ) async {},
              bindBatchFn: (Map<String, dynamic> b) async =>
                  ok(<String, dynamic>{'results': <dynamic>[]}),
            );

        expect(outcomes.single.ok, isFalse);
        expect(outcomes.single.reason, 'unsupported_image_type');
        expect(actions, isEmpty);
      },
    );

    test('重复 bind_batch 幂等（duplicate:true 仍 ok）：重试轮全部成功', () async {
      final File a = writeFile('dup.png', <int>[9]);
      final List<Map<String, dynamic>> itemsIn = <Map<String, dynamic>>[];
      Future<IMBoyHttpResponse> session(
        String path, {
        Map<String, dynamic>? body,
      }) => directSession(
        keyOf: (String f) => 'u1/group/3002/$f',
        onRequest: (_, _) {},
      )(path, body: body);
      Future<void> put(
        String url,
        File f,
        int l,
        Map<String, String> h,
      ) async {}

      Future<List<GroupAlbumUploadOutcome>> run() => api.uploadPhotosDirect(
        groupId: '3002',
        albumId: '88',
        items: <GroupAlbumUploadItem>[itemOf(a, 'dup.png', 'c-dup')],
        sessionFn: session,
        putFn: put,
        bindBatchFn: (Map<String, dynamic> body) async {
          itemsIn.add(Map<String, dynamic>.from(body['items'].first as Map));
          // 第二次（重试）返回 duplicate:true——同 album+object 已绑定
          final bool duplicate = itemsIn.length > 1;
          return ok(<String, dynamic>{
            'results': <dynamic>[
              <String, dynamic>{
                'object_key': (body['items'] as List).first['object_key'],
                'status': 'ok',
                'photo': <String, dynamic>{
                  'photo_id': 'p-existing',
                  if (duplicate) 'duplicate': true,
                },
              },
            ],
          });
        },
      );

      final List<GroupAlbumUploadOutcome> first = await run();
      final List<GroupAlbumUploadOutcome> second = await run();
      expect(first.single.ok && second.single.ok, isTrue);
      expect(second.single.photo?['duplicate'], isTrue);
      // 两轮 bind 的 object_key 一致（同 clientUploadId → 同会话同对象）
      expect(itemsIn[0]['object_key'], itemsIn[1]['object_key']);
    });
  });

  group('R04/退役静态断言（源码级）', () {
    test(
      'direct 链路无 readAsBytes、无 FormData/MultipartFile（multipart 不留 fallback）',
      () {
        const List<String> files = <String>[
          'lib/store/api/group_file_api.dart',
          'lib/store/api/group_album_api.dart',
          'lib/page/group/file/group_file_page.dart',
          'lib/page/group/album/group_album_page.dart',
          'lib/service/group_file_service.dart',
          'lib/service/group_album_service.dart',
        ];
        for (final String path in files) {
          final String src = File(path).readAsStringSync();
          expect(
            RegExp(r'readAsBytes\w*\s*\(').allMatches(src),
            isEmpty,
            reason: 'R04：$path 禁止整文件读入内存',
          );
          expect(
            src.contains('FormData') || src.contains('MultipartFile'),
            isFalse,
            reason: 'V3-12：$path multipart 路径必须删除，不留 fallback',
          );
        }
      },
    );
  });
}
