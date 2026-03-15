import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/page/group/album/group_album_photo_detail_page.dart';
import 'package:imboy/service/group_album_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/group_album_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGroupAlbumService extends GroupAlbumService {
  _FakeGroupAlbumService() : super.withApi(GroupAlbumApi());

  @override
  Future<Map<String, dynamic>?> getPhotoDetail(dynamic photoId) async {
    final id = photoId?.toString() ?? '';
    return {'photo_id': id, 'photo_name': id, 'photo_url': ''};
  }
}

Future<GroupAlbumPhotoDetailPage> _pumpAtDetailRoute(
  WidgetTester tester, {
  Object? extra,
}) async {
  SharedPreferences.setMockInitialValues({Keys.currentUid: 'u_test'});
  await StorageService.init();
  GroupAlbumService.instanceForTest = _FakeGroupAlbumService();

  final container = ProviderContainer();
  addTearDown(container.dispose);

  final router = container.read(goRouterProvider);
  addTearDown(router.dispose);

  router.go('/group/g1/album/a1/photo/p2?album_name=Album', extra: extra);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return tester.widget<GroupAlbumPhotoDetailPage>(
    find.byType(GroupAlbumPhotoDetailPage),
  );
}

void main() {
  tearDown(() {
    GroupAlbumService.instanceForTest = null;
  });

  testWidgets('detail route uses defaults when extra is missing', (
    tester,
  ) async {
    final detail = await _pumpAtDetailRoute(tester);

    expect(detail.groupId, 'g1');
    expect(detail.albumId, 'a1');
    expect(detail.photoId, 'p2');
    expect(detail.albumName, 'Album');
    expect(detail.photoIds, isEmpty);
    expect(detail.initialIndex, 0);
  });

  testWidgets(
    'detail route parses photo_ids list and string index from extra',
    (tester) async {
      final detail = await _pumpAtDetailRoute(
        tester,
        extra: {
          'photo_ids': ['p1', ' ', null, 'p3', 7],
          'index': '2',
        },
      );

      expect(detail.photoIds, ['p1', 'p3', '7']);
      expect(detail.initialIndex, 2);
    },
  );

  testWidgets('detail route falls back when extra payload is invalid', (
    tester,
  ) async {
    final detail = await _pumpAtDetailRoute(
      tester,
      extra: {'photo_ids': 'not-a-list', 'index': 'invalid'},
    );

    expect(detail.photoIds, isEmpty);
    expect(detail.initialIndex, 0);
  });

  test('group album detail route is not gated by feature flags', () {
    expect(
      RouteFeatureGuard.featureForPath('/group/g1/album/a1/photo/p2'),
      isNull,
    );
  });
}
