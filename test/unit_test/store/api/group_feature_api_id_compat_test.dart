import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/service/group_album_service.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:imboy/store/api/group_album_api.dart';
import 'package:imboy/store/api/group_file_api.dart';
import 'package:imboy/store/api/group_schedule_api.dart';
import 'package:imboy/store/api/group_task_api.dart';

part 'group_feature_api_fixtures.dart';

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

    test('uploadFileDirect should short-circuit for blank gid', () async {
      final api = _FakeGroupFileApi();
      final dir = await Directory.systemTemp.createTemp('gf-compat');
      final file = File('${dir.path}/a.txt')..writeAsBytesSync(<int>[1, 2, 3]);
      addTearDown(() => dir.delete(recursive: true));

      final result = await api.uploadFileDirect(
        groupId: '  ',
        file: file,
        fileName: 'a.txt',
        mime: 'text/plain',
      );
      expect(result, isNull);
      expect(api.requestCount, 0);
    });

    test(
      'uploadFileDirect should drive direct session then JSON bind',
      () async {
        final api = _FakeGroupFileApi();
        final dir = await Directory.systemTemp.createTemp('gf-compat');
        final file = File('${dir.path}/a.txt')
          ..writeAsBytesSync(<int>[1, 2, 3]);
        addTearDown(() => dir.delete(recursive: true));

        api.postHandler = (String uri, dynamic data) {
          if (uri.endsWith('/attachment/direct/register')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'object_key': 'u1/group/x/a.txt',
              // 直传会话契约：register 响应必须携带 state（缺省会被判为
              // 终态直接抛 direct session terminal）。
              'state': 'RESERVED',
            });
          }
          if (uri.endsWith('/attachment/direct/declare')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'state': 'DECLARED',
            });
          }
          if (uri.endsWith('/attachment/direct/grant')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'state': 'GRANTED',
              'attempt_id': 1,
              'grant': <String, dynamic>{
                'transport': 's3_put',
                'url': 'https://s3.example/put',
                'method': 'PUT',
                'required_headers': <dynamic>[
                  <dynamic>['Content-Type', 'text/plain'],
                  <dynamic>['x-amz-checksum-sha256', 'YQ=='],
                ],
                'expires_in': 3600,
              },
            });
          }
          if (uri.endsWith('/attachment/direct/finalize')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'state': 'CONFIRMED',
              'attempt_id': 1,
            });
          }
          return IMBoyHttpResponse.success(<String, dynamic>{
            'file_id': 'oss_001',
            'file_name': 'a.txt',
          });
        };

        final result = await api.uploadFileDirect(
          groupId: 'gid_test_id',
          file: file,
          fileName: 'a.txt',
          mime: 'text/plain',
          putFn: (
            String url,
            File f,
            int length,
            Map<String, String> headers,
          ) async {},
        );

        expect(result, isNotNull);
        expect(result?['file_id'], 'oss_001');
        expect(api.lastMethod, 'POST');
        expect(api.lastUri, '/api/v1/group/file/bind');
        final body = api.lastData as Map<String, dynamic>;
        expect(body['gid'], 'gid_test_id');
        expect(body['file_name'], 'a.txt');
        expect(body['file_type'], 'text/plain');
        expect(body['object_key'], 'u1/group/x/a.txt');
        expect(body['file_size'], 3);
        // backend validate_bind_metadata：非空 file_md5 必被拒，只能空串
        expect(body['file_md5'], '');
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

    test(
      'uploadPhotosDirect should short-circuit for blank album_id',
      () async {
        final api = _FakeGroupAlbumApi();
        final dir = await Directory.systemTemp.createTemp('ga-compat');
        final file = File('${dir.path}/a.png')
          ..writeAsBytesSync(<int>[1, 2, 3]);
        addTearDown(() => dir.delete(recursive: true));

        final result = await api.uploadPhotosDirect(
          groupId: 'gid_test_id',
          albumId: '  ',
          items: [
            GroupAlbumUploadItem(
              file: file,
              photoName: 'a.png',
              clientUploadId: 'c-1',
            ),
          ],
        );

        expect(result, isEmpty);
        expect(api.requestCount, 0);
      },
    );

    test(
      'uploadPhotosDirect should direct-upload then bind_batch JSON',
      () async {
        final api = _FakeGroupAlbumApi();
        final dir = await Directory.systemTemp.createTemp('ga-compat');
        final file = File('${dir.path}/a.png')
          ..writeAsBytesSync(<int>[1, 2, 3, 4]);
        addTearDown(() => dir.delete(recursive: true));

        api.postHandler = (String uri, dynamic data) {
          if (uri.endsWith('/attachment/direct/register')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'object_key': 'u1/group/x/a.png',
              'state': 'RESERVED',
            });
          }
          if (uri.endsWith('/attachment/direct/declare')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'state': 'DECLARED',
            });
          }
          if (uri.endsWith('/attachment/direct/grant')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'state': 'GRANTED',
              'attempt_id': 1,
              'grant': <String, dynamic>{
                'transport': 's3_put',
                'url': 'https://s3.example/put',
                'method': 'PUT',
                'required_headers': <dynamic>[
                  <dynamic>['Content-Type', 'image/png'],
                  <dynamic>['x-amz-checksum-sha256', 'YQ=='],
                ],
                'expires_in': 3600,
              },
            });
          }
          if (uri.endsWith('/attachment/direct/finalize')) {
            return IMBoyHttpResponse.success(<String, dynamic>{
              'state': 'CONFIRMED',
              'attempt_id': 1,
            });
          }
          return IMBoyHttpResponse.success(<String, dynamic>{
            'results': <dynamic>[
              <String, dynamic>{
                'object_key': 'u1/group/x/a.png',
                'status': 'ok',
                'photo': <String, dynamic>{'photo_id': 'photo_001'},
              },
            ],
          });
        };

        final result = await api.uploadPhotosDirect(
          groupId: 'gid_test_id',
          albumId: 'alb_test_id',
          items: [
            GroupAlbumUploadItem(
              file: file,
              photoName: 'a.png',
              clientUploadId: 'c-2',
            ),
          ],
          putFn: (
            String url,
            File f,
            int length,
            Map<String, String> headers,
          ) async {},
        );

        expect(result, hasLength(1));
        expect(result.single.ok, isTrue);
        expect(result.single.photo?['photo_id'], 'photo_001');
        expect(api.lastMethod, 'POST');
        expect(api.lastUri, '/api/v1/group_album/photo/bind_batch');
        final body = api.lastData as Map<String, dynamic>;
        expect(body['gid'], 'gid_test_id');
        final items = body['items'] as List<dynamic>;
        expect(items, hasLength(1));
        expect(items.first['album_id'], 'alb_test_id');
        expect(items.first['photo_name'], 'a.png');
        expect(items.first['mime_type'], 'image/png');
        expect(items.first['object_key'], 'u1/group/x/a.png');
        expect(items.first['photo_size'], 4);
        expect(
          items.first['sha256'],
          await sha256OfFile(file),
          reason: 'bind_batch sha256 必须与 direct declare 同值',
        );
      },
    );

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

    test(
      'album service preserves large record ids through delete API',
      () async {
        final api = _FakeGroupAlbumApi();
        final service = GroupAlbumService.withApi(api);
        for (final photoId in [9007199254740993, '9223372036854775807']) {
          expect(await service.deletePhoto(photoId), isTrue);
          expect(api.lastMethod, 'POST');
          expect(api.lastUri, '/api/v1/group_album/photo/delete');
          expect(api.lastData['photo_id'], photoId.toString());
        }
        expect(api.requestCount, 2);
      },
    );

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
