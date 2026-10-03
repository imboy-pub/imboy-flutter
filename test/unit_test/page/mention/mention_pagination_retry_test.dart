import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mention/mention_list_page.dart';
import 'package:imboy/service/mention_service.dart';
import 'package:imboy/store/api/mention_api.dart';

class _Service extends MentionService {
  _Service() : super.withApi(MentionApi());
  final requested = <int>[];
  bool failedOnce = false;
  @override
  Future<int> getUnreadCount({String? groupId}) async => 0;
  @override
  Future<Map<String, dynamic>?> getMentions({
    int page = 1,
    int size = 20,
    int? isRead,
    String? groupId,
  }) async {
    expect(groupId, 'synthetic-group');
    expect(size, 20);
    requested.add(page);
    if (page == 2 && !failedOnce) {
      failedOnce = true;
      return null;
    }
    return {
      'items': List.generate(
        page == 1 ? 20 : 1,
        (index) => {
          'id': page * 100 + index,
          'nickname': 'Synthetic',
          'content': 'page-$page-item-$index',
          'is_read': 1,
        },
      ),
    };
  }
}

Future<void> _reachBottom(WidgetTester tester) async {
  final list = tester.widget<ListView>(find.byType(ListView));
  final controller = list.controller!;
  controller.jumpTo(controller.position.maxScrollExtent - 300);
  await tester.pump();
  controller.jumpTo(controller.position.maxScrollExtent);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => MentionService.instanceForTest = null);
  testWidgets('failed mention page retries the same page without skipping', (
    tester,
  ) async {
    final service = _Service();
    MentionService.instanceForTest = service;
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const MaterialApp(
            home: MentionListPage(groupId: 'synthetic-group'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.requested, [1]);
    await _reachBottom(tester);
    expect(service.requested, [1, 2]);
    expect(tester.takeException(), isNull);
    await _reachBottom(tester);
    expect(service.requested, [1, 2, 2]);
    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('page-2-item-0'), findsOneWidget);
    expect(service.requested, [1, 2, 2]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
