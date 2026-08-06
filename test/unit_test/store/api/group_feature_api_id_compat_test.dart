import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/store/api/group_album_api.dart';
import 'package:imboy/store/api/group_file_api.dart';
import 'package:imboy/store/api/group_schedule_api.dart';
import 'package:imboy/store/api/group_task_api.dart';

class _FakeGroupScheduleApi extends GroupScheduleApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'GET';
    lastUri = uri;
    lastQuery = queryParameters;
    return nextResponse;
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'POST';
    lastUri = uri;
    lastData = data;
    lastQuery = queryParameters;
    return nextResponse;
  }
}

class _FakeGroupTaskApi extends GroupTaskApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'GET';
    lastUri = uri;
    lastQuery = queryParameters;
    return nextResponse;
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'POST';
    lastUri = uri;
    lastData = data;
    lastQuery = queryParameters;
    return nextResponse;
  }
}

class _FakeGroupFileApi extends GroupFileApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'GET';
    lastUri = uri;
    lastQuery = queryParameters;
    return nextResponse;
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'POST';
    lastUri = uri;
    lastData = data;
    lastQuery = queryParameters;
    return nextResponse;
  }
}

class _FakeGroupAlbumApi extends GroupAlbumApi {
  String? lastMethod;
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  int requestCount = 0;
  IMBoyHttpResponse nextResponse = IMBoyHttpResponse.success(
    <String, dynamic>{},
  );

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'GET';
    lastUri = uri;
    lastQuery = queryParameters;
    return nextResponse;
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requestCount++;
    lastMethod = 'POST';
    lastUri = uri;
    lastData = data;
    lastQuery = queryParameters;
    return nextResponse;
  }
}

void main() {
  group('GroupScheduleApi schedule_id compatibility', () {
    test(
      'getSchedule should forward legacy/uid schedule_id as string',
      () async {
        final api = _FakeGroupScheduleApi();
        api.nextResponse = IMBoyHttpResponse.success({
          'schedule': {'start_at': '1735689600'},
        });

        final result = await api.getSchedule(
          groupId: 'group_test_id',
          scheduleId: 'sched_abc123',
        );

        expect(result, isNotNull);
        expect(api.lastMethod, 'GET');
        expect(api.lastUri, '/api/v1/group_schedule/detail');
        expect(api.lastQuery?['group_id'], 'group_test_id');
        expect(api.lastQuery?['schedule_id'], 'sched_abc123');
      },
    );

    test(
      'cancelSchedule should accept numeric id and normalize to string',
      () async {
        final api = _FakeGroupScheduleApi();

        final ok = await api.cancelSchedule(groupId: 'gid_x', scheduleId: 42);

        expect(ok, isTrue);
        expect(api.lastMethod, 'POST');
        expect(api.lastUri, '/api/v1/group_schedule/cancel');
        expect(api.lastData['schedule_id'], '42');
      },
    );

    test(
      'confirmSchedule should short-circuit when schedule_id is empty',
      () async {
        final api = _FakeGroupScheduleApi();

        final ok = await api.confirmSchedule(
          groupId: 'gid_x',
          scheduleId: '',
          confirm: true,
        );

        expect(ok, isFalse);
        expect(api.requestCount, 0);
      },
    );
  });

  group('GroupTaskApi task_id compatibility', () {
    test('getTask should pass legacy task_id without int parsing', () async {
      final api = _FakeGroupTaskApi();
      api.nextResponse = IMBoyHttpResponse.success({'id': 'x'});

      final result = await api.getTask(groupId: 'gid_x', taskId: 'hZ9Pq1');

      expect(result, isNotNull);
      expect(api.lastMethod, 'GET');
      expect(api.lastUri, '/api/v1/group/task/detail');
      expect(api.lastQuery?['task_id'], 'hZ9Pq1');
    });

    test('submitTask should prefer task_uid style id strings', () async {
      final api = _FakeGroupTaskApi();

      final ok = await api.submitTask(
        groupId: 'gid_x',
        taskId: 'task_7f1b',
        content: 'done',
      );

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group/task/submit');
      expect(api.lastData['task_id'], 'task_7f1b');
      expect(api.lastData['content'], 'done');
    });

    test('reviewTask should forward assignment_id as string', () async {
      final api = _FakeGroupTaskApi();

      final ok = await api.reviewTask(
        groupId: 'gid_x',
        taskId: 'assign_test_id',
        status: 1,
      );

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group/task/review');
      expect(api.lastData['assignment_id'], 'assign_test_id');
      expect(api.lastData['score'], 1);
    });

    test('updateTask should return false for empty task id', () async {
      final api = _FakeGroupTaskApi();

      final ok = await api.updateTask(
        groupId: 'gid_x',
        taskId: '',
        title: 'new title',
      );

      expect(ok, isFalse);
      expect(api.requestCount, 0);
    });
  });

  group('GroupFileApi compatibility', () {
    test('getFiles should pass gid and optional category query', () async {
      final api = _FakeGroupFileApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'list': [
          {'id': 11, 'file_id': 'file_11'},
        ],
        'total': 1,
        'page': 1,
        'size': 20,
      });

      final result = await api.getFiles(
        groupId: 'gid_test_id',
        page: 2,
        size: 10,
        category: 'doc',
      );

      expect(api.lastMethod, 'GET');
      expect(api.lastUri, '/api/v1/group/file/list');
      expect(api.lastQuery?['gid'], 'gid_test_id');
      expect(api.lastQuery?['page'], 2);
      expect(api.lastQuery?['size'], 10);
      expect(api.lastQuery?['category'], 'doc');
      expect(result['total'], 1);
      expect((result['list'] as List).length, 1);
    });

    test(
      'getFiles should normalize payload items when list is absent',
      () async {
        final api = _FakeGroupFileApi();
        api.nextResponse = IMBoyHttpResponse.success({
          'items': [
            {'id': '7', 'file_id': 'f7'},
          ],
        });

        final result = await api.getFiles(groupId: 'g1');

        expect((result['list'] as List).length, 1);
        expect(result['total'], 1);
      },
    );

    test('deleteFile should short-circuit for empty id', () async {
      final api = _FakeGroupFileApi();
      final ok = await api.deleteFile('');
      expect(ok, isFalse);
      expect(api.requestCount, 0);
    });

    test('deleteFile should post file_id as string', () async {
      final api = _FakeGroupFileApi();
      final ok = await api.deleteFile(11);
      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group/file/delete');
      expect(api.lastData['file_id'], '11');
    });

    test(
      'getCategoryStats should call categories endpoint and normalize ints',
      () async {
        final api = _FakeGroupFileApi();
        api.nextResponse = IMBoyHttpResponse.success({
          'items': [
            {'category': 'document', 'count': '2', 'total_size': '1024'},
          ],
        });

        final stats = await api.getCategoryStats(groupId: 'gid_test_id');

        expect(api.lastMethod, 'GET');
        expect(api.lastUri, '/api/v1/group/file/categories');
        expect(api.lastQuery?['gid'], 'gid_test_id');
        expect(stats.length, 1);
        expect(stats.first['category'], 'document');
        expect(stats.first['count'], 2);
        expect(stats.first['total_size'], 1024);
      },
    );

    test('searchFiles should pass gid keyword and pagination', () async {
      final api = _FakeGroupFileApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'items': [
          {'id': 8, 'file_id': 'file_8'},
        ],
      });

      final result = await api.searchFiles(
        groupId: 'gid_test_id',
        keyword: '设计文档',
        page: 2,
        size: 5,
      );

      expect(api.lastMethod, 'GET');
      expect(api.lastUri, '/api/v1/group/file/search');
      expect(api.lastQuery?['gid'], 'gid_test_id');
      expect(api.lastQuery?['keyword'], '设计文档');
      expect(api.lastQuery?['page'], 2);
      expect(api.lastQuery?['size'], 5);
      expect((result['list'] as List).length, 1);
      expect(result['total'], 1);
    });

    test('searchFiles should short-circuit when keyword is empty', () async {
      final api = _FakeGroupFileApi();
      final result = await api.searchFiles(
        groupId: 'gid_test_id',
        keyword: '  ',
      );

      expect((result['list'] as List).length, 0);
      expect(result['total'], 0);
      expect(api.requestCount, 0);
    });

    test('uploadFile should short-circuit for empty bytes', () async {
      final api = _FakeGroupFileApi();
      final result = await api.uploadFile(
        groupId: 'gid_test_id',
        fileName: 'a.txt',
        fileBytes: const [],
      );
      expect(result, isNull);
      expect(api.requestCount, 0);
    });

    test(
      'uploadFile should post multipart payload with gid and file',
      () async {
        final api = _FakeGroupFileApi();
        api.nextResponse = IMBoyHttpResponse.success({
          'file_id': 'oss_001',
          'file_name': 'a.txt',
        });

        final result = await api.uploadFile(
          groupId: 'gid_test_id',
          fileName: 'a.txt',
          fileBytes: const [1, 2, 3],
          fileType: 'text/plain',
        );

        expect(result, isNotNull);
        expect(api.lastMethod, 'POST');
        expect(api.lastUri, '/api/v1/group/file/upload');
        final formData = api.lastData as FormData;
        final fields = Map<String, String>.fromEntries(formData.fields);
        expect(fields['gid'], 'gid_test_id');
        expect(fields['file_name'], 'a.txt');
        expect(fields['file_type'], 'text/plain');
        expect(formData.files.any((entry) => entry.key == 'file'), isTrue);
      },
    );
  });

  group('GroupAlbumApi compatibility', () {
    test('getAlbums should pass gid and pagination', () async {
      final api = _FakeGroupAlbumApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'list': [
          {'id': 5, 'album_id': 'alb_5'},
        ],
        'total': 1,
      });

      final result = await api.getAlbums(
        groupId: 'gid_test_id',
        page: 3,
        size: 15,
      );

      expect(api.lastMethod, 'GET');
      expect(api.lastUri, '/api/v1/group_album/list');
      expect(api.lastQuery?['gid'], 'gid_test_id');
      expect(api.lastQuery?['page'], 3);
      expect(api.lastQuery?['size'], 15);
      expect((result['list'] as List).length, 1);
      expect(result['total'], 1);
    });

    test('getAlbums should accept payload items key', () async {
      final api = _FakeGroupAlbumApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'items': [
          {'id': '9', 'album_id': 'alb_9'},
        ],
      });

      final result = await api.getAlbums(groupId: 'gid_x');

      expect((result['list'] as List).length, 1);
      expect(result['total'], 1);
    });

    test('deleteAlbum should short-circuit for null', () async {
      final api = _FakeGroupAlbumApi();
      final ok = await api.deleteAlbum(null);
      expect(ok, isFalse);
      expect(api.requestCount, 0);
    });

    test('deleteAlbum should post album_id as string', () async {
      final api = _FakeGroupAlbumApi();
      final ok = await api.deleteAlbum('alb_test_id');
      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group_album/delete');
      expect(api.lastData['album_id'], 'alb_test_id');
    });

    test('createAlbum should post gid and album_name', () async {
      final api = _FakeGroupAlbumApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'album_id': 'alb_test_id',
        'album_name': '项目资料',
      });

      final result = await api.createAlbum(
        groupId: 'gid_test_id',
        albumName: '项目资料',
      );

      expect(result, isNotNull);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group_album/create');
      expect(api.lastData['gid'], 'gid_test_id');
      expect(api.lastData['album_name'], '项目资料');
    });

    test('createAlbum should short-circuit for blank album name', () async {
      final api = _FakeGroupAlbumApi();
      final result = await api.createAlbum(
        groupId: 'gid_test_id',
        albumName: '   ',
      );

      expect(result, isNull);
      expect(api.requestCount, 0);
    });

    test('renameAlbum should post album_id and album_name', () async {
      final api = _FakeGroupAlbumApi();
      final ok = await api.renameAlbum(
        albumId: 'alb_test_id',
        albumName: '新名字',
      );

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group_album/rename');
      expect(api.lastData['album_id'], 'alb_test_id');
      expect(api.lastData['album_name'], '新名字');
    });

    test('renameAlbum should short-circuit for blank album name', () async {
      final api = _FakeGroupAlbumApi();
      final ok = await api.renameAlbum(albumId: 'alb_test_id', albumName: ' ');

      expect(ok, isFalse);
      expect(api.requestCount, 0);
    });

    test('uploadPhoto should short-circuit for blank album_id', () async {
      final api = _FakeGroupAlbumApi();
      final result = await api.uploadPhoto(
        groupId: 'gid_test_id',
        albumId: '  ',
        photoName: 'a.jpg',
        photoBytes: const [1, 2, 3],
      );

      expect(result, isNull);
      expect(api.requestCount, 0);
    });

    test('uploadPhoto should post multipart payload', () async {
      final api = _FakeGroupAlbumApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'photo_id': 'photo_001',
        'photo_name': 'a.jpg',
      });

      final result = await api.uploadPhoto(
        groupId: 'gid_test_id',
        albumId: 'alb_test_id',
        photoName: 'a.jpg',
        photoBytes: const [1, 2, 3, 4],
      );

      expect(result, isNotNull);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group_album/photo/upload');
      final formData = api.lastData as FormData;
      final fields = Map<String, String>.fromEntries(formData.fields);
      expect(fields['gid'], 'gid_test_id');
      expect(fields['album_id'], 'alb_test_id');
      expect(fields['photo_name'], 'a.jpg');
      expect(formData.files.any((entry) => entry.key == 'photo'), isTrue);
    });

    test('getPhotos should call album photo list endpoint', () async {
      final api = _FakeGroupAlbumApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'items': [
          {'id': 101, 'photo_url': 'https://img.example/p1.jpg'},
        ],
        'total': 1,
      });

      final result = await api.getPhotos(
        albumId: 'alb_test_id',
        page: 2,
        size: 6,
      );

      expect(api.lastMethod, 'GET');
      expect(api.lastUri, '/api/v1/group_album/photo/list');
      expect(api.lastQuery?['album_id'], 'alb_test_id');
      expect(api.lastQuery?['page'], 2);
      expect(api.lastQuery?['size'], 6);
      expect((result['list'] as List).length, 1);
      expect(result['total'], 1);
    });

    test('getPhotos should short-circuit when album id is blank', () async {
      final api = _FakeGroupAlbumApi();
      final result = await api.getPhotos(albumId: '  ');
      expect((result['list'] as List).length, 0);
      expect(result['total'], 0);
      expect(api.requestCount, 0);
    });

    test('getPhotoDetail should call detail endpoint', () async {
      final api = _FakeGroupAlbumApi();
      api.nextResponse = IMBoyHttpResponse.success({
        'id': 101,
        'photo_url': 'https://img.example/p1.jpg',
      });

      final detail = await api.getPhotoDetail('101');

      expect(detail, isNotNull);
      expect(api.lastMethod, 'GET');
      expect(api.lastUri, '/api/v1/group_album/photo/detail');
      expect(api.lastQuery?['photo_id'], '101');
      expect(detail?['id'], 101);
    });

    test('getPhotoDetail should short-circuit for null id', () async {
      final api = _FakeGroupAlbumApi();
      final detail = await api.getPhotoDetail(null);
      expect(detail, isNull);
      expect(api.requestCount, 0);
    });

    test('deletePhoto should post numeric photo id as string', () async {
      final api = _FakeGroupAlbumApi();
      final ok = await api.deletePhoto(101);
      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group_album/photo/delete');
      expect(api.lastData['photo_id'], '101');
    });

    test('updateAlbumCover should post album_id and photo_id', () async {
      final api = _FakeGroupAlbumApi();
      final ok = await api.updateAlbumCover(albumId: 9, photoId: '101');

      expect(ok, isTrue);
      expect(api.lastMethod, 'POST');
      expect(api.lastUri, '/api/v1/group_album/cover/update');
      expect(api.lastData['album_id'], '9');
      expect(api.lastData['photo_id'], '101');
    });

    test(
      'updateAlbumCover should short-circuit when album id is blank',
      () async {
        final api = _FakeGroupAlbumApi();
        final ok = await api.updateAlbumCover(albumId: ' ', photoId: '101');

        expect(ok, isFalse);
        expect(api.requestCount, 0);
      },
    );
  });
}
