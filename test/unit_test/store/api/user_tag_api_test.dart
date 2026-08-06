import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/user_tag_api.dart';

class _FakeUserTagApi extends UserTagApi {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserTagApi', () {
    test(
      'page should request API.userTagPage and return payload on success',
      () async {
        final api = _FakeUserTagApi();
        api.nextResponse = IMBoyHttpResponse.success({
          'items': [1, 2],
          'total': 2,
        });

        final result = await api.page(
          page: 2,
          size: 20,
          scene: 'friend',
          kwd: 'tom',
        );

        expect(result, isNotNull);
        expect(result?['total'], 2);
        expect(api.lastMethod, 'GET');
        expect(api.lastUri, API.userTagPage);
        expect(api.lastQuery, {
          'page': 2,
          'size': 20,
          'scene': 'friend',
          'kwd': 'tom',
        });
      },
    );

    test('page should return null on failure', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.failure(
        errCode: 500,
        errMsg: 'failed',
      );

      final result = await api.page();

      expect(result, isNull);
      expect(api.lastUri, API.userTagPage);
    });

    test(
      'relationAdd should post scene/objectId/tag and return true',
      () async {
        final api = _FakeUserTagApi();
        api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

        final ok = await api.relationAdd(
          objectId: 'u_123',
          tag: [1, 2],
          scene: 'friend',
        );

        expect(ok, isTrue);
        expect(api.lastMethod, 'POST');
        expect(api.lastUri, API.userTagRelationAdd);
        expect(api.lastData, {
          'scene': 'friend',
          'objectId': 'u_123',
          'tag': [1, 2],
        });
      },
    );

    test('changeName should post tag data and return true', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

      final ok = await api.changeName(
        scene: 'friend',
        tagId: 7,
        tagName: 'VIP',
      );

      expect(ok, isTrue);
      expect(api.lastUri, API.userTagChangeName);
      expect(api.lastData, {'scene': 'friend', 'tagId': 7, 'tagName': 'VIP'});
    });

    test('changeName should return false on non-ERROR failure code', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.failure(
        errCode: 500,
        errMsg: 'failed',
      );

      final ok = await api.changeName(
        scene: 'friend',
        tagId: 7,
        tagName: 'VIP',
      );

      expect(ok, isFalse);
      expect(api.lastUri, API.userTagChangeName);
    });

    test('deleteTag should post and return true', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

      final ok = await api.deleteTag(scene: 'collect', tagName: 'read_later');

      expect(ok, isTrue);
      expect(api.lastUri, API.userTagDelete);
      expect(api.lastData, {'scene': 'collect', 'tag': 'read_later'});
    });

    test('addTag should return payload tagId on success', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.success({'tagId': 88});

      final tagId = await api.addTag(scene: 'friend', tagName: 'core');

      expect(tagId, 88);
      expect(api.lastUri, API.userTagAdd);
      expect(api.lastData, {'scene': 'friend', 'tag': 'core'});
    });

    test('addTag should return 0 on non-ERROR failure code', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.failure(
        errCode: 500,
        errMsg: 'failed',
      );

      final tagId = await api.addTag(scene: 'friend', tagName: 'core');

      expect(tagId, 0);
      expect(api.lastUri, API.userTagAdd);
    });

    test('pageRelation should use collect route when scene=collect', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.success({'items': <dynamic>[]});

      await api.pageRelation(
        page: 1,
        size: 5,
        scene: 'collect',
        tagId: 9,
        kwd: 'a',
      );

      expect(api.lastMethod, 'GET');
      expect(api.lastUri, API.userTagRelationCollectPage);
      expect(api.lastQuery?['scene'], 'collect');
      expect(api.lastQuery?['tag_id'], 9);
      expect(api.lastQuery?['kwd'], 'a');
    });

    test('pageRelation should use friend route when scene=friend', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.success({'items': <dynamic>[]});

      await api.pageRelation(page: 3, size: 15, scene: 'friend', tagId: 6);

      expect(api.lastUri, API.userTagRelationFriendPage);
      expect(api.lastQuery?['page'], 3);
      expect(api.lastQuery?['size'], 15);
      expect(api.lastQuery?['scene'], 'friend');
      expect(api.lastQuery?['tag_id'], 6);
    });

    test(
      'pageRelation should fallback to friend route for unknown scene',
      () async {
        final api = _FakeUserTagApi();
        api.nextResponse = IMBoyHttpResponse.success({'items': <dynamic>[]});

        await api.pageRelation(page: 1, size: 10, scene: 'unknown', tagId: 1);

        expect(api.lastUri, API.userTagRelationFriendPage);
        expect(api.lastQuery?['scene'], 'unknown');
      },
    );

    test('removeRelation should post scene/tagId/objectId', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

      final ok = await api.removeRelation(
        tagId: 11,
        objectId: 'u_33',
        scene: 'friend',
      );

      expect(ok, isTrue);
      expect(api.lastUri, API.userTagRelationRemove);
      expect(api.lastData, {
        'scene': 'friend',
        'tagId': 11,
        'objectId': 'u_33',
      });
    });

    test('setRelation should post scene/tag and objectIds', () async {
      final api = _FakeUserTagApi();
      api.nextResponse = IMBoyHttpResponse.success(<String, dynamic>{});

      final ok = await api.setRelation(
        scene: 'friend',
        tagId: 5,
        tagName: 'close',
        objectIds: const ['u1', 'u2'],
      );

      expect(ok, isTrue);
      expect(api.lastUri, API.userTagRelationSet);
      expect(api.lastData, {
        'scene': 'friend',
        'tagId': 5,
        'tagName': 'close',
        'objectIds': ['u1', 'u2'],
      });
    });
  });
}
