part of 'group_file_page_test.dart';

void groupFileControlledOpenTests() {
  _boundFileFreshTest();
  _boundFileDeniedTest();
  _boundFileScopeChangeTest();
  _unboundFileTest();
}

void _unboundFileTest() {
  testWidgets('missing canonical binding never falls back to raw URL', (
    tester,
  ) async {
    GroupFileService.instanceForTest = _FakeGroupFileService(
      files: [
        {
          'id': '9',
          'file_name': '无绑定资料.pdf',
          'file_category': 'document',
          'object_key': null,
          'file_url': 'https://example.com/raw.pdf',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    var opens = 0;
    GroupFilePage.openWebPreviewForTest = (_, _, _) async {
      opens++;
    };
    GroupFilePage.openExternalForTest = (_, _) async {
      opens++;
      return true;
    };
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('无绑定资料.pdf'));
    await tester.pump();
    expect(opens, 0);
    expect(find.text(t.common.groupFileOpenFailed), findsOneWidget);
  });
}

void _boundFileFreshTest() {
  testWidgets('bound file opens with fresh signed URL instead of raw URL', (
    tester,
  ) async {
    const key = 'u1/file_1_a/doc.pdf';
    GroupFileService.instanceForTest = _FakeGroupFileService(
      files: [
        {
          'id': '9',
          'file_name': '受控资料.pdf',
          'file_category': 'document',
          'object_key': key,
          'file_url': 'https://example.com/raw.pdf',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    var requests = 0;
    AssetUrlResolver.instance.fetcherOverride = (value) async {
      expect(value, key);
      requests++;
      return 'https://example.com/signed.pdf?token=$requests';
    };
    await AssetUrlResolver.instance.resolve(key);
    String? opened;
    GroupFilePage.openWebPreviewForTest = (_, url, _) async {
      opened = url;
    };
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('受控资料.pdf'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(opened, 'https://example.com/signed.pdf?token=2');
  });
}

void _boundFileDeniedTest() {
  testWidgets(
    'authorization denial never opens cached URL or external fallback',
    (tester) async {
      const key = 'u1/file_1_a/doc.pdf';
      GroupFileService.instanceForTest = _FakeGroupFileService(
        files: [
          {
            'id': '9',
            'file_name': '失权资料.pdf',
            'file_category': 'document',
            'object_key': key,
            'file_url': 'https://example.com/raw.pdf',
          },
        ],
        categoryStats: const [],
        searchResult: const [],
      );
      AssetUrlResolver.instance.fetcherOverride = (_) async =>
          'https://example.com/cached.pdf';
      await AssetUrlResolver.instance.resolve(key);
      AssetUrlResolver.instance.fetcherOverride = (_) async =>
          throw Exception('forbidden');
      var opens = 0;
      GroupFilePage.openWebPreviewForTest = (_, _, _) async {
        opens++;
      };
      GroupFilePage.openExternalForTest = (_, _) async {
        opens++;
        return true;
      };
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('失权资料.pdf'));
      await tester.pump();
      expect(opens, 0);
      expect(find.text(t.common.groupFileOpenFailed), findsOneWidget);
    },
  );
}

void _boundFileScopeChangeTest() {
  testWidgets('scope change discards pending file authorization', (
    tester,
  ) async {
    GroupFileService.instanceForTest = _FakeGroupFileService(
      files: [
        {
          'id': '9',
          'file_name': '等待授权.pdf',
          'file_category': 'document',
          'object_key': 'u1/file_1_a/doc.pdf',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    final pending = Completer<String>();
    AssetUrlResolver.instance.fetcherOverride = (_) => pending.future;
    var opens = 0;
    GroupFilePage.openWebPreviewForTest = (_, _, _) async {
      opens++;
    };
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('等待授权.pdf'));
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    await tester.pumpWidget(_buildTestApp(groupId: 'g2'));
    pending.complete('https://example.com/signed.pdf');
    await tester.pumpAndSettle();
    expect(opens, 0);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });
}
