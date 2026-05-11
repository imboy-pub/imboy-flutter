import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/group/album/group_album_photo_detail_page.dart';
import 'package:imboy/page/group/album/group_album_photo_page.dart';
import 'package:imboy/service/group_album_service.dart';
import 'package:imboy/store/api/group_album_api.dart';

class _FakeGroupAlbumService extends GroupAlbumService {
  _FakeGroupAlbumService({
    required this.photos,
    required this.photoDetails,
    this.deleteResult = true,
    this.updateCoverResult = true,
  }) : super.withApi(GroupAlbumApi());

  final List<Map<String, dynamic>> photos;
  final Map<String, Map<String, dynamic>> photoDetails;
  final bool deleteResult;
  final bool updateCoverResult;
  final List<String> detailCalls = [];
  final List<String> deleteCalls = [];
  final List<String> updateCoverCalls = [];
  int getPhotosCallCount = 0;

  @override
  Future<Map<String, dynamic>> getPhotos({
    required String albumId,
    int page = 1,
    int size = 20,
  }) async {
    getPhotosCallCount++;
    return {'list': photos, 'total': photos.length, 'page': page, 'size': size};
  }

  @override
  Future<Map<String, dynamic>?> getPhotoDetail(dynamic photoId) async {
    final id = photoId?.toString() ?? '';
    detailCalls.add(id);
    return photoDetails[id];
  }

  @override
  Future<bool> deletePhoto(dynamic photoId) async {
    deleteCalls.add(photoId?.toString() ?? '');
    return deleteResult;
  }

  @override
  Future<bool> updateAlbumCover({required albumId, required photoId}) async {
    final aid = albumId?.toString() ?? '';
    final pid = photoId?.toString() ?? '';
    updateCoverCalls.add('$aid:$pid');
    return updateCoverResult;
  }
}

class _DetailDeleteHost extends StatefulWidget {
  const _DetailDeleteHost();

  @override
  State<_DetailDeleteHost> createState() => _DetailDeleteHostState();
}

class _DetailDeleteHostState extends State<_DetailDeleteHost> {
  String resultText = 'result:none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(resultText),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<dynamic>(
                  builder: (_) => const GroupAlbumPhotoDetailPage(
                    groupId: 'g1',
                    albumId: 'a1',
                    photoId: 'p1',
                    albumName: 'Album',
                    photoIds: ['p1'],
                    initialIndex: 0,
                  ),
                ),
              );
              if (!mounted) return;
              setState(() {
                resultText = 'result:${result ?? 'null'}';
              });
            },
            child: const Text('open-detail'),
          ),
        ],
      ),
    );
  }
}

void main() {
  tearDown(() {
    GroupAlbumService.instanceForTest = null;
  });

  testWidgets('photo list pushes detail route with photo_ids and index extra', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: [
        {'id': 'legacy-1', 'photo_id': 'p1', 'thumbnail_url': ''},
        {'id': 'legacy-2', 'photo_id': 'p2', 'thumbnail_url': ''},
      ],
      photoDetails: const {},
    );
    GroupAlbumService.instanceForTest = fakeService;

    Map<String, dynamic>? capturedExtra;
    String? capturedPhotoId;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const GroupAlbumPhotoPage(
            groupId: 'g1',
            albumId: 'a1',
            albumName: 'Album',
          ),
        ),
        GoRoute(
          path: '/group/:groupId/album/:albumId/photo/:photoId',
          builder: (context, state) {
            capturedExtra = state.extra as Map<String, dynamic>?;
            capturedPhotoId = state.pathParameters['photoId'];
            return const Scaffold(body: Text('detail-page'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final firstPhotoCell = find.byKey(const Key('group_album_photo_cell_0'));
    expect(firstPhotoCell, findsOneWidget);
    await tester.tap(firstPhotoCell);
    await tester.pumpAndSettle();

    expect(find.text('detail-page'), findsOneWidget);
    expect(capturedPhotoId, 'p1');
    expect(capturedExtra, isNotNull);
    expect(capturedExtra!['index'], 0);
    expect(capturedExtra!['photo_ids'], ['p1', 'p2']);
  });

  testWidgets('photo delete uses photo_id and refreshes on success', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [
        {'id': 'legacy-1', 'photo_id': 'p1', 'thumbnail_url': ''},
      ],
      photoDetails: const {},
      deleteResult: true,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoPage(
            groupId: 'g1',
            albumId: 'a1',
            albumName: 'A',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fakeService.getPhotosCallCount, 1);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

    expect(fakeService.deleteCalls, ['p1']);
    expect(find.text('图片已删除'), findsOneWidget);
    expect(fakeService.getPhotosCallCount, 2);
  });

  testWidgets('photo delete failure keeps list without refresh', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [
        {'id': 'legacy-1', 'photo_id': 'p1', 'thumbnail_url': ''},
      ],
      photoDetails: const {},
      deleteResult: false,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoPage(
            groupId: 'g1',
            albumId: 'a1',
            albumName: 'A',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fakeService.getPhotosCallCount, 1);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

    expect(fakeService.deleteCalls, ['p1']);
    expect(find.text('删除失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getPhotosCallCount, 1);
  });

  testWidgets('batch delete selected photos and refreshes on success', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [
        {'id': 'legacy-1', 'photo_id': 'p1', 'thumbnail_url': ''},
        {'id': 'legacy-2', 'photo_id': 'p2', 'thumbnail_url': ''},
      ],
      photoDetails: const {},
      deleteResult: true,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoPage(
            groupId: 'g1',
            albumId: 'a1',
            albumName: 'A',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fakeService.getPhotosCallCount, 1);

    final firstPhotoCell = find.byKey(const Key('group_album_photo_cell_0'));
    final secondPhotoCell = find.byKey(const Key('group_album_photo_cell_1'));
    await tester.longPress(firstPhotoCell);
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.tap(secondPhotoCell);
    await tester.pumpAndSettle();
    expect(find.text('已选择 2 项'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group_album_photo_batch_delete')));
    await tester.pumpAndSettle();
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

    expect(fakeService.deleteCalls, unorderedEquals(['p1', 'p2']));
    expect(find.text('已删除2张图片'), findsOneWidget);
    expect(fakeService.getPhotosCallCount, 2);
  });

  testWidgets('batch delete failure shows snackbar without refresh', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [
        {'id': 'legacy-1', 'photo_id': 'p1', 'thumbnail_url': ''},
        {'id': 'legacy-2', 'photo_id': 'p2', 'thumbnail_url': ''},
      ],
      photoDetails: const {},
      deleteResult: false,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoPage(
            groupId: 'g1',
            albumId: 'a1',
            albumName: 'A',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fakeService.getPhotosCallCount, 1);

    final firstPhotoCell = find.byKey(const Key('group_album_photo_cell_0'));
    final secondPhotoCell = find.byKey(const Key('group_album_photo_cell_1'));
    await tester.longPress(firstPhotoCell);
    await tester.pumpAndSettle();
    await tester.tap(secondPhotoCell);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group_album_photo_batch_delete')));
    await tester.pumpAndSettle();
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

    expect(fakeService.deleteCalls, unorderedEquals(['p1', 'p2']));
    expect(find.text('删除失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getPhotosCallCount, 1);
  });

  testWidgets(
    'photo detail supports prev and next navigation with boundaries',
    (tester) async {
      final fakeService = _FakeGroupAlbumService(
        photos: const [],
        photoDetails: {
          'p1': {'photo_id': 'p1', 'photo_name': 'Photo1'},
          'p2': {'photo_id': 'p2', 'photo_name': 'Photo2'},
          'p3': {'photo_id': 'p3', 'photo_name': 'Photo3'},
        },
      );
      GroupAlbumService.instanceForTest = fakeService;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GroupAlbumPhotoDetailPage(
              groupId: 'g1',
              albumId: 'a1',
              photoId: 'p2',
              albumName: 'Album',
              photoIds: ['p1', 'p2', 'p3'],
              initialIndex: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Album 2/3'), findsOneWidget);
      expect(fakeService.detailCalls, ['p2']);

      await tester.tap(find.byTooltip('下一张'));
      await tester.pumpAndSettle();

      expect(find.text('Album 3/3'), findsOneWidget);
      expect(fakeService.detailCalls, ['p2', 'p3']);

      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(nextButton.onPressed, isNull);

      await tester.tap(find.byTooltip('上一张'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('上一张'));
      await tester.pumpAndSettle();

      expect(find.text('Album 1/3'), findsOneWidget);
      expect(fakeService.detailCalls, ['p2', 'p3', 'p2', 'p1']);
      final prevButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(prevButton.onPressed, isNull);
    },
  );

  testWidgets('photo detail open external shows snackbar when url missing', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [],
      photoDetails: {
        'p1': {'photo_id': 'p1', 'photo_name': 'Photo1'},
      },
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoDetailPage(
            groupId: 'g1',
            albumId: 'a1',
            photoId: 'p1',
            albumName: 'Album',
            photoIds: ['p1'],
            initialIndex: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('外部打开'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('外部打开'));
    await tester.pump();

    expect(find.text('图片地址缺失，无法打开'), findsOneWidget);
  });

  testWidgets('photo detail open external shows snackbar when url invalid', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [],
      photoDetails: {
        'p1': {
          'photo_id': 'p1',
          'photo_name': 'Photo1',
          'photo_url': 'http://[',
        },
      },
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoDetailPage(
            groupId: 'g1',
            albumId: 'a1',
            photoId: 'p1',
            albumName: 'Album',
            photoIds: ['p1'],
            initialIndex: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('外部打开'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('外部打开'));
    await tester.pump();

    expect(find.text('图片地址无效'), findsOneWidget);
  });

  testWidgets('photo detail set cover success shows snackbar', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [],
      photoDetails: {
        'p1': {'photo_id': 'p1', 'photo_name': 'Photo1'},
      },
      updateCoverResult: true,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoDetailPage(
            groupId: 'g1',
            albumId: 'a1',
            photoId: 'p1',
            albumName: 'Album',
            photoIds: ['p1'],
            initialIndex: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('设为封面'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为封面'));
    await tester.pumpAndSettle();

    expect(fakeService.updateCoverCalls, ['a1:p1']);
    expect(find.text('已设为相册封面'), findsOneWidget);
  });

  testWidgets('photo detail set cover failure shows snackbar', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [],
      photoDetails: {
        'p1': {'photo_id': 'p1', 'photo_name': 'Photo1'},
      },
      updateCoverResult: false,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GroupAlbumPhotoDetailPage(
            groupId: 'g1',
            albumId: 'a1',
            photoId: 'p1',
            albumName: 'Album',
            photoIds: ['p1'],
            initialIndex: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('设为封面'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为封面'));
    await tester.pumpAndSettle();

    expect(fakeService.updateCoverCalls, ['a1:p1']);
    expect(find.text('设置封面失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('photo detail delete success pops with true result', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [],
      photoDetails: {
        'p1': {'photo_id': 'p1', 'photo_name': 'Photo1'},
      },
      deleteResult: true,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _DetailDeleteHost())),
    );
    await tester.pumpAndSettle();
    expect(find.text('result:none'), findsOneWidget);

    await tester.tap(find.text('open-detail'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('删除图片'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除图片'));
    await tester.pumpAndSettle();

    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

    expect(fakeService.deleteCalls, ['p1']);
    expect(find.text('result:true'), findsOneWidget);
  });

  testWidgets('photo detail delete failure shows snackbar and stays', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      photos: const [],
      photoDetails: {
        'p1': {'photo_id': 'p1', 'photo_name': 'Photo1'},
      },
      deleteResult: false,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _DetailDeleteHost())),
    );
    await tester.pumpAndSettle();
    expect(find.text('result:none'), findsOneWidget);

    await tester.tap(find.text('open-detail'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('删除图片'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除图片'));
    await tester.pumpAndSettle();

    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

    expect(fakeService.deleteCalls, ['p1']);
    expect(find.text('删除失败，请稍后重试'), findsOneWidget);
    expect(find.text('result:none'), findsNothing);
    expect(find.text('Album 1/1'), findsOneWidget);
  });
}
