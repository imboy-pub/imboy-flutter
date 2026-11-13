import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_member/group_member_page.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _MembersDb implements Database {
  _MembersDb({this.pauseUserId, this.delegate});

  final String? pauseUserId;
  final Database? delegate;
  final queryStarted = Completer<void>();
  final releaseQuery = Completer<void>();
  final inserts = <Map<String, Object?>>[];

  @override
  bool get isOpen => delegate?.isOpen ?? true;

  Future<void> beforeQuery(List<Object?>? arguments) async {
    if (pauseUserId != null &&
        arguments?.contains(pauseUserId) == true &&
        !queryStarted.isCompleted) {
      queryStarted.complete();
      await releaseQuery.future;
    }
  }

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
    await beforeQuery(whereArgs);
    return delegate?.query(
          table,
          distinct: distinct,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        ) ??
        [];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    inserts.add(Map.of(values));
    return delegate?.insert(
          table,
          values,
          nullColumnHack: nullColumnHack,
          conflictAlgorithm: conflictAlgorithm,
        ) ??
        1;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) =>
      delegate?.transaction(
        (txn) => action(_MembersTransaction(this, txn)),
        exclusive: exclusive,
      ) ??
      action(_MembersTransaction(this, null));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MembersTransaction implements Transaction {
  _MembersTransaction(this.owner, this.delegate);
  final _MembersDb owner;
  final Transaction? delegate;

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
    await owner.beforeQuery(whereArgs);
    return delegate?.query(
          table,
          distinct: distinct,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        ) ??
        [];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      delegate?.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      ) ??
      owner.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => delegate!.update(
    table,
    values,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_MembersDb> _openMembersDb(
  WidgetTester tester, {
  String? pauseUserId,
}) async {
  ffi.sqfliteFfiInit();
  ffi.databaseFactory = ffi.databaseFactoryFfi;
  final db = (await tester.runAsync(
    () => openFixtureDatabaseAtVersion(version: 37),
  ))!;
  addTearDown(() => tester.runAsync(db.close));
  return _MembersDb(delegate: db, pauseUserId: pauseUserId);
}

class _MembersPages implements HttpClientAdapter {
  _MembersPages({
    this.total = 21,
    this.pageTwoFailures = 0,
    this.releasePageTwo,
  });

  final int total;
  int pageTwoFailures;
  final Completer<void>? releasePageTwo;
  final pageTwoStarted = Completer<void>();
  final pages = <int>[];
  final requests = <(String, int)>[];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final page = options.queryParameters['page'] as int;
    final groupId = options.queryParameters['gid'].toString();
    pages.add(page);
    requests.add((groupId, page));
    if (page == 2) {
      if (!pageTwoStarted.isCompleted) pageTwoStarted.complete();
      await releasePageTwo?.future;
    }
    final failed = page == 2 && pageTwoFailures > 0;
    if (failed) pageTwoFailures--;
    return ResponseBody.fromString(
      jsonEncode({
        'code': failed ? 500 : 0,
        'msg': failed ? 'synthetic failure' : 'success',
        'payload': failed
            ? null
            : {
                'total': total,
                'list': List.generate(
                  page == 1 ? total.clamp(0, 20) : total - 20,
                  (i) => {
                    'id': '${page * 100 + i}',
                    'group_id': groupId,
                    'user_id': '${page * 100 + i}',
                    'nickname': page == 1 ? 'first batch $i' : 'later match',
                    'role': page == 1 ? 1 : 4,
                    'avatar': '',
                    'sign': '',
                    'account': '',
                    'alias': '',
                    'created_at': 1,
                  },
                ),
              },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void _pinSyntheticToken() {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final encode = base64Url.encode;
  final token =
      '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.'
      '${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.'
      '${encode(utf8.encode('synthetic'))}';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        secure,
        (call) async =>
            call.method == 'read' && call.arguments['key'] == 'secure_token'
            ? token
            : null,
      );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
  });
}

Future<void> _showMembers(
  WidgetTester tester,
  _MembersPages api, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
  _MembersDb? database,
  ValueNotifier<String>? groupId,
}) async {
  SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
  await StorageService.init();
  SqliteService.setDbForTest(database ?? _MembersDb());
  HttpClient.adapterForTest = api;
  _pinSyntheticToken();
  addTearDown(() {
    SqliteService.setDbForTest(null);
    HttpClient.adapterForTest = null;
  });
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.getDarkTheme()
              : AppTheme.getLightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: AppLoading.init()(context, child),
          ),
          home: groupId == null
              ? const GroupMemberPage(groupId: '300')
              : ValueListenableBuilder<String>(
                  valueListenable: groupId,
                  builder: (_, value, _) => GroupMemberPage(groupId: value),
                ),
        ),
      ),
    ),
  );
  if (database?.delegate != null) {
    await _pumpUntil(
      tester,
      () => find.text('first batch 0').evaluate().isNotEmpty,
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _closeMembers(WidgetTester tester) async {
  unawaited(AppLoading.dismiss());
  await tester.pumpAndSettle();
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(ready(), isTrue);
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
  testWidgets(
    'member search states loaded scope and can reach a match in the next batch',
    (tester) async {
      final api = _MembersPages();
      await _showMembers(tester, api);
      expect(api.pages, [1]);
      expect(find.text('仅搜索已加载成员'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'later match');
      await tester.pumpAndSettle();
      expect(find.text(t.common.searchNoResults), findsOneWidget);
      expect(find.text(t.common.loadMore), findsOneWidget);
      await tester.tap(find.text(t.common.loadMore));
      await tester.pumpAndSettle();
      expect(api.pages, [1, 2]);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'later match',
      );
      expect(find.text('later match'), findsWidgets);
      expect(find.text(t.common.searchNoResults), findsNothing);
      expect(tester.takeException(), isNull);
      await _closeMembers(tester);
    },
  );

  testWidgets('filtered empty search cannot load beyond the final page', (
    tester,
  ) async {
    final api = _MembersPages(total: 20);
    await _showMembers(tester, api);
    await tester.enterText(find.byType(EditableText), 'later match');
    await tester.pumpAndSettle();
    expect(find.text(t.common.searchNoResults), findsOneWidget);
    expect(find.text(t.common.loadMore), findsNothing);
    expect(api.pages, [1]);
    await _closeMembers(tester);
  });

  testWidgets('filtered search retries the failed page and keeps its query', (
    tester,
  ) async {
    final api = _MembersPages(pageTwoFailures: 1);
    await _showMembers(tester, api);
    await tester.enterText(find.byType(EditableText), 'later match');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.loadMore));
    await tester.pumpAndSettle();
    expect(api.pages, [1, 2]);
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.common.searchNoResults), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'later match',
    );
    await tester.tap(find.text(t.common.loadMore));
    await tester.pumpAndSettle();
    expect(api.pages, [1, 2, 2]);
    expect(find.text('later match'), findsWidgets);
    expect(find.text(t.common.searchNoResults), findsNothing);
    expect(tester.takeException(), isNull);
    await _closeMembers(tester);
  });

  testWidgets('late member page does not retain the previous account rows', (
    tester,
  ) async {
    final release = Completer<void>();
    final api = _MembersPages(releasePageTwo: release);
    await _showMembers(tester, api);
    final oldInput = tester
        .widget<CupertinoSearchTextField>(find.byType(CupertinoSearchTextField))
        .onChanged!;
    final dbB = _MembersDb();
    final events = <GroupMemberUpdateEvent>[];
    final subscription = AppEventBus.on<GroupMemberUpdateEvent>().listen(
      events.add,
    );
    addTearDown(subscription.cancel);
    await tester.enterText(find.byType(EditableText), 'later match');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.loadMore));
    await _pumpUntil(tester, () => api.pageTwoStarted.isCompleted);
    await StorageService.to.setString(Keys.currentUid, '2002');
    SqliteService.setDbForTest(dbB);
    release.complete();
    await tester.pumpAndSettle();
    oldInput('first batch');
    await tester.pumpAndSettle();
    expect(find.text('first batch 0'), findsNothing);
    expect(
      tester
          .widget<CupertinoSearchTextField>(
            find.byType(CupertinoSearchTextField),
          )
          .enabled,
      isFalse,
    );
    expect(dbB.inserts, isEmpty);
    expect(events, isEmpty);
    await _closeMembers(tester);
  });

  testWidgets(
    'member persistence cannot move an old row into the next database',
    (tester) async {
      final dbA = await _openMembersDb(tester, pauseUserId: '200');
      final api = _MembersPages();
      await _showMembers(tester, api, database: dbA);
      final dbB = await _openMembersDb(tester);
      expect(identical(dbA.delegate, dbB.delegate), isFalse);
      final events = <GroupMemberUpdateEvent>[];
      final subscription = AppEventBus.on<GroupMemberUpdateEvent>().listen(
        events.add,
      );
      addTearDown(subscription.cancel);
      await tester.enterText(find.byType(EditableText), 'later match');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.loadMore));
      await _pumpUntil(tester, () => dbA.queryStarted.isCompleted);
      await StorageService.to.setString(Keys.currentUid, '2002');
      SqliteService.setDbForTest(dbB);
      dbA.releaseQuery.complete();
      await _pumpUntil(
        tester,
        () =>
            find.text('later match').evaluate().length > 1 ||
            tester
                    .widget<CupertinoSearchTextField>(
                      find.byType(CupertinoSearchTextField),
                    )
                    .enabled ==
                false,
      );
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => dbB.delegate!.query('group_member')),
        isEmpty,
      );
      expect(
        await tester.runAsync(
          () => dbA.delegate!.query(
            'group_member',
            where: 'user_id = ?',
            whereArgs: ['200'],
          ),
        ),
        isEmpty,
      );
      expect(events, isEmpty);
      expect(find.text('later match'), findsNothing);
      await _closeMembers(tester);
    },
  );

  testWidgets('default member save stays on its captured account database', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    final dbA = await _openMembersDb(tester, pauseUserId: '200');
    final dbB = await _openMembersDb(tester);
    expect(identical(dbA.delegate, dbB.delegate), isFalse);
    SqliteService.setDbForTest(dbA);
    addTearDown(() => SqliteService.setDbForTest(null));
    GroupMemberModel? saved;
    final pending = GroupMemberRepo()
        .save({
          'id': '200',
          'group_id': '300',
          'user_id': '200',
          'nickname': 'later match',
          'role': 1,
          'created_at': 1,
        })
        .then((value) => saved = value);
    await _pumpUntil(tester, () => dbA.queryStarted.isCompleted);
    await StorageService.to.setString(Keys.currentUid, '2002');
    SqliteService.setDbForTest(dbB);
    dbA.releaseQuery.complete();
    await _pumpUntil(tester, () => saved != null);
    await pending;
    expect(
      await tester.runAsync(() => dbB.delegate!.query('group_member')),
      isEmpty,
    );
    expect(
      await tester.runAsync(() => dbA.delegate!.query('group_member')),
      hasLength(1),
    );
    expect(saved?.userId, '200');
    await StorageService.to.setString(Keys.currentUid, '1001');
    SqliteService.setDbForTest(dbA);
    final updated = await tester.runAsync(
      () => GroupMemberRepo().save({
        'id': '200',
        'group_id': '300',
        'user_id': '200',
        'nickname': 'updated member',
        'role': 1,
        'created_at': 1,
      }),
    );
    expect(updated?.nickname, 'updated member');
    expect(
      (await tester.runAsync(() => dbA.delegate!.query('group_member')))!
          .single['nickname'],
      'updated member',
    );
    expect(
      await tester.runAsync(() => dbB.delegate!.query('group_member')),
      isEmpty,
    );
  });

  testWidgets('member page drops a late result after its group changed', (
    tester,
  ) async {
    final release = Completer<void>();
    final api = _MembersPages(releasePageTwo: release);
    final database = _MembersDb();
    final groupId = ValueNotifier('300');
    addTearDown(groupId.dispose);
    await _showMembers(tester, api, database: database, groupId: groupId);
    final events = <GroupMemberUpdateEvent>[];
    final subscription = AppEventBus.on<GroupMemberUpdateEvent>().listen(
      events.add,
    );
    addTearDown(subscription.cancel);
    await tester.enterText(find.byType(EditableText), 'later match');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.loadMore));
    await _pumpUntil(tester, () => api.pageTwoStarted.isCompleted);
    groupId.value = '301';
    await tester.pump();
    release.complete();
    await tester.pumpAndSettle();
    expect(api.requests, [('300', 1), ('300', 2), ('301', 1)]);
    expect(database.inserts.where((row) => row['user_id'] == '200'), isEmpty);
    expect(events.map((event) => event.groupId), ['301']);
    expect(find.text('first batch 0'), findsOneWidget);
    await _closeMembers(tester);
  });

  testWidgets('disposed member callbacks cannot start work or touch state', (
    tester,
  ) async {
    final api = _MembersPages();
    final database = _MembersDb();
    await _showMembers(tester, api, database: database);
    final oldInput = tester
        .widget<CupertinoSearchTextField>(find.byType(CupertinoSearchTextField))
        .onChanged!;
    final oldFilter = tester
        .widget<CupertinoSlidingSegmentedControl<int>>(
          find.byType(CupertinoSlidingSegmentedControl<int>),
        )
        .onValueChanged;
    await tester.enterText(find.byType(EditableText), 'later match');
    await tester.pumpAndSettle();
    final oldMore = tester.widget<NoDataView>(find.byType(NoDataView)).onTop!;
    final requestsBefore = List.of(api.requests);
    final writesBefore = List.of(database.inserts);
    await tester.pumpWidget(const SizedBox.shrink());
    await expectLater(Future<void>.sync(oldMore), completes);
    expect(() => oldInput('stale query'), returnsNormally);
    expect(() => oldFilter(4), returnsNormally);
    await tester.pump();
    expect(api.requests, requestsBefore);
    expect(database.inserts, writesBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed member page cannot persist or publish a late page', (
    tester,
  ) async {
    final release = Completer<void>();
    final api = _MembersPages(releasePageTwo: release);
    final database = _MembersDb();
    await _showMembers(tester, api, database: database);
    final events = <GroupMemberUpdateEvent>[];
    final subscription = AppEventBus.on<GroupMemberUpdateEvent>().listen(
      events.add,
    );
    addTearDown(subscription.cancel);
    await tester.enterText(find.byType(EditableText), 'later match');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.loadMore));
    await _pumpUntil(tester, () => api.pageTwoStarted.isCompleted);
    await tester.pumpWidget(const SizedBox.shrink());
    release.complete();
    await tester.pumpAndSettle();
    expect(database.inserts.where((row) => row['user_id'] == '200'), isEmpty);
    expect(events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading filtered members preserves the selected role', (
    tester,
  ) async {
    final api = _MembersPages();
    await _showMembers(tester, api);
    await tester.tap(find.text(t.group.groupOwner));
    await tester.pumpAndSettle();
    expect(find.text(t.common.loadMore), findsOneWidget);
    await tester.tap(find.text(t.common.loadMore));
    await tester.pumpAndSettle();
    expect(api.pages, [1, 2]);
    expect(find.text('later match'), findsOneWidget);
    expect(find.text('first batch 0'), findsNothing);
    await _closeMembers(tester);
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('member layout $width $scale $brightness', (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final api = _MembersPages();
          await _showMembers(
            tester,
            api,
            textScale: scale,
            brightness: brightness,
          );
          await tester.enterText(find.byType(EditableText), 'later match');
          await tester.pumpAndSettle();
          final editable = tester
              .state<EditableTextState>(find.byType(EditableText))
              .renderEditable;
          expect(
            editable.size.height + 0.1,
            greaterThanOrEqualTo(editable.preferredLineHeight),
          );
          final input = tester.getSize(find.byType(CupertinoSearchTextField));
          expect(input.height, greaterThanOrEqualTo(48));
          final clear = find
              .ancestor(
                of: find.byIcon(CupertinoIcons.xmark_circle_fill),
                matching: find.byType(CupertinoButton),
              )
              .first;
          expect(tester.getSize(clear).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(clear).width, greaterThanOrEqualTo(48));
          final glyph = tester.widget<RichText>(
            find.descendant(
              of: find.byIcon(CupertinoIcons.xmark_circle_fill),
              matching: find.byType(RichText),
            ),
          );
          expect(glyph.text.style?.fontSize, 20 * scale);
          await tester.tapAt(tester.getTopLeft(clear) + const Offset(2, 2));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            isEmpty,
          );
          expect(api.pages, [1]);
          await tester.enterText(find.byType(EditableText), 'later match');
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          await tester.pumpAndSettle();
          expect(find.text('仅搜索已加载成员'), findsOneWidget);
          final action = find.text(t.common.loadMore);
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          final button = find
              .ancestor(of: action, matching: find.byType(CupertinoButton))
              .first;
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(button.hitTestable(), findsOneWidget);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(api.pages, [1, 2]);
          final result = find.descendant(
            of: find.byType(ListView),
            matching: find.text('later match'),
          );
          await tester.ensureVisible(result);
          await tester.pumpAndSettle();
          expect(result.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _closeMembers(tester);
        });
      }
    }
  }
}
