@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:web/web.dart' as web;

const _origin = String.fromEnvironment('W09_CANCEL_ORIGIN');
const _nonce = String.fromEnvironment('W09_CANCEL_NONCE');
final _bytes = Uint8List.fromList([1, 2, 3, 4]);
final _sha = sha256.convert(_bytes);

String _caseId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256),
).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Future<(int, String)> _request(String path, {String method = 'GET'}) async {
  final controller = web.AbortController();
  Future<(int, String)> execute() async {
    final response = await web.window
        .fetch(
          '$_origin$path'.toJS,
          web.RequestInit(method: method, signal: controller.signal),
        )
        .toDart;
    final body = (await response.text().toDart).toDart;
    return (response.status, body);
  }

  try {
    return await execute().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        controller.abort();
        throw TimeoutException('fixture request timed out');
      },
    );
  } catch (_) {
    throw StateError('fixture request failed');
  }
}

Future<Map<String, dynamic>> _events(String id) async {
  final (status, body) = await _request('/events?case=$id&nonce=$_nonce');
  if (status != 200) throw StateError('fixture events HTTP $status');
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<void> _release(String id, {bool allowMissing = false}) async {
  final (status, _) = await _request(
    '/release?case=$id&nonce=$_nonce',
    method: 'POST',
  );
  if (status != 204 && !(allowMissing && status == 404)) {
    throw StateError('fixture release HTTP $status');
  }
}

Future<Map<String, dynamic>> _wait(String id, String key) async {
  final until = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(until)) {
    final e = await _events(id);
    if (e[key] == true) return e;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('fixture did not observe $key');
}

Future<void> _verifyIdentity() async {
  final (status, body) = await _request('/identity?nonce=$_nonce');
  if (status != 200) throw StateError('fixture identity rejected');
  try {
    final dynamic identity = jsonDecode(body);
    if (identity is! Map ||
        identity['fixture'] != 'w09-slow-put-v1' ||
        identity['nonce'] != _nonce) {
      throw StateError('fixture identity mismatch');
    }
  } catch (_) {
    throw StateError('fixture identity invalid');
  }
}

Future<DirectUploadResult> _safeUpload(
  Future<DirectUploadResult> upload,
) async {
  try {
    return await upload;
  } on DirectUploadCancelled {
    rethrow;
  } catch (_) {
    throw StateError('fixture upload failed');
  }
}

Future<void> _cleanup(String id, bool arrived, bool failed) async {
  try {
    await _release(id, allowMissing: !arrived);
  } catch (_) {
    if (!failed) rethrow;
    // Preserve the primary failure, while making cleanup failure visible.
    print('fixture cleanup failed');
  }
}

class _Control {
  _Control(this.id);
  final String id;
  final actions = <String>[];
  final checkpoints = <DirectCheckpointStage>[];
  Future<IMBoyHttpResponse> call(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final action = path.split('/').last;
    actions.add(action);
    switch (action) {
      case 'register':
        return IMBoyHttpResponse.success({
          'state': 'RESERVED',
          'object_key': 'synthetic/$id',
        });
      case 'declare':
        return IMBoyHttpResponse.success({'state': 'DECLARED'});
      case 'status':
        return IMBoyHttpResponse.success({
          'object_key': 'synthetic/$id',
          'state': 'GRANTED',
          'expected': {
            'sha256': _sha.toString(),
            'size_bytes': _bytes.length,
            'mime': 'application/octet-stream',
          },
          'attempts': [<String, dynamic>{}],
        });
      case 'grant':
      case 'renew':
        return IMBoyHttpResponse.success({
          'state': 'GRANTED',
          'attempt_id': action == 'grant' ? 1 : 2,
          'grant': {
            'transport': 's3_put',
            'method': 'PUT',
            'url': '$_origin/put?case=$id&nonce=$_nonce',
            'required_headers': [
              ['Content-Type', 'application/octet-stream'],
              ['x-amz-checksum-sha256', base64Encode(_sha.bytes)],
            ],
          },
        });
      case 'finalize':
        return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
      default:
        throw StateError('unexpected control action $action');
    }
  }

  Future<void> checkpoint(DirectCheckpoint e) async => checkpoints.add(e.stage);
}

void main() {
  setUpAll(() async {
    final uri = Uri.tryParse(_origin);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(_nonce)) {
      throw StateError('Set W09_CANCEL_NONCE to the task-owned fixture nonce');
    }
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host != '127.0.0.1' ||
        !uri.hasPort ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw StateError(
        'Set W09_CANCEL_ORIGIN to the task-owned loopback fixture origin',
      );
    }
    await _verifyIdentity();
  });

  for (final resume in [false, true]) {
    test(
      '${resume ? 'resume' : 'initial'} cancels actual in-flight browser PUT',
      () async {
        final id = _caseId();
        final control = _Control(id);
        final token = CancelToken();
        var currentOwner = 'owner-a';
        final source = DirectUploadSource.bytes(
          _bytes,
          beforeDispatch: () {
            if (currentOwner != 'owner-a') throw StateError('owner changed');
          },
        );
        var callerOutbox = 0;
        final Future<DirectUploadResult> upload = resume
            ? DirectAttachmentApi.resumeSource(
                objectKey: 'synthetic/$id',
                source: source,
                mime: 'application/octet-stream',
                sessionFn: control.call,
                checkpoint: control.checkpoint,
                cancelToken: token,
              )
            : DirectAttachmentApi.uploadSource(
                source,
                fileName: 'synthetic.bin',
                mime: 'application/octet-stream',
                sessionFn: control.call,
                checkpoint: control.checkpoint,
                cancelToken: token,
              );
        final observed = _safeUpload(upload).then((v) {
          callerOutbox++;
          return v;
        });
        final outcome = expectLater(
          observed,
          throwsA(isA<DirectUploadCancelled>()),
        );
        var arrived = false;
        var failed = false;
        try {
          await _wait(
            id,
            'bodyEnded',
          ); // Request reached fixture; response is still held.
          arrived = true;
          currentOwner =
              'owner-b'; // Synthetic switch; caller cancels the captured task.
          token.cancel('synthetic account transition');
          await outcome.timeout(const Duration(seconds: 8));
          final closed = await _wait(id, 'closedBeforeResponse');
          expect(closed['responses'], 0);
          expect(closed['puts'], 1);
          await _release(
            id,
          ); // Deliberately late response, must not revive the task.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect((await _events(id))['puts'], 1);
          expect(
            control.actions,
            resume ? ['status', 'renew'] : ['register', 'declare', 'grant'],
          );
          expect(
            control.checkpoints,
            isNot(contains(DirectCheckpointStage.putDone)),
          );
          expect(
            control.checkpoints,
            isNot(contains(DirectCheckpointStage.confirmed)),
          );
          expect(callerOutbox, 0);
        } catch (_) {
          failed = true;
          rethrow;
        } finally {
          token.cancel('test cleanup');
          await _cleanup(id, arrived, failed);
        }
      },
    );
  }

  test(
    'response wins before later cancellation: one finalize and no replay',
    () async {
      final id = _caseId();
      final control = _Control(id);
      final token = CancelToken();
      final upload = DirectAttachmentApi.uploadSource(
        DirectUploadSource.bytes(_bytes),
        fileName: 'synthetic.bin',
        mime: 'application/octet-stream',
        sessionFn: control.call,
        cancelToken: token,
        checkpoint: control.checkpoint,
      );
      var arrived = false;
      var failed = false;
      try {
        await _wait(id, 'bodyEnded');
        arrived = true;
        await _release(id);
        final result = await _safeUpload(upload)
            .timeout(const Duration(seconds: 8));
        expect(result.state, 'CONFIRMED');
        token.cancel('too late');
        expect(control.actions, ['register', 'declare', 'grant', 'finalize']);
        expect((await _events(id))['puts'], 1);
      } catch (_) {
        failed = true;
        rethrow;
      } finally {
        token.cancel('test cleanup');
        await _cleanup(id, arrived, failed);
      }
    },
  );
}
