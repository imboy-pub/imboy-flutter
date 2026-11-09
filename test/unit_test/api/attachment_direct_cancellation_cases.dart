part of 'attachment_direct_api_test.dart';

void _registerDirectCancellationTests({
  required File Function(String, List<int>) writeFile,
  required IMBoyHttpResponse Function(Map<String, dynamic>) ok,
  required IMBoyHttpResponse Function(String, int, String) grantPayload,
}) {
  test(
    'cancel token aborts a real waiting PUT without finalize or renewal',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final entered = Completer<void>();
      final release = Completer<void>();
      final served = server.first.then((request) async {
        await request.drain<void>();
        entered.complete();
        await release.future;
        try {
          await request.response.close();
        } on Object {
          // The client deliberately aborts this request.
        }
      });
      final actions = <String>[];
      final token = CancelToken();
      final file = writeFile('cancel.png', [1, 2, 3, 4]);
      final upload = DirectAttachmentApi.uploadFile(
        file,
        fileName: 'cancel.png',
        mime: 'image/png',
        cancelToken: token,
        sessionFn: (path, {body}) async {
          final action = path.split('/').last;
          actions.add(action);
          return switch (action) {
            'register' => ok({
              'object_key': 'u1/file/cancel',
              'state': 'RESERVED',
            }),
            'declare' => ok({'state': 'DECLARED'}),
            'grant' => grantPayload(
              'http://127.0.0.1:${server.port}/put',
              1,
              'YQ==',
            ),
            _ => throw StateError('unexpected request: $action'),
          };
        },
      );
      final failed = expectLater(upload, throwsA(isA<DirectUploadCancelled>()));
      try {
        await entered.future;
        token.cancel('account cleanup');
        await failed;
        expect(actions, ['register', 'declare', 'grant']);
      } finally {
        if (!release.isCompleted) release.complete();
        await server.close(force: true);
        await served;
      }
    },
  );
}
