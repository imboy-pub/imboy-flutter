part of 'group_album_photo_navigation_test.dart';

void groupAlbumPhotoAccessibilityTests() {
  group('图片格无障碍（多选收口回归）', () {
    testWidgets('非多选态：长按进多选暴露为自定义语义操作', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final fakeService = _FakeGroupAlbumService(
          photos: [
            {
              'id': 'legacy-1',
              'photo_id': 'p1',
              'thumbnail_url': '',
              'uploader_id': _currentUid,
            },
          ],
          photoDetails: const {},
        );
        GroupAlbumService.instanceForTest = fakeService;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: GroupAlbumPhotoPage(groupId: 'g1', albumId: 'a1'),
              builder: AppLoading.init(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 图片格没有文字，读屏只能靠语义。长按是纯手势，读屏用户做不出来，
        // 不挂自定义操作的话根本进不了多选。
        final cell = find.byKey(const Key('group_album_photo_cell_0'));
        expect(cell, findsOneWidget);

        final labels = tester
            .getSemantics(cell)
            .getSemanticsData()
            .customSemanticsActionIds
            ?.map((id) => CustomSemanticsAction.getAction(id)?.label)
            .whereType<String>()
            .toSet();

        expect(labels, isNotNull, reason: '图片格没有任何自定义语义操作');
        expect(labels, contains(t.main.multiSelect));
      } finally {
        handle.dispose();
      }
    });
  });

  testWidgets('photo tile is named and opens with Tab and Enter', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      GroupAlbumService.instanceForTest = _FakeGroupAlbumService(
        photos: const [
          {'id': '101', 'thumbnail_url': ''},
        ],
        photoDetails: const {},
      );
      String? openedPhoto;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const GroupAlbumPhotoPage(groupId: 'g1', albumId: 'a1'),
          ),
          GoRoute(
            path: '/group/:groupId/album/:albumId/photo/:photoId',
            builder: (_, state) {
              openedPhoto = state.pathParameters['photoId'];
              return const Scaffold(body: Text('opened-photo'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      final photo = find.bySemanticsLabel(
        '${t.group.groupAlbumPhotoDetailTitle} 1',
      );
      final photoData = tester.getSemantics(photo).getSemanticsData();
      expect(photoData.flagsCollection.isButton, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(openedPhoto, '101');
      expect(find.text('opened-photo'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'delete has an independent named target; selection respects reduced motion',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final fake = _FakeGroupAlbumService(
          photos: const [
            {'id': '101', 'uploader_id': _currentUid, 'thumbnail_url': ''},
          ],
          photoDetails: const {},
        );
        GroupAlbumService.instanceForTest = fake;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const GroupAlbumPhotoPage(groupId: 'g1', albumId: 'a1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final delete = find.byKey(const Key('group_album_photo_delete_0'));
        expect(tester.getSize(delete).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(delete).height, greaterThanOrEqualTo(44));
        final namedDelete = find.bySemanticsLabel(
          t.common.groupAlbumPhotoDeleteTitle,
        );
        final deleteData = tester.getSemantics(namedDelete).getSemanticsData();
        expect(deleteData.flagsCollection.isButton, isTrue);
        Focus.of(tester.element(find.byIcon(CupertinoIcons.delete)))
            .requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        expect(fake.deleteCalls, isEmpty);
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();

        final cell = find.byKey(const Key('group_album_photo_cell_0'));
        await tester.longPress(cell);
        await tester.pumpAndSettle();
        final selected = find.bySemanticsLabel(
          '${t.group.groupAlbumPhotoDetailTitle} 1',
        );
        final selectedData = tester.getSemantics(selected).getSemanticsData();
        expect(
          selectedData.flagsCollection.isSelected.toBoolOrNull() ?? false,
          isTrue,
        );
        final animations = tester.widgetList<AnimatedOpacity>(
          find.descendant(of: cell, matching: find.byType(AnimatedOpacity)),
        );
        expect(animations, isNotEmpty);
        expect(
          animations.every((animation) => animation.duration == Duration.zero),
          isTrue,
        );
        expect(
          find.byKey(const Key('group_album_photo_delete_0')),
          findsNothing,
        );
      } finally {
        handle.dispose();
      }
    },
  );
}
