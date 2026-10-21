import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';

/// step-8（direct-v1 文件化传输）定向测试：
///   * 流式 sha256 正确性 + 全链编排（mock 会话/PUT，不触网）；
///   * required_headers 原样透传且仅两项（T07/T29 客户端侧）；
///   * PUT 失败 → renew 新 attempt 重试（I05：URL 不重放）；
///   * FINALIZING（服务端封存中）如实上报，不得冒充 CONFIRMED；
///   * 本地取消：中断且不发 finalize；
///   * 大文件路径不 readAsBytes（putFn 收到 File；源码无 readAsBytes 调用）；
///   * journal epoch 隔离（E10）。
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dv1-flutter-test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  File writeFile(String name, List<int> bytes) {
    final File f = File('${tmp.path}/$name');
    f.writeAsBytesSync(bytes);
    return f;
  }

  IMBoyHttpResponse ok(Map<String, dynamic> payload) =>
      IMBoyHttpResponse.success(payload);

  /// grant fake 的 required_headers 用后端真实线格式：to_js 把 tuple {K,V}
  /// 编成 JSON 二元数组 [K, V]（20b 真 HTTP driver 实证）。此前 fake 用
  /// {K:V} Map 与旧 grantOf 同错形成假绿——真实后端对接时 headers 恒空。
  IMBoyHttpResponse grantPayload(
    String url,
    int attemptId,
    String checksumB64,
  ) => ok(<String, dynamic>{
    'state': 'GRANTED',
    'object_key': 'u1/file/x',
    'attempt_id': attemptId,
    'grant': <String, dynamic>{
      'transport': 's3_put',
      'url': url,
      'method': 'PUT',
      'required_headers': <dynamic>[
        <dynamic>['Content-Type', 'image/png'],
        <dynamic>['x-amz-checksum-sha256', checksumB64],
      ],
      'expires_in': 3600,
    },
  });

  test('sha256OfFile 与单块/多块向量一致（流式，不整读）', () async {
    final File small = writeFile('small.bin', <int>[1, 2, 3, 4]);
    final String h1 = await sha256OfFile(small);
    final String h2 = crypto.sha256.convert(<int>[1, 2, 3, 4]).toString();
    expect(h1, h2);

    // 多块（>2 个 64KB 块）流式对拍
    final List<int> big = <int>[for (int i = 0; i < 200 * 1024; i++) i % 251];
    final File bigFile = writeFile('big.bin', big);
    expect(await sha256OfFile(bigFile), crypto.sha256.convert(big).toString());
  });

  test('happy path：全链编排 + required_headers 精确透传 + checkpoint 完整', () async {
    final File file = writeFile('a.png', <int>[9, 9, 9]);
    final String sha = await sha256OfFile(file);
    final String checksumB64 = base64.encode(<int>[1, 2]);
    final List<String> putUrls = <String>[];
    final List<Map<String, String>> putHeaders = <Map<String, String>>[];
    final List<int> putLengths = <int>[];

    IMBoyHttpResponse handler(String action, Map<String, dynamic> body) {
      switch (action) {
        case 'register':
          return ok(<String, dynamic>{
            'object_key': 'u1/file/dv1a',
            'state': 'RESERVED',
          });
        case 'declare':
          return ok(<String, dynamic>{
            'state': 'DECLARED',
            'expected_version': 1,
          });
        case 'grant':
          return grantPayload('https://s3.example/put-1', 1, checksumB64);
        case 'finalize':
          return ok(<String, dynamic>{
            'state': 'CONFIRMED',
            'attempt_id': body['attempt_id'],
          });
      }
      throw StateError('unexpected action $action');
    }

    final List<String> actions = <String>[];
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final String action = path.split('/').last;
      actions.add(action);
      bodies.add(body ?? <String, dynamic>{});
      return handler(action, body ?? <String, dynamic>{});
    }

    final List<DirectCheckpointStage> stages = <DirectCheckpointStage>[];
    final DirectUploadResult r = await DirectAttachmentApi.uploadFile(
      file,
      fileName: 'a.png',
      mime: 'image/png',
      sessionFn: session,
      putFn:
          (String url, File f, int length, Map<String, String> headers) async {
            putUrls.add(url);
            putHeaders.add(headers);
            putLengths.add(length);
          },
      checkpoint: (DirectCheckpoint e) async => stages.add(e.stage),
    );

    expect(r.state, 'CONFIRMED');
    expect(r.objectKey, 'u1/file/dv1a');
    expect(actions, <String>['register', 'declare', 'grant', 'finalize']);
    expect(bodies[1]['sha256'], sha);
    expect(bodies[1]['size_bytes'], file.lengthSync());
    // required_headers 原样且仅两项（T07：不增；T29：无业务凭据）
    expect(putHeaders.single['Content-Type'], 'image/png');
    expect(putHeaders.single['x-amz-checksum-sha256'], checksumB64);
    expect(putHeaders.single.length, 2);
    expect(putLengths.single, file.lengthSync());
    // attempt_id 传给 finalize（单次 dispatch 绑定）
    expect(bodies[3]['attempt_id'], 1);
    // checkpoint 阶段序完整
    expect(stages, <DirectCheckpointStage>[
      DirectCheckpointStage.registered,
      DirectCheckpointStage.declared,
      DirectCheckpointStage.granted,
      DirectCheckpointStage.putDone,
      DirectCheckpointStage.confirmed,
    ]);
  });

  test('PUT 失败一次 → renew 新 attempt（URL 不重放）→ 成功', () async {
    final File file = writeFile('b.png', <int>[1]);
    final List<String> actions = <String>[];
    final List<String> urls = <String>[];
    final List<dynamic> finalizeAttemptIds = <dynamic>[];
    int grantRound = 0;
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final String action = path.split('/').last;
      actions.add(action);
      switch (action) {
        case 'register':
          return ok(<String, dynamic>{'object_key': 'u1/file/dv1b'});
        case 'declare':
          return ok(<String, dynamic>{'state': 'DECLARED'});
        case 'grant':
        case 'renew':
          grantRound += 1;
          return grantPayload(
            'https://s3.example/attempt-$grantRound',
            grantRound,
            'YQ==',
          );
        case 'finalize':
          finalizeAttemptIds.add(body?['attempt_id']);
          return ok(<String, dynamic>{
            'state': 'CONFIRMED',
            'attempt_id': body?['attempt_id'],
          });
      }
      throw StateError('unexpected $action');
    }

    final DirectUploadResult r = await DirectAttachmentApi.uploadFile(
      file,
      fileName: 'b.png',
      mime: 'image/png',
      sessionFn: session,
      putFn:
          (String url, File f, int length, Map<String, String> headers) async {
            urls.add(url);
            if (urls.length == 1) {
              throw Exception('direct put failed: http 500');
            }
          },
    );

    expect(r.state, 'CONFIRMED');
    expect(actions.where((String a) => a == 'renew').length, 1);
    expect(urls.length, 2);
    expect(urls[0], isNot(urls[1])); // I05：重试必新 URL/新 target
    expect(finalizeAttemptIds, <int>[2]);
  });

  test('finalize 恒 rejected(409)：三次后按预算上抛，不冒充 CONFIRMED', () async {
    final File file = writeFile('c.png', <int>[2]);
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final String action = path.split('/').last;
      switch (action) {
        case 'register':
          return ok(<String, dynamic>{'object_key': 'u1/file/dv1c'});
        case 'declare':
          return ok(<String, dynamic>{'state': 'DECLARED'});
        case 'grant':
        case 'renew':
          return grantPayload('https://s3.example/x', 9, 'YQ==');
        case 'finalize':
          return IMBoyHttpResponse.failure(
            errMsg: 'attempt_rejected',
            errCode: 409,
          );
      }
      throw StateError('unexpected $action');
    }

    await expectLater(
      DirectAttachmentApi.uploadFile(
        file,
        fileName: 'c.png',
        mime: 'image/png',
        sessionFn: session,
        putFn: (
          String url,
          File f,
          int length,
          Map<String, String> headers,
        ) async {},
      ),
      throwsException,
    );
  });

  test('finalize 返回 FINALIZING：如实上报封存中，不冒充 CONFIRMED', () async {
    final File file = writeFile('d.png', <int>[3]);
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final String action = path.split('/').last;
      switch (action) {
        case 'register':
          return ok(<String, dynamic>{'object_key': 'u1/file/dv1d'});
        case 'declare':
          return ok(<String, dynamic>{'state': 'DECLARED'});
        case 'grant':
          return grantPayload('https://s3.example/x', 1, 'YQ==');
        case 'finalize':
          return ok(<String, dynamic>{
            'state': 'FINALIZING',
            'outcome': 'UNKNOWN_QUARANTINED',
            'attempt_id': body?['attempt_id'],
            'retry_action': 'retry_attempt',
          });
      }
      throw StateError('unexpected $action');
    }

    final List<DirectCheckpointStage> stages = <DirectCheckpointStage>[];
    final DirectUploadResult r = await DirectAttachmentApi.uploadFile(
      file,
      fileName: 'd.png',
      mime: 'image/png',
      sessionFn: session,
      putFn: (
        String url,
        File f,
        int length,
        Map<String, String> headers,
      ) async {},
      checkpoint: (DirectCheckpoint e) async => stages.add(e.stage),
    );
    expect(r.state, 'FINALIZING');
    expect(r.state, isNot('CONFIRMED'));
    // 封存态如实暴露（调用方据此不得把附件发出）
    expect(r.quarantined, isTrue);
    // confirmed checkpoint 只对应真 CONFIRMED——封存态发出会让持久化
    // checkpoint 的调用方误判"已确认"（review 第四轮回归锚）
    expect(stages, isNot(contains(DirectCheckpointStage.confirmed)));
  });

  test('本地取消：putFn 抛取消后中断且不发 finalize', () async {
    final File file = writeFile('e.png', <int>[4]);
    final List<String> actions = <String>[];
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final String action = path.split('/').last;
      actions.add(action);
      switch (action) {
        case 'register':
          return ok(<String, dynamic>{'object_key': 'u1/file/dv1e'});
        case 'declare':
          return ok(<String, dynamic>{'state': 'DECLARED'});
        case 'grant':
          return grantPayload('https://s3.example/x', 1, 'YQ==');
      }
      throw StateError('unexpected $action');
    }

    await expectLater(
      DirectAttachmentApi.uploadFile(
        file,
        fileName: 'e.png',
        mime: 'image/png',
        sessionFn: session,
        putFn:
            (
              String url,
              File f,
              int length,
              Map<String, String> headers,
            ) async {
              throw const DirectUploadCancelled('u1/file/dv1e');
            },
      ),
      throwsA(isA<DirectUploadCancelled>()),
    );
    expect(
      actions.contains('finalize'),
      isFalse,
      reason: '取消后不得发起 finalize（服务端会话由 sweep 收敛）',
    );
  });

  test('大文件路径无 readAsBytes：源码静态断言 + putFn 收 File', () async {
    final String src = File('lib/store/api/attachment_direct_api.dart')
        .readAsStringSync();
    // 调用级断言（注释文本不算）：无 readAsBytes( / readAsBytesSync( 调用
    expect(
      RegExp(r'readAsBytes\w*\s*\(').allMatches(src),
      isEmpty,
      reason: 'R04：direct-v1 链路禁止整文件读入内存',
    );
  });

  test('journal epoch 隔离：uid 不符拒绝恢复（E10）', () {
    const DirectUploadJournal j = DirectUploadJournal(
      uid: '10001',
      clientUploadId: 'c-1',
      objectKey: 'u10001/file/x',
      stage: 'granted',
    );
    expect(() => j.requireEpoch('10001'), returnsNormally);
    expect(
      () => j.requireEpoch('20002'),
      throwsA(isA<DirectUploadEpochMismatch>()),
    );
  });

  test('resume：CONFIRMED 幂等直返；GRANTED 续传走 renew+finalize', () async {
    final File file = writeFile('f.png', <int>[5]);
    // CONFIRMED：幂等直返，无网络 PUT
    List<String> actions = <String>[];
    Future<IMBoyHttpResponse> confirmedSession(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final String action = path.split('/').last;
      actions.add(action);
      if (action == 'status') {
        return ok(<String, dynamic>{
          'state': 'CONFIRMED',
          'session_state': 'confirmed',
          'attempts': <dynamic>[],
        });
      }
      throw StateError('unexpected $action');
    }

    final DirectUploadResult done = await DirectAttachmentApi.resumeDirect(
      objectKey: 'u1/file/dv1f',
      file: file,
      mime: 'image/png',
      sessionFn: confirmedSession,
      putFn:
          (String url, File f, int length, Map<String, String> headers) async {
            throw StateError('confirmed 会话不得重新 PUT');
          },
    );
    expect(done.state, 'CONFIRMED');
    expect(actions, <String>['status']);

    // GRANTED：renew 新 attempt 续传
    actions = <String>[];
    Future<IMBoyHttpResponse> grantedSession(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final String action = path.split('/').last;
      actions.add(action);
      switch (action) {
        case 'status':
          return ok(<String, dynamic>{
            'state': 'GRANTED',
            'attempts': <dynamic>[<String, dynamic>{}],
          });
        case 'renew':
          return grantPayload('https://s3.example/resume-2', 2, 'YQ==');
        case 'finalize':
          return ok(<String, dynamic>{
            'state': 'CONFIRMED',
            'attempt_id': body?['attempt_id'],
          });
      }
      throw StateError('unexpected $action');
    }

    final DirectUploadResult resumed = await DirectAttachmentApi.resumeDirect(
      objectKey: 'u1/file/dv1g',
      file: file,
      mime: 'image/png',
      sessionFn: grantedSession,
      putFn:
          (String url, File f, int length, Map<String, String> headers) async {
            expect(url, 'https://s3.example/resume-2');
          },
    );
    expect(resumed.state, 'CONFIRMED');
    expect(resumed.attemptId, 2);
    expect(actions, <String>['status', 'renew', 'finalize']);
  });

  test(
    'resumeDirect finalize 封存态：quarantined 如实上报且不发 confirmed checkpoint',
    () async {
      final File file = writeFile('resume-q.png', <int>[7]);
      final List<DirectCheckpointStage> stages = <DirectCheckpointStage>[];
      Future<IMBoyHttpResponse> quarantinedSession(
        String path, {
        Map<String, dynamic>? body,
      }) async {
        final String action = path.split('/').last;
        switch (action) {
          case 'status':
            return ok(<String, dynamic>{
              'state': 'FINALIZING',
              'attempts': <dynamic>[<String, dynamic>{}, <String, dynamic>{}],
            });
          case 'renew':
            return grantPayload('https://s3.example/resume-q', 3, 'YQ==');
          case 'finalize':
            return ok(<String, dynamic>{
              'state': 'FINALIZING',
              'outcome': 'UNKNOWN_QUARANTINED',
              'attempt_id': body?['attempt_id'],
            });
        }
        throw StateError('unexpected $action');
      }

      final DirectUploadResult r = await DirectAttachmentApi.resumeDirect(
        objectKey: 'u1/file/dv1q',
        file: file,
        mime: 'image/png',
        sessionFn: quarantinedSession,
        putFn: (
          String url,
          File f,
          int length,
          Map<String, String> headers,
        ) async {},
        checkpoint: (DirectCheckpoint e) async => stages.add(e.stage),
      );
      expect(r.state, 'FINALIZING');
      expect(r.quarantined, isTrue);
      expect(stages, isNot(contains(DirectCheckpointStage.confirmed)));
    },
  );

  test('journal 落盘/加载往返', () async {
    const DirectUploadJournal j = DirectUploadJournal(
      uid: '42',
      clientUploadId: 'c-9',
      objectKey: 'u42/file/y',
      stage: 'declared',
    );
    await DirectUploadJournal.save(tmp, j);
    final DirectUploadJournal? loaded = await DirectUploadJournal.load(tmp);
    expect(loaded, isNotNull);
    expect(loaded!.uid, '42');
    expect(loaded.objectKey, 'u42/file/y');
  });
}
