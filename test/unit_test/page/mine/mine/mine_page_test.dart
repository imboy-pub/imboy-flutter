import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/modules/attachments/personal_attachments_page.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/current_space_tile.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/mine/mine/mine_shortcut.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/service/storage.dart';

/// 已批准的「常用工具」布局：空间切换并入资料区，个人/企业入口分流。
class _TestExperience extends ProductExperienceNotifier {
  _TestExperience(this.experience);
  final ProductExperience experience;

  @override
  ProductExperience build() => experience;
}

class _EligibleSeatAdapter implements HttpClientAdapter {
  _EligibleSeatAdapter({this.seatEnabled = true, this.fail = false});

  final bool seatEnabled;
  final bool fail;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (fail) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'synthetic seat contexts failure',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'payload': {
          'contexts': [
            {
              'organization_id': '7266418340025468901',
              'business_identity_id': '7266418340025468902',
              'seat_enabled': seatEnabled,
            },
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GoRouter _stubRouter({
  bool enterprise = false,
  bool enterpriseEntry = false,
  String? enterpriseName,
}) {
  // 所有菜单跳转目标都用 stub 接住，避免 context.push 抛 'no route' 错
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/mine',
    routes: [
      GoRoute(
        path: '/mine',
        builder: (context, _) => MinePage(
          enterprise: enterprise,
          enterpriseName: enterpriseName,
          enterpriseEntry: enterpriseEntry
              ? MineShortcut(
                  label: '企业管理',
                  icon: CupertinoIcons.building_2_fill,
                  onTap: () => context.push('/enterprise-target'),
                )
              : null,
        ),
      ),
      GoRoute(path: '/wallet', builder: (_, _) => stub('wallet stub')),
      GoRoute(
        path: kOrganizationPickerPath,
        builder: (_, _) => stub('space picker stub'),
      ),
      GoRoute(
        path: kTalkRecordListPath,
        builder: (_, state) => stub('talk record ${state.uri.query}'),
      ),
      GoRoute(
        path: '/enterprise-target',
        builder: (_, _) => stub('enterprise stub'),
      ),
      GoRoute(path: '/mine/appeal', builder: (_, _) => stub('appeal stub')),
      GoRoute(path: kCsWorkspacePath, builder: (_, _) => stub('客服工作台目标')),
      GoRoute(path: '/favorites', builder: (_, _) => stub('favorites stub')),
      GoRoute(path: '/storage_space', builder: (_, _) => stub('storage stub')),
      GoRoute(path: '/devices', builder: (_, _) => stub('devices stub')),
      GoRoute(path: '/mine/setting', builder: (_, _) => stub('setting stub')),
      GoRoute(path: '/feedback', builder: (_, _) => stub('feedback stub')),
      GoRoute(path: '/qrcode/user', builder: (_, _) => stub('qrcode stub')),
      GoRoute(
        path: '/personal_info/profile',
        builder: (_, _) => stub('personal stub'),
      ),
    ],
  );
}

Future<void> _setUser({
  String uid = 'tsid_uid_001',
  String account = 'imboy_user',
  String nickname = 'Tester',
  String avatar = '',
  String sign = '',
}) async {
  await StorageService.setMap(Keys.currentUser, <String, dynamic>{
    'uid': uid,
    'account': account,
    'nickname': nickname,
    'avatar': avatar,
    'email': '',
    'gender': 0,
    'sign': sign,
    'region': '',
    'createdAt': 0,
  });
}

Future<void> _pumpMine(
  WidgetTester tester, {
  bool enterprise = false,
  bool enterpriseEntry = false,
  String? enterpriseName,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productExperienceProvider.overrideWith(
          () => _TestExperience(
            enterprise
                ? ProductExperience.workspace
                : ProductExperience.personal,
          ),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          routerConfig: _stubRouter(
            enterprise: enterprise,
            enterpriseEntry: enterpriseEntry,
            enterpriseName: enterpriseName,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  setUp(() async {
    await _setUser();
    // 编译内频道特性开启也不能恢复已移除的「我的频道」入口。
    AppFeatureRegistry.replaceSnapshotForTest({
      for (final f in compiledProductFeatures) f: true,
    });
  });

  tearDown(() async {
    await StorageService.to.remove(Keys.currentUser);
    CurrentOrganizationStore.disposeAccount('tsid_uid_001');
    AppFeatureRegistry.replaceSnapshotForTest({});
  });

  group('MinePage compact profile', () {
    testWidgets('个人资料保留昵称、ID和二维码，不再承载空间切换', (tester) async {
      await _pumpMine(tester);
      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('ID: imboy_user'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.qrcode), findsOneWidget);
      // 空间切换收敛到消息页左上角抽屉：本页无空间胶囊/入口行。
      expect(find.byType(CurrentSpaceTile), findsNothing);
      expect(
        find.text(t.organization.experienceUi.personalSpace),
        findsNothing,
      );
      expect(find.text(t.organization.experienceUi.currentSpace), findsNothing);
      expect(find.text('切换空间'), findsNothing);
    });

    testWidgets('点击昵称只进个人资料，不再打开空间选择器', (tester) async {
      await _pumpMine(tester);
      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();
      expect(find.text('personal stub'), findsOneWidget);
      expect(find.text('space picker stub'), findsNothing);
    });

    testWidgets('企业模式昵称下显示企业名小字，不显示 ID', (tester) async {
      await CurrentOrganizationStore.forAccount('tsid_uid_001')
          .set(const Organization(id: '7266418340025468901', name: '示例企业'));
      await _pumpMine(tester, enterprise: true, enterpriseName: '示例企业');
      expect(find.text('示例企业'), findsOneWidget);
      expect(find.text('ID: imboy_user'), findsNothing);
      expect(find.byType(CurrentSpaceTile), findsNothing);
      // 企业名为纯展示：点击资料卡进个人资料，不触发空间选择器。
      await tester.tap(find.text('示例企业'));
      await tester.pumpAndSettle();
      expect(find.text('space picker stub'), findsNothing);
    });

    testWidgets('企业名缺失时资料区不留空占位行', (tester) async {
      await _pumpMine(tester, enterprise: true);
      expect(find.text('ID: imboy_user'), findsNothing);
      expect(find.text(t.organization.picker.noneSelected), findsNothing);
      expect(find.byType(CurrentSpaceTile), findsNothing);
    });

    testWidgets('精简资料不展示签名或空文本行', (tester) async {
      await _setUser(sign: '不忘初心');
      await _pumpMine(tester);
      expect(find.text('不忘初心'), findsNothing);
      expect(find.text(''), findsNothing);
    });
  });

  group('MinePage shortcuts and menus', () {
    testWidgets('个人常用工具并排且唯一，开启频道特性仍不展示我的频道', (tester) async {
      await _pumpMine(tester);
      expect(find.text(t.discovery.myChannels), findsNothing);
      final labels = [
        t.main.favorites,
        t.talkRecord.entryTitle,
        t.attachmentManager.personalTitle,
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      final centers = labels.map(
        (label) => tester.getCenter(find.text(label)).dy,
      );
      expect(centers.toSet(), hasLength(1));
      expect(find.text('钱包'), findsNothing, reason: '当前构建未包含钱包特性');
      for (final label in [
        t.main.storageSpace,
        t.account.loginDeviceManagement,
        t.appeal.title,
        t.main.setting,
        t.common.feedback,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('关闭可选特性不影响基础工具，钱包仍受特性门控', (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest({
        for (final f in compiledProductFeatures) f: false,
      });
      await _pumpMine(tester);
      expect(find.text(t.account.wallet), findsNothing);
      expect(find.text(t.discovery.myChannels), findsNothing);
      expect(find.text(t.main.favorites), findsOneWidget);
      expect(find.text(t.talkRecord.entryTitle), findsOneWidget);
      expect(find.text(t.attachmentManager.personalTitle), findsOneWidget);
    });

    testWidgets('企业仅保留收藏和注入企业入口，不出现个人工具', (tester) async {
      await _pumpMine(tester, enterprise: true, enterpriseEntry: true);
      expect(find.text(t.main.favorites), findsOneWidget);
      expect(find.text('企业管理'), findsOneWidget);
      expect(
        tester.getCenter(find.text(t.main.favorites)).dy,
        tester.getCenter(find.text('企业管理')).dy,
      );
      for (final label in [
        t.discovery.myChannels,
        t.talkRecord.entryTitle,
        t.attachmentManager.personalTitle,
        t.main.storageSpace,
        t.account.loginDeviceManagement,
        t.appeal.title,
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text(t.main.setting), findsOneWidget);
      expect(find.text(t.common.feedback), findsOneWidget);
      await tester.tap(find.text('企业管理'));
      await tester.pumpAndSettle();
      expect(find.text('enterprise stub'), findsOneWidget);
    });

    testWidgets('面聊记录快捷入口传递个人上下文，不附带企业', (tester) async {
      await _pumpMine(tester);
      await tester.tap(find.text(t.talkRecord.entryTitle));
      await tester.pumpAndSettle();
      expect(find.text('talk record scope=personal'), findsOneWidget);
    });
  });

  for (final enterprise in [false, true]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0]) {
        testWidgets(
          '${width.toInt()}宽大字号无溢出：enterprise=$enterprise $brightness',
          (tester) async {
            await _setUser(
              nickname: '长昵称与Unicode中文🙂Long user name',
              account: 'long_test_account_01234567890123456789',
            );
            await CurrentOrganizationStore.forAccount('tsid_uid_001').set(
              const Organization(
                id: '7266418340025468901',
                name: '这是一个需要截断的很长的企业空间名称🙂',
              ),
            );
            await _pumpMine(
              tester,
              enterprise: enterprise,
              enterpriseEntry: enterprise,
              enterpriseName: enterprise ? '这是一个需要截断的很长的企业空间名称🙂' : null,
              width: width,
              textScale: 2,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(find.text(t.common.feedback), 220);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('客服入口仅个人模式挂载坐席权限组件', (tester) async {
    await _pumpMine(tester);
    expect(find.byType(CsWorkspaceEntryTile), findsOneWidget);
    expect(find.text('客服工作台'), findsNothing, reason: '无合格坐席上下文时仍隐藏，模式切换不能绕过权限');
  });

  testWidgets('企业模式不挂载客服入口（工作台已有同名入口）', (tester) async {
    await _pumpMine(tester, enterprise: true);
    expect(
      find.byType(CsWorkspaceEntryTile),
      findsNothing,
      reason: '企业模式工作台已有客服工作台入口，我页重复披露',
    );
    expect(find.text('客服工作台'), findsNothing);
  });

  for (final fail in [false, true]) {
    testWidgets('客服权限失败时保持隐藏：networkFailure=$fail', (tester) async {
      const secureChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            secureChannel,
            (call) async =>
                call.method == 'readAll' ? <String, String>{} : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureChannel, null),
      );
      final adapter = _EligibleSeatAdapter(seatEnabled: false, fail: fail);
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      await _pumpMine(tester);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      if (fail) {
        // 让实际 HTTP 重试链耗尽，验证失败后的入口而非尚在加载的占位。
        for (var attempt = 0; attempt < 3; attempt++) {
          await tester.pump(const Duration(seconds: 8));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pumpAndSettle();
        }
      }
      expect(adapter.requests, greaterThan(0));
      expect(find.text(t.customerService.entryTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('合格坐席个人模式入口可见且可打开', (tester) async {
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secureChannel,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null),
    );
    HttpClient.adapterForTest = _EligibleSeatAdapter();
    addTearDown(() => HttpClient.adapterForTest = null);
    await tester.runAsync(() async {
      await CsApi().seatContexts();
    });
    await _pumpMine(tester);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('客服工作台'), findsOneWidget);
    await tester.ensureVisible(find.text('客服工作台'));
    await tester.tap(find.text('客服工作台'));
    await tester.pumpAndSettle();
    expect(find.text('客服工作台目标'), findsOneWidget);
  });

  testWidgets('合格坐席企业模式入口也不渲染（入口收敛到工作台）', (tester) async {
    // 预热一份合格坐席上下文，证明"不渲染"是模式门控而非坐席资格缺失；
    // 企业模式下页面不挂载 CsWorkspaceEntryTile，不会发起 seat-contexts。
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secureChannel,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null),
    );
    HttpClient.adapterForTest = _EligibleSeatAdapter();
    addTearDown(() => HttpClient.adapterForTest = null);
    await tester.runAsync(() async {
      await CsApi().seatContexts();
    });
    await _pumpMine(tester, enterprise: true);
    expect(find.text('客服工作台'), findsNothing);
    expect(find.byType(CsWorkspaceEntryTile), findsNothing);
  });

  group('MinePage navigation', () {
    for (final entry in <String, String>{
      '收藏': 'favorites stub',
      '存储空间': 'storage stub',
      '登录设备管理': 'devices stub',
      '处置与申诉': 'appeal stub',
      '反馈建议': 'feedback stub',
    }.entries) {
      testWidgets('tap ${entry.key} → existing destination', (tester) async {
        await _pumpMine(tester);
        await tester.ensureVisible(find.text(entry.key));
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('本机附件快捷入口打开既有附件页', (tester) async {
      await _pumpMine(tester);
      await tester.tap(find.text(t.attachmentManager.personalTitle));
      await tester.pumpAndSettle();
      expect(find.byType(PersonalAttachmentsPage), findsOneWidget);
    });

    testWidgets('二维码进入二维码页，不触发个人资料', (tester) async {
      await _pumpMine(tester);
      await tester.tap(find.byIcon(CupertinoIcons.qrcode));
      await tester.pumpAndSettle();
      expect(find.text('qrcode stub'), findsOneWidget);
      expect(find.text('personal stub'), findsNothing);
    });

    testWidgets('tap setting → /mine/setting', (tester) async {
      await _pumpMine(tester);

      await tester.ensureVisible(find.text('设置'));
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      expect(find.text('setting stub'), findsOneWidget);
    });

    testWidgets('tap profile card → /personal_info/profile', (tester) async {
      await _pumpMine(tester);

      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();

      expect(find.text('personal stub'), findsOneWidget);
    });
  });
}
