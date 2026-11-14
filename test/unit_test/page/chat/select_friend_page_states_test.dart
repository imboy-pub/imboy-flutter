import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/select_friend.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ContactDatabase implements Database {
  Future<List<Map<String, Object?>>> Function() read = () async => [];
  int reads = 0;

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
    if (table != 'contact') throw StateError('Unexpected table: $table');
    reads++;
    return await read();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> _friend(String name) => {
  'peer_id': '8001',
  'nickname': name,
  'avatar': '',
  'tag': '',
  'updated_at': 1790000000000,
  'is_friend': 1,
};

Future<void> _pumpPage(
  WidgetTester tester, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const SelectFriendPage(
            peer: {
              'nickname': 'Synthetic card',
              'title': 'Synthetic card',
              'avatar': '',
            },
            peerIsReceiver: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _refresh(WidgetTester tester) async {
  final indicator = tester.state<RefreshIndicatorState>(
    find.byType(RefreshIndicator),
  );
  unawaited(indicator.show());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _ContactDatabase db;

  setUp(() async {
    await StorageService.to.setString(Keys.currentUid, '990044');
    db = _ContactDatabase();
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await StorageService.to.remove(Keys.currentUid);
  });

  testWidgets(
    'initial failure ends loading and retries the actual contact query',
    (tester) async {
      db.read = () async => throw StateError('synthetic contact failure');
      await _pumpPage(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ShimmerList), findsNothing);
      expect(find.text(t.common.loadError), findsOneWidget);
      expect(find.text(t.common.buttonRetry), findsOneWidget);
      db.read = () async => [_friend('Alice recovered')];
      await tester.tap(find.text(t.common.buttonRetry));
      await tester.pumpAndSettle();
      expect(find.text('Alice recovered'), findsOneWidget);
      expect(find.text(t.common.loadError), findsNothing);
      expect(db.reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pull down refresh queries contacts and retains rows on failure',
    (tester) async {
      db.read = () async => [_friend('Alice gesture retained')];
      await _pumpPage(tester);
      await tester.pumpAndSettle();
      expect(db.reads, 1);
      db.read = () async => throw StateError('synthetic gesture failure');
      final first = find.byType(Scrollable).first;
      expect(
        tester.widget<Scrollable>(first).axisDirection,
        AxisDirection.right,
      );
      await tester.drag(first, const Offset(0, 320));
      await tester.pumpAndSettle();
      expect(db.reads, 1, reason: 'the search field cannot refresh contacts');
      final contacts = find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
            ),
          )
          .hitTestable();
      expect(contacts, findsOneWidget);
      await tester.drag(contacts, const Offset(0, 320));
      await tester.pumpAndSettle();
      expect(db.reads, 2);
      expect(find.text(t.common.loadError), findsOneWidget);
      expect(find.text('Alice gesture retained'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('successful empty query is empty without a failure or retry', (
    tester,
  ) async {
    await _pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text(t.common.noContacts), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
    expect(find.text(t.common.buttonRetry), findsNothing);
  });

  testWidgets(
    'failed refresh retains rows and successful empty refresh clears them',
    (tester) async {
      db.read = () async => [_friend('Alice retained')];
      await _pumpPage(tester, textScale: 0.5);
      await tester.pumpAndSettle();
      db.read = () async => throw StateError('synthetic refresh failure');
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Alice retained'), findsOneWidget);
      expect(find.text(t.common.loadError), findsOneWidget);
      final retry = find.ancestor(
        of: find.text(t.common.buttonRetry),
        matching: find.byType(CupertinoButton),
      );
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      db.read = () async => [];
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Alice retained'), findsNothing);
      expect(find.text(t.common.noContacts), findsOneWidget);
    },
  );

  for (final width in [320.0, 360.0, 390.0]) {
    for (final textScale in [1.0, 1.5, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'refresh recovery fits $width at $textScale in ${brightness.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            try {
              db.read = () async => [_friend('Alice retained')];
              await _pumpPage(
                tester,
                textScale: textScale,
                brightness: brightness,
              );
              await tester.pumpAndSettle();
              db.read = () async =>
                  throw StateError('synthetic refresh failure');
              await _refresh(tester);
              await tester.pumpAndSettle();
              expect(find.text('Alice retained'), findsOneWidget);
              expect(find.text(t.common.loadError), findsOneWidget);
              final retry = find.ancestor(
                of: find.text(t.common.buttonRetry),
                matching: find.byType(CupertinoButton),
              );
              expect(retry.hitTestable(), findsOneWidget);
              expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
              expect(tester.getSize(retry).width, greaterThanOrEqualTo(48));
              final data = tester
                  .getSemantics(find.bySemanticsLabel(t.common.buttonRetry))
                  .getSemanticsData();
              expect(data.label, t.common.buttonRetry);
              expect(data.flagsCollection.isButton, isTrue);
              expect(data.hasAction(SemanticsAction.tap), isTrue);
              db.read = () async => [_friend('Alice recovered')];
              await tester.tap(retry);
              await tester.pumpAndSettle();
              expect(find.text('Alice recovered'), findsOneWidget);
              expect(find.text(t.common.loadError), findsNothing);
              expect(db.reads, 3);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }

  testWidgets('retry is single flight and keeps progress visible', (
    tester,
  ) async {
    db.read = () async => throw StateError('synthetic failure');
    await _pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 200));
    final pending = Completer<List<Map<String, Object?>>>();
    db.read = () => pending.future;
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    expect(db.reads, 2);
    expect(find.byType(ShimmerList), findsOneWidget);
    expect(find.text(t.common.buttonRetry), findsNothing);
    pending.complete([_friend('Alice single flight')]);
    await tester.pumpAndSettle();
    expect(find.text('Alice single flight'), findsOneWidget);
    expect(db.reads, 2);
  });

  testWidgets('late previous-account response is never selectable', (
    tester,
  ) async {
    final pending = Completer<List<Map<String, Object?>>>();
    db.read = () => pending.future;
    await _pumpPage(tester);
    await StorageService.to.setString(Keys.currentUid, '990045');
    pending.complete([_friend('Previous account contact')]);
    await tester.pumpAndSettle();
    expect(find.text('Previous account contact'), findsNothing);
    expect(find.text(t.common.noPermission), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late response after leaving the page does not update disposed state',
    (tester) async {
      final pending = Completer<List<Map<String, Object?>>>();
      db.read = () => pending.future;
      await _pumpPage(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      pending.complete([_friend('Disposed contact')]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh stays single flight while keeping the existing rows', (
    tester,
  ) async {
    db.read = () async => [_friend('Alice visible during refresh')];
    await _pumpPage(tester);
    await tester.pumpAndSettle();
    final pending = Completer<List<Map<String, Object?>>>();
    db.read = () => pending.future;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final first = refresh();
    final repeated = refresh();
    await tester.pump();
    expect(find.text('Alice visible during refresh'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(db.reads, 2);
    pending.complete([_friend('Alice refreshed once')]);
    await Future.wait([first, repeated]);
    await tester.pumpAndSettle();
    expect(find.text('Alice refreshed once'), findsOneWidget);
    expect(db.reads, 2);
  });

  testWidgets(
    'account change while confirmation is open cannot return a contact',
    (tester) async {
      db.read = () async => [_friend('Alice previous account')];
      await _pumpPage(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice previous account'));
      await tester.pumpAndSettle();
      await StorageService.to.setString(Keys.currentUid, '990045');
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(SelectFriendPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selection confirmation still returns the original contact model',
    (tester) async {
      db.read = () async => [_friend('Alice selected')];
      Object? result;
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) => CupertinoButton(
                  child: const Text('Open picker'),
                  onPressed: () async {
                    result = await Navigator.of(context).push<Object>(
                      MaterialPageRoute(
                        builder: (_) => const SelectFriendPage(
                          peer: {
                            'nickname': 'Synthetic card',
                            'title': 'Synthetic card',
                            'avatar': '',
                          },
                          peerIsReceiver: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice selected'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();
      expect((result as ContactModel).peerId, '8001');
      expect((result as ContactModel).title, 'Alice selected');
    },
  );
}
