part of 'group_file_page_test.dart';

class _DelayedSearchService extends _FakeGroupFileService {
  _DelayedSearchService()
    : super(
        files: [
          {
            'file_id': 'f1',
            'file_name': 'old-file',
            'file_category': 'document',
          },
        ],
        categoryStats: [],
        searchResult: [],
      );

  final oldSearch = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> searchFiles({
    required String groupId,
    required String keyword,
    int page = 1,
    int size = 20,
  }) {
    if (keyword == 'old') return oldSearch.future;
    throw BadRequestException(message: 'membership ended', code: 403);
  }
}

void groupFileLoadRaceTests() {
  testWidgets(
    'denied search clears old files; late success cannot restore them',
    (tester) async {
      final service = _DelayedSearchService();
      GroupFileService.instanceForTest = service;
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('old-file'), findsOneWidget);
      final field = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField),
      );
      field.controller!.text = 'old';
      field.onSubmitted!('old');
      await tester.pump();
      field.controller!.text = 'new';
      field.onSubmitted!('new');
      await tester.pumpAndSettle();
      expect(find.text('old-file'), findsNothing);
      expect(find.text(t.common.loadError), findsOneWidget);
      service.oldSearch.complete({
        'list': [
          {
            'file_id': 'f2',
            'file_name': 'late-file',
            'file_category': 'document',
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('late-file'), findsNothing);
      expect(find.text(t.common.loadError), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
