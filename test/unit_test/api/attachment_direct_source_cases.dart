part of 'attachment_direct_api_test.dart';

void _registerDirectSourceTests({
  required IMBoyHttpResponse Function(String, int, String) grantPayload,
}) {
  test(
    'reopenable stream uses the same direct state machine and exact bytes',
    () async {
      final chunks = <List<int>>[
        [1, 2],
        [3, 4],
      ];
      final expected = [1, 2, 3, 4];
      var opens = 0;
      final source = DirectUploadSource(
        length: expected.length,
        openRead: () {
          opens++;
          return Stream.fromIterable(chunks);
        },
      );
      final actions = <String>[];
      final result = await DirectAttachmentApi.uploadSource(
        source,
        fileName: 'stream.png',
        mime: 'image/png',
        sessionFn: (path, {body}) async {
          final action = path.split('/').last;
          actions.add(action);
          switch (action) {
            case 'register':
              return IMBoyHttpResponse.success({
                'state': 'RESERVED',
                'object_key': 'u1/file/x',
              });
            case 'declare':
              expect(
                body!['sha256'],
                crypto.sha256.convert(expected).toString(),
              );
              expect(body['size_bytes'], expected.length);
              return IMBoyHttpResponse.success({'state': 'DECLARED'});
            case 'grant':
              return grantPayload(
                'https://s3.example/source',
                1,
                base64Encode(crypto.sha256.convert(expected).bytes),
              );
            case 'finalize':
              return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
            default:
              throw StateError(action);
          }
        },
        putFn:
            (url, material, length, headers, {cancelToken, onProgress}) async {
              expect(identical(material, source), isTrue);
              expect(
                await material
                    .openRead(cancelToken: cancelToken)
                    .expand((chunk) => chunk)
                    .toList(),
                expected,
              );
              expect(length, expected.length);
              expect(headers.length, 2);
            },
      );
      expect(result.state, 'CONFIRMED');
      expect(opens, 2);
      expect(actions, ['register', 'declare', 'grant', 'finalize']);
    },
  );

  test('byte source snapshots caller bytes and supports reopening', () async {
    final bytes = Uint8List.fromList([1, 2]);
    final source = DirectUploadSource.bytes(bytes);
    bytes[0] = 9;
    for (var i = 0; i < 2; i++) {
      expect(await source.openRead().expand((chunk) => chunk).toList(), [1, 2]);
    }
  });

  test('length mismatch fails before declare and cancels the source', () async {
    final actions = <String>[];
    final source = DirectUploadSource(
      length: 3,
      openRead: () => Stream.value([1, 2]),
    );
    await expectLater(
      DirectAttachmentApi.uploadSource(
        source,
        fileName: 'changed.png',
        mime: 'image/png',
        sessionFn: (path, {body}) async {
          actions.add(path.split('/').last);
          return IMBoyHttpResponse.success({
            'state': 'RESERVED',
            'object_key': 'u1/file/x',
          });
        },
      ),
      throwsStateError,
    );
    expect(actions, ['register']);
  });

  test(
    'cancel during stalled hash releases stream and never declares or PUTs',
    () async {
      final entered = Completer<void>();
      var closed = false;
      final input = StreamController<List<int>>(
        onListen: () => entered.complete(),
        onCancel: () => closed = true,
      );
      final cancel = CancelToken();
      final actions = <String>[];
      final upload = DirectAttachmentApi.uploadSource(
        DirectUploadSource(length: 2, openRead: () => input.stream),
        fileName: 'cancelled.png',
        mime: 'image/png',
        cancelToken: cancel,
        sessionFn: (path, {body}) async {
          actions.add(path.split('/').last);
          return IMBoyHttpResponse.success({
            'state': 'RESERVED',
            'object_key': 'u1/file/x',
          });
        },
      );
      final rejected = expectLater(
        upload,
        throwsA(isA<DirectUploadCancelled>()),
      );
      await entered.future;
      cancel.cancel('synthetic owner changed');
      await rejected;
      expect(closed, isTrue);
      expect(actions, ['register']);
      await input.close();
    },
  );

  test('source resume forwards the same cancellation token and suppresses finalize', () async {
    final bytes = Uint8List.fromList([5, 6]);
    final source = DirectUploadSource.bytes(bytes);
    final cancel = CancelToken();
    final actions = <String>[];
    await expectLater(
      DirectAttachmentApi.resumeSource(
        objectKey: 'u1/file/x',
        source: source,
        mime: 'image/png',
        cancelToken: cancel,
        sessionFn: (path, {body}) async {
          final action = path.split('/').last;
          actions.add(action);
          if (action == 'status') {
            return IMBoyHttpResponse.success({
              'state': 'GRANTED',
              'expected': {
                'sha256': crypto.sha256.convert(bytes).toString(),
                'size_bytes': '2',
                'mime': 'image/png',
              },
              'attempts': [<String, dynamic>{}],
            });
          }
          if (action == 'renew') {
            return grantPayload(
              'https://s3.example/resume',
              2,
              base64Encode(crypto.sha256.convert(bytes).bytes),
            );
          }
          throw StateError(action);
        },
        putFn:
            (url, material, length, headers, {cancelToken, onProgress}) async {
              expect(identical(cancelToken, cancel), isTrue);
              cancel.cancel('synthetic cancellation');
            },
      ),
      throwsA(isA<DirectUploadCancelled>()),
    );
    expect(actions, ['status', 'renew']);
  });
}
