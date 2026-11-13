import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/search/web_search_page.dart';
import 'package:imboy/page/search/web_search_state.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'web_message_search_failure_test.dart' show waitForHistoryWrites;

class _SourceDatabase implements Database {
  final reads = <String, int>{};
  final handlers =
      <String, Future<List<Map<String, Object?>>> Function(List<Object?>?)>{};

  @override
  bool get isOpen => true;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    reads.update(table, (value) => value + 1, ifAbsent: () => 1);
    return await handlers[table]?.call(whereArgs) ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthChanges extends ChangeNotifier {
  void change() => notifyListeners();
}

Map<String, Object?> _row(String table, String title) => switch (table) {
  'contact' => {
    'peer_id': '201',
    'nickname': title,
    'tag': '',
    'updated_at': 1,
  },
  'group' => {
    'id': '301',
    'title': title,
    'owner_uid': '100',
    'creator_uid': '100',
    'created_at': 1,
  },
  _ => {
    'id': 1,
    'peer_id': '401',
    'title': title,
    'last_time': 1,
    'type': 'C2C',
    'payload': '{}',
  },
};

Finder _title(String title) => find.byWidgetPredicate(
  (widget) => widget is TextHighlight && widget.text == title,
);

Future<void> _pump(
  WidgetTester tester, {
  required Future<List<SearchItem>> Function(String) messages,
  Listenable? changes,
}) async {
  resetWebSearchHistoryQueueForTest();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: WebSearchPage(
          initialQuery: 'first',
          messageSearchForTest: messages,
          authChangesForTest: changes,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await waitForHistoryWrites(tester, find.byType(WebSearchPage));
}

void main() {
  late _SourceDatabase db;
  setUp(() async {
    await StorageService.to.setString(Keys.currentUid, '100');
    db = _SourceDatabase();
    SqliteService.setDbForTest(db);
    for (final table in ['contact', 'group', 'conversation']) {
      db.handlers[table] = (_) async => [_row(table, '$table result')];
    }
  });
  tearDown(() => SqliteService.setDbForTest(null));

  for (final (table, type) in [
    ('contact', SearchItemType.contact),
    ('group', SearchItemType.group),
    ('conversation', SearchItemType.conversation),
  ]) {
    testWidgets('$table failure is visible and retries only that source', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var messages = 0;
        db.handlers[table] = (_) async =>
            throw Exception('synthetic $table failure');
        await _pump(
          tester,
          messages: (_) async {
            messages++;
            return [];
          },
        );
        expect(
          find.byKey(ValueKey('web_${type.name}_search_failure')),
          findsOneWidget,
        );
        for (final other in [
          'contact',
          'group',
          'conversation',
        ].where((value) => value != table)) {
          expect(_title('$other result'), findsOneWidget);
        }
        final retry = find.byKey(ValueKey('web_${type.name}_search_retry'));
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
        final label = switch (type) {
          SearchItemType.contact => t.common.titleContact,
          SearchItemType.group => t.chat.groupChat,
          _ => t.common.searchConversations,
        };
        expect(
          tester.getSemantics(retry).getSemanticsData().label,
          '$label，${t.common.retry}',
        );
        db.handlers[table] = (_) async => [_row(table, '$table recovered')];
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(_title('$table recovered'), findsOneWidget);
        expect(
          find.byKey(ValueKey('web_${type.name}_search_failure')),
          findsNothing,
        );
        expect(messages, 1);
        expect(db.reads[table], 2);
        for (final other in [
          'contact',
          'group',
          'conversation',
        ].where((value) => value != table)) {
          expect(db.reads[other], 1);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
    'multiple failures recover independently and preserve successful groups',
    (tester) async {
      db.handlers['contact'] = (_) async => throw Exception('contact failed');
      db.handlers['group'] = (_) async => throw Exception('group failed');
      await _pump(tester, messages: (_) async => []);
      expect(
        find.byKey(const ValueKey('web_contact_search_failure')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('web_group_search_failure')),
        findsOneWidget,
      );
      db.handlers['contact'] = (_) async => [];
      await tester.tap(find.byKey(const ValueKey('web_contact_search_retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web_contact_search_failure')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('web_group_search_failure')),
        findsOneWidget,
      );
      expect(_title('conversation result'), findsOneWidget);
      expect(db.reads['group'], 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'source retry is single flight and leaves other results available',
    (tester) async {
      db.handlers['contact'] = (_) async => throw Exception('contact failed');
      await _pump(tester, messages: (_) async => []);
      final pending = Completer<List<Map<String, Object?>>>();
      db.handlers['contact'] = (_) => pending.future;
      final retry = find.byKey(const ValueKey('web_contact_search_retry'));
      await tester.tap(retry);
      await tester.pump();
      expect(_title('group result'), findsOneWidget);
      expect(db.reads['contact'], 2);
      expect(tester.widget<CupertinoButton>(retry).onPressed, isNull);
      pending.complete([_row('contact', 'contact retried once')]);
      await tester.pumpAndSettle();
      expect(_title('contact retried once'), findsOneWidget);
      expect(db.reads['contact'], 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('older retry cannot replace results from a new query', (
    tester,
  ) async {
    db.handlers['contact'] = (_) async => throw Exception('contact failed');
    await _pump(tester, messages: (_) async => []);
    final pending = Completer<List<Map<String, Object?>>>();
    db.handlers['contact'] = (_) => pending.future;
    await tester.tap(find.byKey(const ValueKey('web_contact_search_retry')));
    await tester.pump();
    db.handlers['contact'] = (_) async => [
      _row('contact', 'new query contact'),
    ];
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    pending.complete([_row('contact', 'stale retry contact')]);
    await tester.pumpAndSettle();
    expect(_title('new query contact'), findsOneWidget);
    expect(_title('stale retry contact'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'second',
    );
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('auth change discards the pending source retry', (tester) async {
    final changes = _AuthChanges();
    addTearDown(changes.dispose);
    db.handlers['contact'] = (_) async => throw Exception('contact failed');
    await _pump(tester, messages: (_) async => [], changes: changes);
    final pending = Completer<List<Map<String, Object?>>>();
    db.handlers['contact'] = (_) => pending.future;
    await tester.tap(find.byKey(const ValueKey('web_contact_search_retry')));
    await tester.pump();
    await StorageService.to.setString(Keys.currentUid, '200');
    changes.change();
    pending.complete([_row('contact', 'old account contact')]);
    await tester.pumpAndSettle();
    expect(_title('old account contact'), findsNothing);
    expect(
      find.byKey(const ValueKey('web_contact_search_failure')),
      findsNothing,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful empty sources are not reported as failures', (
    tester,
  ) async {
    for (final table in db.handlers.keys.toList()) {
      db.handlers[table] = (_) async => [];
    }
    await _pump(tester, messages: (_) async => []);
    expect(find.text('${t.common.search}: "first"'), findsOneWidget);
    expect(find.text(t.common.searchError), findsNothing);
    expect(find.text(t.common.searchFailedRetry), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'source boundary maps non-Exception read failures to unavailable',
    () async {
      final result = await runWebMessageSearch(
        () async => throw StateError('synthetic closed SQLite read'),
      );
      expect(result.$1, isEmpty);
      expect(result.$2, WebMessageSearchFailure.unavailable);
    },
  );
}
