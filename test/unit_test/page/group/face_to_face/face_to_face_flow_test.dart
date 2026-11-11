import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_confirm_page.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_page.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gid = '9007199254740993';
const _peer = '9007199254740995';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<void>? pendingMatch;
  Completer<void>? pendingMembers;
  bool failMatch = false;
  bool failSave = false;
  List<Map<String, dynamic>> members = [
    {'user_id': _peer, 'nickname': '附近朋友', 'alias': '', 'account': 'fixture'},
  ];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final isSave = options.path.endsWith('face2face_save');
    final isMatch = options.path.endsWith('face2face');
    if (isMatch) await pendingMatch?.future;
    final failed = isMatch && failMatch || isSave && failSave;
    final page = int.tryParse('${options.queryParameters['page'] ?? 1}') ?? 1;
    final batch = members.skip((page - 1) * 200).take(200).toList();
    final payload = options.path.contains('member')
        ? {'list': batch, 'total': members.length}
        : {
            'gid': _gid,
            'member_list': members,
            'group': {'id': _gid},
          };
    if (options.path.contains('member')) await pendingMembers?.future;
    return ResponseBody.fromString(
      jsonEncode({
        'code': failed ? 1 : 0,
        'msg': failed ? '暗号已失效，请重新匹配' : 'success',
        'payload': payload,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  // Dio 与平台通道在真实事件循环完成；先排空它们再等待页面动画。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<GoRouter> _open(
  WidgetTester tester,
  _Adapter adapter, {
  bool confirm = false,
  Future<ImboyLocation?> Function()? location,
  Brightness brightness = Brightness.light,
}) async {
  HttpClient.adapterForTest = adapter;
  final router = GoRouter(
    initialLocation: confirm ? '/confirm' : '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const FaceToFacePage()),
      GoRoute(
        path: '/confirm',
        builder: (_, _) => FaceToFaceConfirmPage(
          gid: _gid,
          code: '0123',
          memberList: [
            PeopleModel(id: _peer, account: 'fixture', nickname: '附近朋友'),
          ],
        ),
      ),
      GoRoute(
        path: '/group/face_to_face_confirm',
        builder: (_, state) {
          final args = state.extra! as Map<String, dynamic>;
          return FaceToFaceConfirmPage(
            gid: args['gid'] as String,
            code: args['code'] as String,
            memberList: args['memberList'] as List<PeopleModel>,
          );
        },
      ),
      GoRoute(
        path: '/people_info/:id',
        builder: (_, state) => Scaffold(
          body: Text(
            'profile:${state.pathParameters['id']}:${(state.extra! as Map)['scene']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        faceToFaceLocationProvider.overrideWithValue(
          location ??
              () async => const ImboyLocation(latitude: 39.9, longitude: 116.4),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          theme: ThemeData(brightness: brightness),
          routerConfig: router,
        ),
      ),
    ),
  );
  await _settle(tester);
  return router;
}

Future<void> _typeCode(WidgetTester tester) async {
  for (final digit in ['0', '1', '2', '3']) {
    await tester.tap(
      find.descendant(
        of: find.byType(NumericKeypad),
        matching: find.text(digit),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('imboy/sound'),
          (_) async => null,
        );
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('imboy/sound'), null);
  });

  for (final position in <ImboyLocation?>[
    null,
    const ImboyLocation(latitude: 0, longitude: 0),
    const ImboyLocation(latitude: 91, longitude: 116),
    const ImboyLocation(latitude: 39, longitude: double.nan),
  ]) {
    test('invalid location $position never sends a match request', () async {
      final adapter = _Adapter();
      HttpClient.adapterForTest = adapter;
      final container = ProviderContainer(
        overrides: [
          faceToFaceLocationProvider.overrideWithValue(() async => position),
        ],
      );
      addTearDown(container.dispose);
      container.listen(faceToFaceProvider, (_, _) {});
      final result = await container
          .read(faceToFaceProvider.notifier)
          .faceToFace('0123');
      expect(result['gid'], isEmpty);
      expect(result['error'], t.common.f2fLocationRequired);
      expect(adapter.requests, isEmpty);
    });
  }

  testWidgets(
    'four digits match once, block extra taps, preserve leading zero and exact IDs',
    (tester) async {
      final adapter = _Adapter()..pendingMatch = Completer<void>();
      await _open(tester, adapter);
      await _typeCode(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NumericKeypad),
          matching: find.text('4'),
        ),
      );
      await tester.pump();
      final state = ProviderScope.containerOf(
        tester.element(find.byType(FaceToFacePage)),
      ).read(faceToFaceProvider);
      expect(state.resultData, '0123', reason: state.errorInfo);
      expect(state.errorInfo, isEmpty);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.queryParameters, {
        'code': '0123',
        'longitude': '116.4',
        'latitude': '39.9',
      });
      adapter.pendingMatch!.complete();
      await _settle(tester);
      expect(find.byType(FaceToFaceConfirmPage), findsOneWidget);
      expect(find.text('附近朋友'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('location denial stays inline and retry obtains a new position', (
    tester,
  ) async {
    var granted = false;
    final adapter = _Adapter();
    await _open(
      tester,
      adapter,
      location: () async => granted
          ? const ImboyLocation(latitude: 39.9, longitude: 116.4)
          : null,
    );
    await _typeCode(tester);
    await _settle(tester);
    expect(find.text(t.common.f2fLocationRequired), findsOneWidget);
    expect(adapter.requests, isEmpty);
    granted = true;
    await tester.tap(find.text(t.common.retry));
    await _settle(tester);
    expect(find.byType(FaceToFaceConfirmPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('server failure stays visible and same code can retry', (
    tester,
  ) async {
    final adapter = _Adapter()..failMatch = true;
    await _open(tester, adapter);
    await _typeCode(tester);
    await _settle(tester);
    expect(find.text('暗号已失效，请重新匹配'), findsOneWidget);
    adapter.failMatch = false;
    await tester.tap(find.text(t.common.retry));
    await _settle(tester);
    expect(find.byType(FaceToFaceConfirmPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'only current group events update members; avatar opens add-friend profile',
    (tester) async {
      final adapter = _Adapter();
      await _open(tester, adapter, confirm: true);
      void joined(String gid) => AppEventBus.fire(
        ChatExtendEvent(
          type: 'join_group',
          payload: {
            'groupId': gid,
            'userId': '9007199254740997',
            'people': PeopleModel(
              id: '9007199254740997',
              account: 'fixture2',
              nickname: '新朋友',
            ),
          },
        ),
      );
      joined('999');
      await _settle(tester);
      expect(find.text('新朋友'), findsNothing);
      joined(_gid);
      joined(_gid);
      await _settle(tester);
      expect(find.text('新朋友'), findsOneWidget);
      await tester.tap(find.text('附近朋友'));
      await _settle(tester);
      expect(find.text('profile:$_peer:group_member'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'missed events reconcile on refresh and remove departed members',
    (tester) async {
      final adapter = _Adapter();
      await _open(tester, adapter, confirm: true);
      adapter.members = [
        {'user_id': '42', 'nickname': '补拉成员', 'alias': ''},
      ];
      await tester.tap(find.text(t.common.retry));
      await _settle(tester);
      expect(find.text('补拉成员'), findsOneWidget);
      expect(find.text('附近朋友'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('save failure remains visible after periodic member refresh', (
    tester,
  ) async {
    final adapter = _Adapter()..failSave = true;
    await _open(tester, adapter, confirm: true);
    await tester.tap(find.text(t.group.enterTheGroup));
    await _settle(tester);
    expect(find.text('暗号已失效，请重新匹配'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
    expect(find.text('暗号已失效，请重新匹配'), findsOneWidget);
    expect(find.byType(FaceToFaceConfirmPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'inactive members stay hidden and empty names have a visible label',
    (tester) async {
      final adapter = _Adapter()
        ..members = [
          {'user_id': '41', 'status': 0, 'nickname': '已离开'},
          {'user_id': '42', 'status': 1, 'nickname': '', 'alias': ''},
        ];
      await _open(tester, adapter, confirm: true);
      expect(find.text('已离开'), findsNothing);
      expect(find.text(t.main.unnamed), findsOneWidget);
      expect(find.text(t.common.f2fEnteringGroup(count: 1)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('late member snapshot cannot overwrite a new join event', (
    tester,
  ) async {
    final adapter = _Adapter()..pendingMembers = Completer<void>();
    await _open(tester, adapter, confirm: true);
    AppEventBus.fire(
      ChatExtendEvent(
        type: 'join_group',
        payload: {
          'groupId': _gid,
          'userId': '42',
          'people': PeopleModel(
            id: '42',
            account: 'fixture42',
            nickname: '刚加入的朋友',
          ),
        },
      ),
    );
    await _settle(tester);
    adapter.pendingMembers!.complete();
    await _settle(tester);
    expect(find.text('刚加入的朋友'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('location timeout releases busy state and offers retry', (
    tester,
  ) async {
    final position = Completer<ImboyLocation?>();
    final adapter = _Adapter();
    await _open(tester, adapter, location: () => position.future);
    await _typeCode(tester);
    await tester.pump(const Duration(seconds: 31));
    await _settle(tester);
    expect(find.text(t.common.f2fLocationRequired), findsOneWidget);
    expect(find.text(t.common.retry), findsOneWidget);
    expect(adapter.requests, isEmpty);
    position.complete(null);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('system location fallback after 20 seconds can still match', (
    tester,
  ) async {
    await _open(
      tester,
      _Adapter(),
      location: () => Future.delayed(
        const Duration(seconds: 20),
        () => const ImboyLocation(latitude: 39.9, longitude: 116.4),
      ),
    );
    await _typeCode(tester);
    await tester.pump(const Duration(seconds: 20));
    await _settle(tester);
    expect(find.byType(FaceToFaceConfirmPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing input page while locating ignores late result', (
    tester,
  ) async {
    final position = Completer<ImboyLocation?>();
    final adapter = _Adapter();
    await _open(tester, adapter, location: () => position.future);
    await _typeCode(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    position.complete(const ImboyLocation(latitude: 39.9, longitude: 116.4));
    await _settle(tester);
    expect(adapter.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member refresh fetches every page before replacing members', (
    tester,
  ) async {
    final adapter = _Adapter()
      ..members = List.generate(
        201,
        (i) => {'user_id': '${i + 1}', 'nickname': 'member$i', 'alias': ''},
      );
    await _open(tester, adapter, confirm: true);
    expect(
      adapter.requests.where((r) => r.path.contains('member')),
      hasLength(2),
    );
    expect(find.text('member200'), findsOneWidget);
    expect(find.text(t.common.f2fEnteringGroup(count: 201)), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [280.0, 375.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'layout width=$width $brightness keeps keypad compact and has no overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _open(tester, _Adapter(), brightness: brightness);
          expect(
            tester.getSize(find.byType(NumericKeypad)).width,
            lessThanOrEqualTo(420),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
