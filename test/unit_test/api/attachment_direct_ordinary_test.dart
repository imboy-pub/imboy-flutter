import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/store/api/attachment_api.dart';

void main() {
  test('群消息密文 direct 登记并冻结密文与锚点', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final requests = <({String action, Map<String, dynamic> body})>[];
    final stages = <UploadCheckpointStage>[];
    Uint8List? uploaded;
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final action = path.split('/').last;
      final data = body ?? <String, dynamic>{};
      requests.add((action: action, body: data));
      switch (action) {
        case 'register':
          return IMBoyHttpResponse.success({
            'object_key': 'group/g/key',
            'state': 'RESERVED',
          });
        case 'declare':
          return IMBoyHttpResponse.success({'state': 'DECLARED'});
        case 'grant':
          return IMBoyHttpResponse.success({
            'attempt_id': 1,
            'grant': {
              'transport': 's3_put',
              'url': 'https://s3.example/a',
              'method': 'PUT',
              'required_headers': [
                ['Content-Type', 'image/png'],
                ['x-amz-checksum-sha256', 'sha'],
              ],
              'expires_in': 300,
            },
          });
        case 'finalize':
          return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
        default:
          throw StateError(action);
      }
    }

    final seal = AttachmentSealRequest(
      bindingHash: Uint8List(32),
      attachmentId: 'message-file',
    );
    final key = await AttachmentApi.uploadViaPresign(
      bytes,
      'a.png',
      'image/png',
      scope: 'group',
      scopeRef: 'g',
      anchorMsgId: 'xid',
      clientUploadId: 'f0e0d0c0-b0a0-4908-8877-665544332211',
      persistTask: false,
      seal: seal,
      directSessionFn: session,
      directPutFn: (url, file, length, headers) async {
        uploaded = await file.readAsBytes();
      },
      checkpoint: (event) async => stages.add(event.stage),
    );
    expect(key, 'group/g/key');
    expect(requests.map((e) => e.action), [
      'register',
      'register',
      'declare',
      'grant',
      'finalize',
    ]);
    for (final registration in requests.where((e) => e.action == 'register')) {
      expect(registration.body['cipher'], AttachmentDescriptor.supportedCipher);
      expect(registration.body['purpose'], 'message');
      expect(registration.body['anchor_msg_id'], 'xid');
    }
    final declared = requests.singleWhere((e) => e.action == 'declare').body;
    expect(declared['sha256'], crypto.sha256.convert(uploaded!).toString());
    expect(declared['sha256'], isNot(crypto.sha256.convert(bytes).toString()));
    expect(declared['size_bytes'], uploaded!.length);
    expect(
      jsonEncode(requests.map((e) => e.body).toList()),
      isNot(contains(crypto.sha256.convert(bytes).toString())),
    );
    expect(seal.descriptor?.objectKey, key);
    expect(stages, [
      UploadCheckpointStage.presigned,
      UploadCheckpointStage.sealed,
      UploadCheckpointStage.putDone,
      UploadCheckpointStage.confirmed,
    ]);
  });
  test('已确认恢复复核密文并按本地检查点完成', () async {
    final bytes = Uint8List.fromList([8, 7, 6]);
    Uint8List? ciphertext;
    Uint8List? contentKey;
    Uint8List? baseNonce;
    String? sha;
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      switch (path.split('/').last) {
        case 'register':
          return IMBoyHttpResponse.success({
            'object_key': 'private/key',
            'state': 'CONFIRMED',
          });
        case 'status':
          return IMBoyHttpResponse.success({
            'state': 'CONFIRMED',
            'expected': {
              'sha256': sha,
              'size_bytes': ciphertext!.length,
              'mime': 'image/png',
            },
          });
        default:
          throw StateError('unexpected action $path');
      }
    }

    final seal = AttachmentSealRequest(
      bindingHash: Uint8List(32),
      attachmentId: 'image-1',
    );
    final stages = <UploadCheckpointStage>[];
    await expectLater(
      AttachmentApi.uploadViaPresign(
        bytes,
        'a.png',
        'image/png',
        persistTask: false,
        seal: seal,
        clientUploadId: 'f0e0d0c0-b0a0-4908-8877-665544332211',
        directSessionFn: (path, {body}) async {
          if (path.endsWith('/register')) {
            return IMBoyHttpResponse.success({
              'object_key': 'private/key',
              'state': 'RESERVED',
            });
          }
          throw StateError('interrupt after checkpoint');
        },
        checkpoint: (event) async {
          stages.add(event.stage);
          if (event.stage == UploadCheckpointStage.sealed) {
            ciphertext = event.uploadBytes;
            contentKey = event.contentKey;
            baseNonce = event.baseNonce;
            sha = event.ciphertextSha256;
            throw StateError('simulated crash');
          }
        },
      ),
      throwsStateError,
    );
    final recoveredStages = <UploadCheckpointStage>[];
    final recoveredSeal = AttachmentSealRequest(
      bindingHash: Uint8List(32),
      attachmentId: 'image-1',
    );
    final recovered = await AttachmentApi.uploadViaPresign(
      bytes,
      'a.png',
      'image/png',
      persistTask: false,
      seal: recoveredSeal,
      clientUploadId: 'f0e0d0c0-b0a0-4908-8877-665544332211',
      directSessionFn: session,
      resume: ResumableUploadState(
        objectKey: 'private/key',
        contentKey: contentKey,
        baseNonce: baseNonce,
      ),
      directPutFn: (_, _, _, _) async =>
          throw StateError('confirmed object must not be uploaded'),
      checkpoint: (event) async => recoveredStages.add(event.stage),
    );
    expect(recovered, 'private/key');
    expect(recoveredSeal.uploadedFileHash256, sha);
    expect(recoveredStages, [
      UploadCheckpointStage.sealed,
      UploadCheckpointStage.putDone,
      UploadCheckpointStage.confirmed,
    ]);
  });

  test('账号变更在领取 PUT 前终止', () async {
    var active = true;
    var sent = false;
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      if (path.endsWith('/register')) {
        return IMBoyHttpResponse.success({
          'object_key': 'private/key',
          'state': 'RESERVED',
        });
      }
      if (path.endsWith('/declare')) {
        return IMBoyHttpResponse.success({'state': 'DECLARED'});
      }
      if (path.endsWith('/grant')) {
        active = false;
        return IMBoyHttpResponse.success({
          'attempt_id': 1,
          'grant': {
            'transport': 's3_put',
            'url': 'https://s3.example/a',
            'method': 'PUT',
            'required_headers': [
              ['Content-Type', 'image/png'],
              ['x-amz-checksum-sha256', 'sha'],
            ],
          },
        });
      }
      throw StateError(path);
    }

    await expectLater(
      AttachmentApi.uploadViaPresign(
        Uint8List.fromList([1]),
        'a.png',
        'image/png',
        persistTask: false,
        directSessionFn: session,
        requireSession: () {
          if (!active) throw StateError('session changed');
        },
        directPutFn: (_, _, _, _) async {
          sent = true;
        },
      ),
      throwsStateError,
    );
    expect(sent, isFalse);
  });
  test('非法 grant 目标或额外鉴权头拒绝发送', () async {
    var put = false;
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      if (path.endsWith('/register')) {
        return IMBoyHttpResponse.success({
          'object_key': 'private/key',
          'state': 'RESERVED',
        });
      }
      if (path.endsWith('/declare')) {
        return IMBoyHttpResponse.success({'state': 'DECLARED'});
      }
      if (path.endsWith('/grant')) {
        return IMBoyHttpResponse.success({
          'attempt_id': 1,
          'grant': {
            'transport': 's3_put',
            'url': 'http://outside.example/path',
            'method': 'PUT',
            'required_headers': [
              ['Authorization', 'unexpected'],
              ['x-amz-checksum-sha256', 'sha'],
            ],
          },
        });
      }
      throw StateError(path);
    }

    await expectLater(
      AttachmentApi.uploadViaPresign(
        Uint8List.fromList([1]),
        'a.png',
        'image/png',
        persistTask: false,
        directSessionFn: session,
        directPutFn: (_, _, _, _) async {
          put = true;
        },
      ),
      throwsStateError,
    );
    expect(put, isFalse);
  });
}
