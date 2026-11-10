part of 'group_direct_upload_test.dart';

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

void _registerGroupCleanupTests(
  File Function(String, List<int>) writeFile,
  DirectSessionFn Function(List<String>) sessionFor,
) {
  test(
    'group file cleanup waits for bind response and rejects its late result',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final actions = <String>[];
      final upload = GroupFileApi().uploadFileDirect(
        groupId: '3001',
        file: writeFile('cleanup.pdf', [1, 2, 3]),
        fileName: 'cleanup.pdf',
        mime: 'application/pdf',
        sessionFn: sessionFor(actions),
        putFn: (_, file, length, headers) async {},
        bindFn: (_) async {
          entered.complete();
          await release.future;
          return IMBoyHttpResponse.success({'file_id': 'late-file'});
        },
      );
      final failed = expectLater(
        upload,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await entered.future;
      final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(
        AccountLocalTaskOwner.capture(),
      );
      var stopped = false;
      final drained = cleanup.stopped.then((_) => stopped = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(stopped, isFalse);
        release.complete();
        await failed;
        await drained;
        expect(actions, ['register', 'declare', 'grant', 'finalize']);
      } finally {
        if (!release.isCompleted) release.complete();
        await failed;
        await drained;
        cleanup.release();
      }
    },
  );

  test(
    'album cleanup drains the current PUT and prevents later uploads and binds',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final actions = <String>[];
      var puts = 0, binds = 0;
      final upload = GroupAlbumApi().uploadPhotosDirect(
        groupId: '3001',
        albumId: 'album-cleanup',
        items: [
          for (var i = 0; i < 2; i++)
            GroupAlbumUploadItem(
              file: writeFile('cleanup-$i.png', [i + 1]),
              photoName: 'cleanup-$i.png',
              clientUploadId: 'cleanup-photo-$i',
            ),
        ],
        sessionFn: sessionFor(actions),
        putFn: (_, file, length, headers) async {
          puts++;
          entered.complete();
          await release.future;
        },
        bindBatchFn: (_) async {
          binds++;
          return IMBoyHttpResponse.success({
            'results': <Map<String, dynamic>>[],
          });
        },
      );
      final failed = expectLater(
        upload,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await entered.future;
      final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(
        AccountLocalTaskOwner.capture(),
      );
      var stopped = false;
      final drained = cleanup.stopped.then((_) => stopped = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(stopped, isFalse);
        release.complete();
        await failed;
        await drained;
        expect(puts, 1);
        expect(binds, 0);
        expect(actions, ['register', 'declare', 'grant']);
      } finally {
        if (!release.isCompleted) release.complete();
        await failed;
        await drained;
        cleanup.release();
      }
    },
  );
}
