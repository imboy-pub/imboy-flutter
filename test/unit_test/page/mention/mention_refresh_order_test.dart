import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mention/mention_list_page.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/mention_service.dart';
import 'package:imboy/store/api/mention_api.dart';

Map<String, dynamic> _items(String label, int count) => {
  'items': List.generate(
    count,
    (i) => {
      'id': '$label-$i',
      'nickname': 'Synthetic',
      'content': '$label-$i',
      'is_read': 1,
    },
  ),
};

class _Service extends MentionService {
  _Service(this.phase) : super.withApi(MentionApi());
  final String phase;
  final entered = Completer<void>();
  final release = Completer<Map<String, dynamic>?>();
  int calls = 0;
  @override
  Future<int> getUnreadCount({String? groupId}) async => 0;
  @override
  Future<Map<String, dynamic>?> getMentions({
    int page = 1,
    int size = 20,
    int? isRead,
    String? groupId,
  }) async {
    calls++;
    if (calls == 1) return _items('initial', 20);
    if (calls == 2) {
      expect(page, phase == 'pagination' ? 2 : 1);
      entered.complete();
      return release.future;
    }
    expect(page, 1);
    return _items('newest', 1);
  }
}

void _refresh() =>
    AppEventBus.fire(const NewMentionEvent(data: {'id': 'synthetic'}));

void main() {
  for (final phase in ['pagination', 'refresh']) {
    testWidgets('new mention refresh rejects late $phase result', (
      tester,
    ) async {
      final service = _Service(phase);
      MentionService.instanceForTest = service;
      addTearDown(() async {
        if (!service.release.isCompleted) service.release.complete(null);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        MentionService.instanceForTest = null;
      });
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
      if (phase == 'pagination') {
        final list = tester.widget<ListView>(find.byType(ListView));
        list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      } else {
        _refresh();
      }
      await tester.pump();
      await service.entered.future;
      _refresh();
      await tester.pump();
      await tester.pump();
      expect(find.text('newest-0'), findsOneWidget);
      service.release.complete(_items('stale', 1));
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.childrenDelegate.estimatedChildCount, 1);
      expect(find.text('newest-0'), findsOneWidget);
      expect(find.text('stale-0'), findsNothing);
      expect(service.calls, 3);
      expect(tester.takeException(), isNull);
    });
  }
}
